//
//  SnapzyConfigurationWriteRouter.swift
//  Snapzy
//
//  Pure, stateless routing decision: given current settings, on-disk docs, and
//  write mode, returns the lean user-config document to persist (nil = no write)
//  and whether the built-in should be written.
//

import Foundation

/// The routing outcome for a single sync cycle.
struct SnapzyConfigurationWriteRouting {
  /// Whether the built-in config.toml should be written (full current settings export).
  let shouldWriteBuiltIn: Bool
  /// The updated lean user-config document to persist.
  /// `nil` means no user-config write this cycle.
  let userConfigDoc: SimpleTOMLDocument?
}

enum SnapzyConfigurationWriteRouter {
  /// Route a sync cycle to the correct file(s).
  ///
  /// - Parameters:
  ///   - currentDoc: Parsed current app settings (from `exportTOML()`).
  ///   - builtInDoc: Parsed on-disk built-in config.toml.
  ///   - userConfigDoc: Parsed on-disk user-config.toml (empty doc if missing/new).
  ///   - mode: Write-back mode.
  /// - Returns: Routing decision with what to write where.
  static func route(
    currentDoc: SimpleTOMLDocument,
    builtInDoc: SimpleTOMLDocument,
    userConfigDoc: SimpleTOMLDocument,
    mode: SnapzyConfigurationWriteMode
  ) -> SnapzyConfigurationWriteRouting {
    switch mode {
    case .perKey:
      return routePerKey(currentDoc: currentDoc, userConfigDoc: userConfigDoc)

    case .primary:
      return routePrimary(currentDoc: currentDoc, builtInDoc: builtInDoc, userConfigDoc: userConfigDoc)
    }
  }

  // MARK: - perKey mode

  /// Built-in: write full export (as today).
  /// User-config: update current values for EXISTING keys only (lean set unchanged).
  private static func routePerKey(
    currentDoc: SimpleTOMLDocument,
    userConfigDoc: SimpleTOMLDocument
  ) -> SnapzyConfigurationWriteRouting {
    let updatedUserDoc = updateExistingKeys(in: userConfigDoc, from: currentDoc)
    // Only write user-config if it already has content.
    let hasUserConfigKeys = !leafKeys(in: userConfigDoc.root).isEmpty
    return SnapzyConfigurationWriteRouting(
      shouldWriteBuiltIn: false,
      userConfigDoc: hasUserConfigKeys ? updatedUserDoc : nil
    )
  }

  // MARK: - primary mode

  /// Built-in: NOT written (read-only base).
  /// User-config: accumulate all keys where current value differs from built-in.
  private static func routePrimary(
    currentDoc: SimpleTOMLDocument,
    builtInDoc: SimpleTOMLDocument,
    userConfigDoc: SimpleTOMLDocument
  ) -> SnapzyConfigurationWriteRouting {
    // Keys where current settings differ from built-in.
    let changedEntries = SnapzyConfigurationDiff.diff(base: builtInDoc, override: currentDoc)
      .filter { $0.isChanged || $0.isOnlyInOverride }

    // Build the delta doc (only changed keys).
    var deltaRoot: [String: SimpleTOMLValue] = [:]
    for entry in changedEntries {
      guard let value = entry.overrideValue else { continue }
      if let updated = setLeafValue(value, at: entry.keyPath, in: deltaRoot) {
        deltaRoot = updated
      }
    }
    let deltaDoc = SimpleTOMLDocument(root: deltaRoot)

    // Merge delta into existing user-config (growing the lean override set).
    let (mergedDoc, _) = userConfigDoc.merging(override: deltaDoc)

    return SnapzyConfigurationWriteRouting(
      shouldWriteBuiltIn: false,
      userConfigDoc: mergedDoc
    )
  }

  // MARK: - Helpers

  /// For every leaf key present in `target`, set its value from `source` (if present).
  private static func updateExistingKeys(
    in target: SimpleTOMLDocument,
    from source: SimpleTOMLDocument
  ) -> SimpleTOMLDocument {
    var updated = target
    for keyPath in leafKeys(in: target.root) {
      if let newValue = source.value(at: keyPath) {
        try? updated.set(newValue, at: keyPath)
      }
    }
    return updated
  }

  /// Collect all leaf key paths (non-table) within a table, recursively.
  static func leafKeys(in table: [String: SimpleTOMLValue], prefix: [String] = []) -> [[String]] {
    var paths: [[String]] = []
    for key in table.keys {
      let path = prefix + [key]
      switch table[key]! {
      case .table(let child):
        paths.append(contentsOf: leafKeys(in: child, prefix: path))
      default:
        paths.append(path)
      }
    }
    return paths
  }

  /// Returns the root dict after setting `value` at `path`, or nil if path is empty.
  private static func setLeafValue(
    _ value: SimpleTOMLValue,
    at path: [String],
    in root: [String: SimpleTOMLValue]
  ) -> [String: SimpleTOMLValue]? {
    guard !path.isEmpty else { return nil }
    var doc = SimpleTOMLDocument(root: root)
    try? doc.set(value, at: path)
    return doc.root
  }
}
