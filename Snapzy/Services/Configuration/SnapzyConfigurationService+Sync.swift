//
//  SnapzyConfigurationService+Sync.swift
//  Snapzy
//
//  Routing-aware debounce sync for built-in config.toml.
//  User-layer write helpers → SnapzyConfigurationService+UserLayer.swift
//  Import/export/replace → SnapzyConfigurationService+ImportExport.swift
//

import Foundation

extension SnapzyConfigurationService {

  // MARK: - Public routing-aware sync

  func prepareManagedConfigForOpening(at url: URL? = nil) throws -> SnapzyConfigurationSyncResult {
    try syncManagedConfigIfSafe(at: url)
  }

  func syncManagedConfigIfSafe(at url: URL? = nil) throws -> SnapzyConfigurationSyncResult {
    if url == nil && needsUserSelectedConfigAccess {
      return SnapzyConfigurationSyncResult(status: .permissionRequired, fileURL: resolvedConfigFileURL)
    }

    let layer = userLayerState
    if layer.isEnabled {
      return try syncUserConfigPrimary(builtInURL: url ?? resolvedConfigFileURL, userURL: layer.resolvedFileURL)
    }

    return try syncBuiltInOnly(at: url)
  }

  func syncManagedConfigIfSafeInBackground(at url: URL? = nil) async throws -> SnapzyConfigurationSyncResult {
    if url == nil && needsUserSelectedConfigAccess {
      return SnapzyConfigurationSyncResult(status: .permissionRequired, fileURL: resolvedConfigFileURL)
    }

    let layer = userLayerState
    if layer.isEnabled {
      return try await Task.detached(priority: .utility) { [self] in
        try await MainActor.run {
          try self.syncUserConfigPrimary(
            builtInURL: url ?? self.resolvedConfigFileURL,
            userURL: layer.resolvedFileURL)
        }
      }.value
    }

    return try await syncBuiltInOnlyInBackground(at: url)
  }

  // MARK: - Forced sync after confirmation

  @discardableResult
  func syncManagedConfigToCurrentSettings(at url: URL? = nil) throws -> URL {
    let operationID = beginManagedConfigOperation()
    let source = exportTOML()
    let targetURL = try replaceManagedConfig(with: source, at: url)
    markCurrentFileAppliedIfLatest(source, operationID: operationID)
    return targetURL
  }

  @discardableResult
  func syncManagedConfigToCurrentSettingsIfUnchanged(
    at url: URL? = nil,
    expectedFileSignature: String?
  ) throws -> URL {
    let operationID = beginManagedConfigOperation()
    let source = exportTOML()
    let targetURL = url ?? resolvedConfigFileURL
    let access = beginAccessingConfigFile(targetURL)
    defer { access.stop() }

    try Self.managedConfigFileQueue.sync {
      let fm = FileManager.default
      try fm.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if let expectedFileSignature {
        guard fm.fileExists(atPath: targetURL.path) else {
          throw SnapzyConfigurationSyncError.fileChangedSinceConfirmation
        }
        let currentFileSig = SnapzyConfigurationAutoImporter.contentSignature(
          for: try String(contentsOf: targetURL, encoding: .utf8))
        guard currentFileSig == expectedFileSignature else {
          throw SnapzyConfigurationSyncError.fileChangedSinceConfirmation
        }
      }
      try source.write(to: targetURL, atomically: true, encoding: .utf8)
    }
    markCurrentFileAppliedIfLatest(source, operationID: operationID)
    return targetURL
  }

  // MARK: - Private built-in-only paths

  private func syncBuiltInOnly(at url: URL?) throws -> SnapzyConfigurationSyncResult {
    let operationID = beginManagedConfigOperation()
    let currentSource = exportTOML()
    let access = beginAccessingConfigFile(url)
    defer { access.stop() }
    let lastSig = defaults.string(forKey: PreferencesKeys.configurationLastAppliedSignature)
    let outcome = try Self.managedConfigFileQueue.sync {
      try Self.syncManagedConfigFile(
        currentSource: currentSource, fileURL: access.url, lastAppliedSignature: lastSig)
    }
    if let source = outcome.sourceToMarkApplied {
      markCurrentFileAppliedIfLatest(source, operationID: operationID)
    }
    return outcome.result
  }

  private func syncBuiltInOnlyInBackground(at url: URL?) async throws -> SnapzyConfigurationSyncResult {
    let operationID = beginManagedConfigOperation()
    let currentSource = exportTOML()
    let lastSig = defaults.string(forKey: PreferencesKeys.configurationLastAppliedSignature)
    let access = beginAccessingConfigFile(url)
    defer { access.stop() }
    let fileURL = access.url
    let outcome = try await Task.detached(priority: .utility) {
      try Self.managedConfigFileQueue.sync {
        try Self.syncManagedConfigFile(
          currentSource: currentSource, fileURL: fileURL, lastAppliedSignature: lastSig)
      }
    }.value
    if let source = outcome.sourceToMarkApplied {
      markCurrentFileAppliedIfLatest(source, operationID: operationID)
    }
    return outcome.result
  }

  // MARK: - Shared file-sync primitive (nonisolated)

  nonisolated static func syncManagedConfigFile(
    currentSource: String,
    fileURL: URL,
    lastAppliedSignature: String?
  ) throws -> ManagedConfigFileSyncOutcome {
    let fm = FileManager.default
    try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let currentSig = SnapzyConfigurationAutoImporter.contentSignature(for: currentSource)

    guard fm.fileExists(atPath: fileURL.path) else {
      try currentSource.write(to: fileURL, atomically: true, encoding: .utf8)
      return ManagedConfigFileSyncOutcome(
        result: SnapzyConfigurationSyncResult(
          status: .synced, fileURL: fileURL,
          observedFileSignature: nil, exportedSettingsSignature: currentSig),
        sourceToMarkApplied: currentSource)
    }

    let fileSource = try String(contentsOf: fileURL, encoding: .utf8)
    let fileSig = SnapzyConfigurationAutoImporter.contentSignature(for: fileSource)

    if fileSource == currentSource {
      return ManagedConfigFileSyncOutcome(
        result: SnapzyConfigurationSyncResult(
          status: .alreadyCurrent, fileURL: fileURL,
          observedFileSignature: fileSig, exportedSettingsSignature: currentSig),
        sourceToMarkApplied: fileSource)
    }

    if lastAppliedSignature == fileSig {
      try currentSource.write(to: fileURL, atomically: true, encoding: .utf8)
      return ManagedConfigFileSyncOutcome(
        result: SnapzyConfigurationSyncResult(
          status: .synced, fileURL: fileURL,
          observedFileSignature: fileSig, exportedSettingsSignature: currentSig),
        sourceToMarkApplied: currentSource)
    }

    return ManagedConfigFileSyncOutcome(
      result: SnapzyConfigurationSyncResult(
        status: .needsConfirmation, fileURL: fileURL,
        observedFileSignature: fileSig, exportedSettingsSignature: currentSig),
      sourceToMarkApplied: nil)
  }
}
