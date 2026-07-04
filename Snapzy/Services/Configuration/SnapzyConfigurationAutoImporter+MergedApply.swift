//
//  SnapzyConfigurationAutoImporter+MergedApply.swift
//  Snapzy
//
//  Launch-time apply when user-config layer is enabled:
//  parse built-in, parse user-config, deep-merge, import merged doc.
//

import Foundation

@MainActor
extension SnapzyConfigurationAutoImporter {

  /// Apply built-in + user-config overlay on launch.
  ///
  /// - Reads both files; missing user-config falls through to built-in-only import.
  /// - Skip if neither file changed since last launch (both signatures match).
  /// - On user parse error: warn, fall back to built-in-only apply.
  /// - schema_version mismatch in either layer: warn + continue (per spec).
  static func applyMergedIfNeeded(
    builtInURL: URL,
    userURL: URL,
    defaults: UserDefaults = .standard,
    force: Bool = false
  ) -> SnapzyConfigurationAutoImportResult {
    let fileManager = FileManager.default

    guard fileManager.fileExists(atPath: builtInURL.path) else {
      return SnapzyConfigurationAutoImportResult(
        status: .skippedMissingFile,
        fileURL: builtInURL,
        importResult: nil,
        errorMessage: nil
      )
    }

    let builtInSource: String
    do {
      builtInSource = try String(contentsOf: builtInURL, encoding: .utf8)
    } catch {
      return SnapzyConfigurationAutoImportResult(
        status: .failed,
        fileURL: builtInURL,
        importResult: nil,
        errorMessage: error.localizedDescription
      )
    }

    let userSource: String?
    if fileManager.fileExists(atPath: userURL.path) {
      userSource = try? String(contentsOf: userURL, encoding: .utf8)
    } else {
      userSource = nil
    }

    // Skip if both files are identical to last launch.
    let builtInSig = contentSignature(for: builtInSource)
    let userSig = userSource.map { contentSignature(for: $0) } ?? ""
    let lastBuiltInSig = defaults.string(forKey: PreferencesKeys.configurationLastAppliedSignature) ?? ""
    let lastUserSig = defaults.string(forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature) ?? ""
    if !force && builtInSig == lastBuiltInSig && userSig == lastUserSig {
      return SnapzyConfigurationAutoImportResult(
        status: .skippedUnchanged,
        fileURL: builtInURL,
        importResult: nil,
        errorMessage: nil
      )
    }

    // Parse + optionally merge.
    let (mergedDoc, fatalError, mergeWarnings) = parsedMergedDocument(
      builtInSource: builtInSource,
      userSource: userSource
    )

    guard let doc = mergedDoc else {
      return SnapzyConfigurationAutoImportResult(
        status: .failed,
        fileURL: builtInURL,
        importResult: nil,
        errorMessage: fatalError
      )
    }

    var importResult = SnapzyConfigurationImporter.importDocument(doc, defaults: defaults)
    if !mergeWarnings.isEmpty {
      let warningIssues = mergeWarnings.map {
        SnapzyConfigurationIssue(severity: .warning, message: $0)
      }
      importResult = SnapzyConfigurationImportResult(
        appliedChangeCount: importResult.appliedChangeCount,
        issues: importResult.issues + warningIssues
      )
    }

    if importResult.hasErrors {
      return SnapzyConfigurationAutoImportResult(
        status: .failed,
        fileURL: builtInURL,
        importResult: importResult,
        errorMessage: nil
      )
    }

    // Stamp both signatures only after successful apply.
    defaults.set(builtInSig, forKey: PreferencesKeys.configurationLastAppliedSignature)
    defaults.set(userSig, forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature)

    return SnapzyConfigurationAutoImportResult(
      status: .applied,
      fileURL: builtInURL,
      importResult: importResult,
      errorMessage: nil
    )
  }

  // MARK: - Private helpers

  /// Returns `(document, fatalErrorMessage, mergeWarnings)`.
  /// `fatalErrorMessage` is non-nil only when built-in fails to parse (unrecoverable).
  private static func parsedMergedDocument(
    builtInSource: String,
    userSource: String?
  ) -> (document: SimpleTOMLDocument?, errorMessage: String?, warnings: [String]) {
    let builtInDoc: SimpleTOMLDocument
    do {
      builtInDoc = try SimpleTOMLParser.parse(builtInSource)
    } catch {
      return (nil, error.localizedDescription, [])
    }

    guard let userSrc = userSource else {
      return (builtInDoc, nil, [])
    }

    let userDoc: SimpleTOMLDocument
    do {
      userDoc = try SimpleTOMLParser.parse(userSrc)
    } catch {
      let warning = "user-config parse error (using built-in only): \(error.localizedDescription)"
      return (builtInDoc, nil, [warning])
    }

    let (merged, warnings) = builtInDoc.merging(override: userDoc)
    return (merged, nil, warnings)
  }
}
