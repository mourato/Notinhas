//
//  SnapzyConfigurationDiff.swift
//  Snapzy
//
//  Leaf-level dotted-key diff between two SimpleTOMLDocuments.
//  Used by write routing (Phase 04) and promote-to-built-in diff UI (Phase 06).
//

import Foundation

struct SnapzyConfigurationDiffEntry: Equatable {
  let keyPath: [String]
  let dottedKey: String
  let baseValue: SimpleTOMLValue?
  let overrideValue: SimpleTOMLValue?

  var isOnlyInOverride: Bool { baseValue == nil && overrideValue != nil }
  var isOnlyInBase: Bool { overrideValue == nil && baseValue != nil }
  var isChanged: Bool { baseValue != nil && overrideValue != nil && baseValue != overrideValue }
}

enum SnapzyConfigurationDiff {
  /// Returns leaf-level entries where `base` and `override` differ.
  /// Entries appear for: changed values, keys only in base, keys only in override.
  /// Tables are recursed into; only leaf values produce entries.
  static func diff(
    base: SimpleTOMLDocument,
    override: SimpleTOMLDocument
  ) -> [SnapzyConfigurationDiffEntry] {
    var entries: [SnapzyConfigurationDiffEntry] = []
    diffTables(
      base: base.root,
      override: override.root,
      path: [],
      entries: &entries
    )
    return entries.sorted { $0.dottedKey < $1.dottedKey }
  }

  // MARK: - Private

  private static func diffTables(
    base: [String: SimpleTOMLValue],
    override: [String: SimpleTOMLValue],
    path: [String],
    entries: inout [SnapzyConfigurationDiffEntry]
  ) {
    let allKeys = Set(base.keys).union(override.keys)
    for key in allKeys {
      let basVal = base[key]
      let ovrVal = override[key]
      let childPath = path + [key]

      switch (basVal, ovrVal) {
      case (.some(.table(let b)), .some(.table(let o))):
        diffTables(base: b, override: o, path: childPath, entries: &entries)

      case (.some(.table(let b)), .none):
        // Subtree only in base — recurse, emitting each leaf as base-only
        collectLeaves(from: b, path: childPath, side: .base, entries: &entries)

      case (.none, .some(.table(let o))):
        // Subtree only in override — recurse, emitting each leaf as override-only
        collectLeaves(from: o, path: childPath, side: .override, entries: &entries)

      case (.some(.table(let b)), .some):
        // Base is table, override is scalar — emit override only
        collectLeaves(from: b, path: childPath, side: .base, entries: &entries)
        entries.append(entry(path: childPath, base: nil, override: ovrVal))

      case (.some, .some(.table(let o))):
        // Base is scalar, override is table — emit base only
        entries.append(entry(path: childPath, base: basVal, override: nil))
        collectLeaves(from: o, path: childPath, side: .override, entries: &entries)

      default:
        // Both scalars or one absent — emit if different
        if basVal != ovrVal {
          entries.append(entry(path: childPath, base: basVal, override: ovrVal))
        }
      }
    }
  }

  private enum Side { case base, override }

  private static func collectLeaves(
    from table: [String: SimpleTOMLValue],
    path: [String],
    side: Side,
    entries: inout [SnapzyConfigurationDiffEntry]
  ) {
    for key in table.keys {
      let childPath = path + [key]
      switch table[key]! {
      case .table(let child):
        collectLeaves(from: child, path: childPath, side: side, entries: &entries)
      default:
        let val = table[key]
        switch side {
        case .base:    entries.append(entry(path: childPath, base: val, override: nil))
        case .override: entries.append(entry(path: childPath, base: nil, override: val))
        }
      }
    }
  }

  private static func entry(
    path: [String],
    base: SimpleTOMLValue?,
    override: SimpleTOMLValue?
  ) -> SnapzyConfigurationDiffEntry {
    SnapzyConfigurationDiffEntry(
      keyPath: path,
      dottedKey: path.joined(separator: "."),
      baseValue: base,
      overrideValue: override
    )
  }
}
