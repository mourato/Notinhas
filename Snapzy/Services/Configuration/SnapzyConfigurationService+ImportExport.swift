//
//  SnapzyConfigurationService+ImportExport.swift
//  Snapzy
//
//  File-level import, export, backup, restore, and replace operations.
//

import Foundation

extension SnapzyConfigurationService {

  func export(to url: URL) throws {
    let toml = exportTOML()
    let shouldMarkApplied = isSuggestedConfigFile(url)
    let operationID = shouldMarkApplied ? beginManagedConfigOperation() : nil
    try Self.managedConfigFileQueue.sync {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try toml.write(to: url, atomically: true, encoding: .utf8)
    }
    if shouldMarkApplied, let operationID {
      markCurrentFileAppliedIfLatest(toml, operationID: operationID)
    }
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
    let operationID = beginManagedConfigOperation()
    try replaceManagedConfig(with: source, at: managedConfigURL)
    let result = importTOML(source)
    if !result.hasErrors { markCurrentFileAppliedIfLatest(source, operationID: operationID) }
    return result
  }

  func restoreDefaultsReplacingManagedConfig() throws -> SnapzyConfigurationImportResult {
    let source = SnapzyConfigurationDefaultDocument.toml()
    let validationIssues = SnapzyConfigurationImporter.validateTOML(source)
    guard !validationIssues.contains(where: { $0.severity == .error }) else {
      return SnapzyConfigurationImportResult(appliedChangeCount: 0, issues: validationIssues)
    }
    let operationID = beginManagedConfigOperation()
    try replaceManagedConfig(with: source)
    let result = importTOML(source)
    if !result.hasErrors {
      CloudManager.shared.clearConfiguration()
      markCurrentFileAppliedIfLatest(source, operationID: operationID)
    }
    return result
  }

  @discardableResult
  func replaceManagedConfig(with source: String, at url: URL? = nil) throws -> URL {
    let targetURL = url ?? resolvedConfigFileURL
    let access = beginAccessingConfigFile(targetURL)
    defer { access.stop() }
    try Self.managedConfigFileQueue.sync {
      try FileManager.default.createDirectory(
        at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try source.write(to: targetURL, atomically: true, encoding: .utf8)
    }
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
    let toml = exportTOML()
    let shouldMarkApplied = isSuggestedConfigFile(url)
    var didCreateFile = false
    try Self.managedConfigFileQueue.sync {
      let fm = FileManager.default
      try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      if !fm.fileExists(atPath: url.path) {
        try toml.write(to: url, atomically: true, encoding: .utf8)
        didCreateFile = true
      }
    }
    if didCreateFile && shouldMarkApplied {
      let operationID = beginManagedConfigOperation()
      markCurrentFileAppliedIfLatest(toml, operationID: operationID)
    }
    return url
  }
}
