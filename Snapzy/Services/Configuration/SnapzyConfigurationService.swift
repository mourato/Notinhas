//
//  SnapzyConfigurationService.swift
//  Snapzy
//
//  Facade for exporting and importing Snapzy TOML configuration files.
//

import Foundation

@MainActor
final class SnapzyConfigurationService {
  static let shared = SnapzyConfigurationService()

  private let defaults = UserDefaults.standard

  private init() {}

  struct ScopedAccess: Sendable {
    let url: URL
    private let accessURL: URL
    private let didStartAccessing: Bool

    init(url: URL, accessURL: URL, didStartAccessing: Bool) {
      self.url = url
      self.accessURL = accessURL
      self.didStartAccessing = didStartAccessing
    }

    nonisolated func stop() {
      if didStartAccessing {
        accessURL.stopAccessingSecurityScopedResource()
      }
    }
  }

  var suggestedConfigURL: URL {
    SnapzyConfigurationPaths.suggestedConfigURL
  }

  var suggestedConfigDirectoryURL: URL {
    SnapzyConfigurationPaths.suggestedConfigDirectoryURL
  }

  var suggestedConfigParentDirectoryURL: URL {
    suggestedConfigDirectoryURL.deletingLastPathComponent()
  }

  var suggestedConfigRootDirectoryURL: URL {
    SnapzyConfigurationPaths.userHomeDirectory
  }

  var resolvedConfigFileURL: URL {
    if let fileURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationFileBookmark) {
      return fileURL
    }
    if let directoryURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationDirectoryBookmark) {
      return configFileURL(inDirectory: directoryURL)
    }
    return suggestedConfigURL
  }

  var hasPersistedConfigPermission: Bool {
    guard let accessURL = resolvedConfigAccessURL(for: resolvedConfigFileURL) else {
      return false
    }

    let didStart = accessURL.startAccessingSecurityScopedResource()
    if didStart {
      accessURL.stopAccessingSecurityScopedResource()
    }
    return didStart
  }

  var needsUserSelectedConfigAccess: Bool {
    isRunningSandboxed && !hasPersistedConfigPermission
  }

  func exportTOML() -> String {
    SnapzyConfigurationExporter.exportTOML()
  }

  static func syncDecision(
    fileSource: String,
    currentSource: String,
    defaults: UserDefaults = .standard
  ) -> SnapzyConfigurationSyncDecision {
    if fileSource == currentSource {
      return .alreadyCurrent
    }

    if SnapzyConfigurationAutoImporter.isCurrentFileApplied(fileSource, defaults: defaults) {
      return .syncAutomatically
    }

    return .askBeforeReplacing
  }

  func export(to url: URL) throws {
    let toml = exportTOML()
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try toml.write(to: url, atomically: true, encoding: .utf8)

    if isSuggestedConfigFile(url) {
      SnapzyConfigurationAutoImporter.markCurrentFileApplied(toml, defaults: defaults)
    }
  }

  func importTOML(_ source: String) -> SnapzyConfigurationImportResult {
    SnapzyConfigurationImporter.importTOML(source)
  }

  func `import`(from url: URL) throws -> SnapzyConfigurationImportResult {
    let source = try String(contentsOf: url, encoding: .utf8)
    return importTOML(source)
  }

  func importBackupReplacingManagedConfig(
    from url: URL,
    managedConfigURL: URL? = nil
  ) throws -> SnapzyConfigurationImportResult {
    let source = try String(contentsOf: url, encoding: .utf8)
    let validationIssues = SnapzyConfigurationImporter.validateTOML(source)

    guard !validationIssues.contains(where: { $0.severity == .error }) else {
      return SnapzyConfigurationImportResult(appliedChangeCount: 0, issues: validationIssues)
    }

    try replaceManagedConfig(with: source, at: managedConfigURL)
    let result = importTOML(source)
    if !result.hasErrors {
      SnapzyConfigurationAutoImporter.markCurrentFileApplied(source, defaults: defaults)
    }
    return result
  }

  func restoreDefaultsReplacingManagedConfig() throws -> SnapzyConfigurationImportResult {
    let source = SnapzyConfigurationDefaultDocument.toml()
    let validationIssues = SnapzyConfigurationImporter.validateTOML(source)

    guard !validationIssues.contains(where: { $0.severity == .error }) else {
      return SnapzyConfigurationImportResult(appliedChangeCount: 0, issues: validationIssues)
    }

    try replaceManagedConfig(with: source)

    let result = importTOML(source)
    if !result.hasErrors {
      CloudManager.shared.clearConfiguration()
      SnapzyConfigurationAutoImporter.markCurrentFileApplied(source, defaults: defaults)
    }
    return result
  }

  func prepareManagedConfigForOpening(at url: URL? = nil) throws -> SnapzyConfigurationSyncResult {
    let access = beginAccessingConfigFile(url)
    defer { access.stop() }

    let fileManager = FileManager.default
    let directory = access.url.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    let currentSource = exportTOML()
    guard fileManager.fileExists(atPath: access.url.path) else {
      try writeManagedConfig(currentSource, to: access.url)
      return SnapzyConfigurationSyncResult(status: .synced, fileURL: access.url)
    }

    let fileSource = try String(contentsOf: access.url, encoding: .utf8)
    switch Self.syncDecision(fileSource: fileSource, currentSource: currentSource, defaults: defaults) {
    case .alreadyCurrent:
      SnapzyConfigurationAutoImporter.markCurrentFileApplied(fileSource, defaults: defaults)
      return SnapzyConfigurationSyncResult(status: .alreadyCurrent, fileURL: access.url)
    case .syncAutomatically:
      try writeManagedConfig(currentSource, to: access.url)
      return SnapzyConfigurationSyncResult(status: .synced, fileURL: access.url)
    case .askBeforeReplacing:
      return SnapzyConfigurationSyncResult(status: .needsConfirmation, fileURL: access.url)
    }
  }

  @discardableResult
  func syncManagedConfigToCurrentSettings(at url: URL? = nil) throws -> URL {
    let source = exportTOML()
    let targetURL = try replaceManagedConfig(with: source, at: url)
    SnapzyConfigurationAutoImporter.markCurrentFileApplied(source, defaults: defaults)
    return targetURL
  }

  @discardableResult
  func replaceManagedConfig(with source: String, at url: URL? = nil) throws -> URL {
    let targetURL = url ?? resolvedConfigFileURL
    let access = beginAccessingConfigFile(targetURL)
    defer { access.stop() }

    let directory = targetURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try source.write(to: targetURL, atomically: true, encoding: .utf8)
    return targetURL
  }

  @discardableResult
  func ensureSuggestedConfigExists() throws -> URL {
    try ensureConfigExists(at: resolvedConfigFileURL)
  }

  @discardableResult
  func ensureConfigExists(at url: URL) throws -> URL {
    let access = beginAccessingConfigFile(url)
    defer { access.stop() }

    let fileManager = FileManager.default
    let directory = url.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    if !fileManager.fileExists(atPath: url.path) {
      try export(to: url)
    }

    return url
  }

  func configFileURL(inDirectory directoryURL: URL) -> URL {
    directoryURL
      .standardizedFileURL
      .appendingPathComponent("config.toml")
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

  func rememberConfigFileAccess(_ url: URL) throws {
    try rememberAccess(to: url, key: PreferencesKeys.configurationFileBookmark)
  }

  func rememberConfigDirectoryAccess(_ url: URL) throws {
    try rememberAccess(to: url, key: PreferencesKeys.configurationDirectoryBookmark)
  }

  func beginAccessingConfigFile(_ targetURL: URL? = nil) -> ScopedAccess {
    let fileURL = targetURL?.standardizedFileURL ?? resolvedConfigFileURL
    let accessURL = resolvedConfigAccessURL(for: fileURL) ?? fileURL
    let didStart = accessURL.startAccessingSecurityScopedResource()
    return ScopedAccess(url: fileURL, accessURL: accessURL, didStartAccessing: didStart)
  }

  private func rememberAccess(to url: URL, key: String) throws {
    let bookmarkData = try url.standardizedFileURL.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    defaults.set(bookmarkData, forKey: key)
  }

  private func resolvedConfigAccessURL(for targetURL: URL) -> URL? {
    if let fileURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationFileBookmark),
       normalizedPath(fileURL) == normalizedPath(targetURL) {
      return fileURL
    }

    if let directoryURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationDirectoryBookmark) {
      let targetPath = normalizedPath(targetURL)
      let directoryPath = normalizedPath(directoryURL)
      if targetPath == directoryPath || targetPath.hasPrefix(directoryPath + "/") {
        return directoryURL
      }
    }

    return nil
  }

  private func resolveBookmarkURL(forKey key: String, removeInvalidBookmark: Bool = true) -> URL? {
    guard let bookmarkData = defaults.data(forKey: key) else {
      return nil
    }

    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ).standardizedFileURL

      if isStale {
        try? rememberAccess(to: url, key: key)
      }

      return url
    } catch {
      if removeInvalidBookmark {
        defaults.removeObject(forKey: key)
      }
      return nil
    }
  }

  private func writeManagedConfig(_ source: String, to url: URL) throws {
    try source.write(to: url, atomically: true, encoding: .utf8)
    SnapzyConfigurationAutoImporter.markCurrentFileApplied(source, defaults: defaults)
  }

  private func normalizedPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  private var isRunningSandboxed: Bool {
    ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
  }
}
