//
//  SnapzyConfigurationService+UserLayer.swift
//  Snapzy
//
//  Write-routing helpers for the user-config.toml override layer (Phase 04).
//  Called from SnapzyConfigurationService+Sync.swift when userLayer.isEnabled.
//

import Foundation

extension SnapzyConfigurationService {

  // MARK: - primary mode

  /// Skip built-in write; write lean user-config (changed keys vs built-in).
  /// Conflict detection mirrors built-in logic using the user-layer signature.
  func syncUserConfigPrimary(
    builtInURL: URL,
    userURL: URL
  ) throws -> SnapzyConfigurationSyncResult {
    let operationID = beginUserConfigOperation()

    let currentSource = exportTOML()
    guard let currentDoc = parsedDoc(source: currentSource) else {
      return SnapzyConfigurationSyncResult(status: .permissionRequired, fileURL: userURL)
    }

    let builtInDoc = loadDoc(at: builtInURL) ?? SimpleTOMLDocument()
    let existingUserDoc = loadDoc(at: userURL) ?? SimpleTOMLDocument()

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: currentDoc,
      builtInDoc: builtInDoc,
      userConfigDoc: existingUserDoc,
      mode: .primary
    )

    guard let updatedUserDoc = routing.userConfigDoc else {
      return SnapzyConfigurationSyncResult(status: .alreadyCurrent, fileURL: userURL)
    }

    let userConfigSource = updatedUserDoc.toTOML()
    let lastUserSig = defaults.string(forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature)

    let outcome = try Self.managedConfigFileQueue.sync {
      try Self.syncManagedConfigFile(
        currentSource: userConfigSource,
        fileURL: userURL,
        lastAppliedSignature: lastUserSig
      )
    }

    if let source = outcome.sourceToMarkApplied {
      markUserConfigAppliedIfLatest(source, operationID: operationID)
    }
    return outcome.result
  }

  // MARK: - perKey mode

  /// Update existing user-config keys with current values (lean set grows only if
  /// a key was already present). Best-effort: never creates user-config from scratch.
  @discardableResult
  func updateUserConfigPerKey(userURL: URL) throws -> SnapzyConfigurationSyncResult {
    let fm = FileManager.default
    guard fm.fileExists(atPath: userURL.path) else {
      return SnapzyConfigurationSyncResult(status: .alreadyCurrent, fileURL: userURL)
    }

    let currentSource = exportTOML()
    guard let currentDoc = parsedDoc(source: currentSource) else {
      return SnapzyConfigurationSyncResult(status: .alreadyCurrent, fileURL: userURL)
    }

    let existingUserDoc = loadDoc(at: userURL) ?? SimpleTOMLDocument()
    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: currentDoc,
      builtInDoc: SimpleTOMLDocument(),
      userConfigDoc: existingUserDoc,
      mode: .perKey
    )

    guard let updatedUserDoc = routing.userConfigDoc else {
      return SnapzyConfigurationSyncResult(status: .alreadyCurrent, fileURL: userURL)
    }

    let operationID = beginUserConfigOperation()
    let source = updatedUserDoc.toTOML()
    let lastUserSig = defaults.string(forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature)

    let outcome = try Self.managedConfigFileQueue.sync {
      try Self.syncManagedConfigFile(
        currentSource: source,
        fileURL: userURL,
        lastAppliedSignature: lastUserSig
      )
    }

    if let writtenSource = outcome.sourceToMarkApplied {
      markUserConfigAppliedIfLatest(writtenSource, operationID: operationID)
    }
    return outcome.result
  }

  // MARK: - Import user config (Phase 07 facade)

  /// Validate and write `url` as the new user-config override layer.
  /// Creates the parent directory if missing. Refreshes the user signature and
  /// re-applies the merged effective config.
  func importUserConfig(from url: URL) throws -> SnapzyConfigurationImportResult {
    let source = try String(contentsOf: url, encoding: .utf8)
    let validationIssues = SnapzyConfigurationImporter.validateTOML(source)
    guard !validationIssues.contains(where: { $0.severity == .error }) else {
      return SnapzyConfigurationImportResult(appliedChangeCount: 0, issues: validationIssues)
    }

    let userURL = resolvedUserConfigFileURL
    _ = beginUserConfigOperation()
    try Self.managedConfigFileQueue.sync {
      try FileManager.default.createDirectory(
        at: userURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try source.write(to: userURL, atomically: true, encoding: .utf8)
    }

    // Re-apply merged effective config with force: true.
    // The applyMergedIfNeeded call will record the signature itself upon success.
    return SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: resolvedConfigFileURL,
      userURL: userURL,
      defaults: defaults,
      force: true
    ).importResult ?? SnapzyConfigurationImportResult(appliedChangeCount: 0, issues: [])
  }

  // MARK: - Promote user overrides → built-in (Phase 06)

  /// Copy selected user-config leaf key values into built-in config.toml.
  /// User-config is NOT modified; its signature is NOT touched.
  /// Uses the built-in safe-write guard (conflicts respected).
  func promoteUserKeysToBuiltIn(_ keyPaths: [[String]]) throws {
    guard !keyPaths.isEmpty else { return }

    let userURL = resolvedUserConfigFileURL
    guard let userSource = try? String(contentsOf: userURL, encoding: .utf8),
          let userDoc = try? SimpleTOMLParser.parse(userSource)
    else { return }

    let access = beginAccessingConfigFile()
    defer { access.stop() }

    let builtInURL = access.url
    let builtInSource = (try? String(contentsOf: builtInURL, encoding: .utf8)) ?? ""
    var builtInDoc = (try? SimpleTOMLParser.parse(builtInSource)) ?? SimpleTOMLDocument()

    // Apply each selected key's user value into the built-in doc.
    for path in keyPaths {
      if let value = userDoc.value(at: path) {
        try? builtInDoc.set(value, at: path)
      }
    }

    let updatedBuiltInSource = builtInDoc.toTOML()
    let lastSig = defaults.string(forKey: PreferencesKeys.configurationLastAppliedSignature)
    let operationID = beginManagedConfigOperation()

    let outcome = try Self.managedConfigFileQueue.sync {
      try Self.syncManagedConfigFile(
        currentSource: updatedBuiltInSource,
        fileURL: builtInURL,
        lastAppliedSignature: lastSig
      )
    }
    if let source = outcome.sourceToMarkApplied {
      markCurrentFileAppliedIfLatest(source, operationID: operationID)
    }
  }

  // MARK: - Diff for promote sheet (Phase 06)

  /// Returns differing leaf keys between user-config and built-in.
  func userConfigDiff() -> [SnapzyConfigurationDiffEntry] {
    let builtInDoc = loadDoc(at: resolvedConfigFileURL) ?? SimpleTOMLDocument()
    let userDoc = loadDoc(at: resolvedUserConfigFileURL) ?? SimpleTOMLDocument()
    return SnapzyConfigurationDiff.diff(base: builtInDoc, override: userDoc)
      .filter { $0.isChanged || $0.isOnlyInOverride }
  }

  // MARK: - Private helpers

  func parsedDoc(source: String) -> SimpleTOMLDocument? {
    try? SimpleTOMLParser.parse(source)
  }

  func loadDoc(at url: URL) -> SimpleTOMLDocument? {
    guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    return try? SimpleTOMLParser.parse(source)
  }
}
