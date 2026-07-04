//
//  SnapzyConfigurationService.swift
//  Snapzy
//
//  Facade for exporting and importing Snapzy TOML configuration files.
//  Sync operations → SnapzyConfigurationService+Sync.swift
//  User-layer routing → SnapzyConfigurationService+UserLayer.swift
//  Bookmark helpers → SnapzyConfigurationService+Bookmarks.swift
//

import Foundation

@MainActor
final class SnapzyConfigurationService {
  static let shared = SnapzyConfigurationService()

  nonisolated static let managedConfigFileQueue = DispatchQueue(
    label: "com.trongduong.snapzy.configuration.managed-file",
    qos: .utility
  )

  let defaults = UserDefaults.standard
  var nextManagedConfigOperationID = 0
  var latestManagedConfigOperationID = 0
  var nextUserConfigOperationID = 0
  var latestUserConfigOperationID = 0

  private init() {}

  // MARK: - Nested types

  struct ScopedAccess: Sendable {
    let url: URL
    let accessURL: URL
    let didStartAccessing: Bool

    nonisolated func stop() {
      if didStartAccessing { accessURL.stopAccessingSecurityScopedResource() }
    }
  }

  struct ManagedConfigFileSyncOutcome: Sendable {
    let result: SnapzyConfigurationSyncResult
    let sourceToMarkApplied: String?
  }

  // MARK: - Computed properties

  var suggestedConfigURL: URL { SnapzyConfigurationPaths.suggestedConfigURL }
  var suggestedConfigDirectoryURL: URL { SnapzyConfigurationPaths.suggestedConfigDirectoryURL }
  var suggestedConfigParentDirectoryURL: URL { suggestedConfigDirectoryURL.deletingLastPathComponent() }
  var suggestedConfigRootDirectoryURL: URL { SnapzyConfigurationPaths.userHomeDirectory }

  var resolvedConfigFileURL: URL {
    if let fileURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationFileBookmark) {
      return fileURL
    }
    if let directoryURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationDirectoryBookmark) {
      return configFileURL(inDirectory: directoryURL)
    }
    return suggestedConfigURL
  }

  var resolvedUserConfigFileURL: URL {
    SnapzyConfigurationUserLayerState(defaults: defaults).resolvedFileURL
  }

  var userLayerState: SnapzyConfigurationUserLayerState {
    SnapzyConfigurationUserLayerState(defaults: defaults)
  }

  var hasPersistedConfigPermission: Bool {
    guard let accessURL = resolvedConfigAccessURL(for: resolvedConfigFileURL) else { return false }
    let didStart = accessURL.startAccessingSecurityScopedResource()
    if didStart { accessURL.stopAccessingSecurityScopedResource() }
    return didStart
  }

  var needsUserSelectedConfigAccess: Bool {
    isRunningSandboxed && !hasPersistedConfigPermission
  }

  // MARK: - Import / export

  func exportTOML() -> String { SnapzyConfigurationExporter.exportTOML() }
  func importTOML(_ source: String) -> SnapzyConfigurationImportResult {
    let layer = userLayerState
    guard layer.isEnabled else {
      return SnapzyConfigurationImporter.importTOML(source, defaults: defaults)
    }

    let builtInDoc: SimpleTOMLDocument
    do {
      builtInDoc = try SimpleTOMLParser.parse(source)
    } catch {
      return SnapzyConfigurationImportResult(
        appliedChangeCount: 0,
        issues: [SnapzyConfigurationIssue(severity: .error, message: error.localizedDescription)]
      )
    }

    let userURL = layer.resolvedFileURL
    let userSource = (try? String(contentsOf: userURL, encoding: .utf8)) ?? ""
    let userDoc = (try? SimpleTOMLParser.parse(userSource)) ?? SimpleTOMLDocument()

    let (mergedDoc, warnings) = builtInDoc.merging(override: userDoc)
    var result = SnapzyConfigurationImporter.importDocument(mergedDoc, defaults: defaults)
    if !warnings.isEmpty {
      let warningIssues = warnings.map { SnapzyConfigurationIssue(severity: .warning, message: $0) }
      result = SnapzyConfigurationImportResult(
        appliedChangeCount: result.appliedChangeCount,
        issues: result.issues + warningIssues
      )
    }

    if !result.hasErrors {
      let builtInSig = SnapzyConfigurationAutoImporter.contentSignature(for: source)
      let userSig = SnapzyConfigurationAutoImporter.contentSignature(for: userSource)
      defaults.set(builtInSig, forKey: PreferencesKeys.configurationLastAppliedSignature)
      defaults.set(userSig, forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature)
    }

    return result
  }
  func `import`(from url: URL) throws -> SnapzyConfigurationImportResult {
    try importTOML(String(contentsOf: url, encoding: .utf8))
  }

  static func syncDecision(
    fileSource: String,
    currentSource: String,
    defaults: UserDefaults = .standard
  ) -> SnapzyConfigurationSyncDecision {
    if fileSource == currentSource { return .alreadyCurrent }
    if SnapzyConfigurationAutoImporter.isCurrentFileApplied(fileSource, defaults: defaults) { return .syncAutomatically }
    return .askBeforeReplacing
  }

  // MARK: - Operation guards

  func beginManagedConfigOperation() -> Int {
    nextManagedConfigOperationID += 1
    latestManagedConfigOperationID = nextManagedConfigOperationID
    return nextManagedConfigOperationID
  }

  func markCurrentFileAppliedIfLatest(_ source: String, operationID: Int) {
    guard operationID == latestManagedConfigOperationID else { return }
    SnapzyConfigurationAutoImporter.markCurrentFileApplied(source, defaults: defaults)
  }

  func beginUserConfigOperation() -> Int {
    nextUserConfigOperationID += 1
    latestUserConfigOperationID = nextUserConfigOperationID
    return nextUserConfigOperationID
  }

  func markUserConfigAppliedIfLatest(_ source: String, operationID: Int) {
    guard operationID == latestUserConfigOperationID else { return }
    defaults.set(
      SnapzyConfigurationAutoImporter.contentSignature(for: source),
      forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature
    )
  }

  // MARK: - File access

  func beginAccessingConfigFile(_ targetURL: URL? = nil) -> ScopedAccess {
    let fileURL = targetURL?.standardizedFileURL ?? resolvedConfigFileURL
    let accessURL = resolvedConfigAccessURL(for: fileURL) ?? fileURL
    let didStart = accessURL.startAccessingSecurityScopedResource()
    return ScopedAccess(url: fileURL, accessURL: accessURL, didStartAccessing: didStart)
  }

  func configFileURL(inDirectory directoryURL: URL) -> URL {
    directoryURL.standardizedFileURL.appendingPathComponent("config.toml")
  }

  func isSuggestedConfigDirectory(_ url: URL) -> Bool {
    normalizedPath(url) == normalizedPath(suggestedConfigDirectoryURL)
  }

  func isSuggestedConfigParentDirectory(_ url: URL) -> Bool {
    normalizedPath(url) == normalizedPath(suggestedConfigParentDirectoryURL)
  }

  func isSuggestedConfigRootDirectory(_ url: URL) -> Bool {
    normalizedPath(url) == normalizedPath(suggestedConfigRootDirectoryURL)
  }

  func isSuggestedConfigFile(_ url: URL) -> Bool {
    normalizedPath(url) == normalizedPath(suggestedConfigURL)
  }
}
