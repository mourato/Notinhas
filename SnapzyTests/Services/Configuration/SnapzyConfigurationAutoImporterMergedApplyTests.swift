//
//  SnapzyConfigurationAutoImporterMergedApplyTests.swift
//  SnapzyTests
//
//  Merge-value behavior tests for applyMergedIfNeeded (Phase 03).
//  Signature-tracking tests → SnapzyConfigurationAutoImporterSignatureTests.swift
//

import XCTest
@testable import Snapzy

@MainActor
final class SnapzyConfigurationAutoImporterMergedApplyTests: XCTestCase {
  private var tempDir: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SnapzyMergedApplyTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDir)
    tempDir = nil
    try super.tearDownWithError()
  }

  private func builtInURL() -> URL { tempDir.appendingPathComponent("config.toml") }
  private func userURL() -> URL { tempDir.appendingPathComponent("user-config.toml") }

  private func write(_ source: String, to url: URL) throws {
    try source.write(to: url, atomically: true, encoding: .utf8)
  }

  // MARK: - Tests

  /// User-config value overrides the same key in built-in.
  func testUserConfigValueOverridesBuiltIn() throws {
    let defaults = UserDefaultsFactory.make()
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "png"
    show_cursor = false
    """, to: builtInURL())
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "webp"
    """, to: userURL())

    let result = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )

    XCTAssertEqual(result.status, .applied)
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp", "user-config wins")
    XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotShowCursor) as? Bool, false, "built-in key inherited")
  }

  /// Keys absent from user-config are inherited from built-in.
  func testAbsentUserKeysInheritFromBuiltIn() throws {
    let defaults = UserDefaultsFactory.make()
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "jpeg"
    show_cursor = true
    """, to: builtInURL())
    try write("""
    schema_version = 1
    """, to: userURL())

    let result = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )

    XCTAssertEqual(result.status, .applied)
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "jpeg")
    XCTAssertEqual(defaults.object(forKey: PreferencesKeys.screenshotShowCursor) as? Bool, true)
  }

  /// When user-config file is absent, built-in is applied as normal.
  func testMissingUserConfigAppliesBuiltInOnly() throws {
    let defaults = UserDefaultsFactory.make()
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "png"
    """, to: builtInURL())

    let result = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )

    XCTAssertEqual(result.status, .applied)
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "png")
  }

  /// Invalid TOML in user-config → warning issued, falls back to built-in only.
  func testUserConfigParseErrorFallsBackToBuiltIn() throws {
    let defaults = UserDefaultsFactory.make()
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "jpeg"
    """, to: builtInURL())
    try write("this is not valid [[[ toml", to: userURL())

    let result = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )

    XCTAssertEqual(result.status, .applied, "still applied using built-in only")
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "jpeg", "built-in value applied")
    let warnings = result.importResult?.issues.filter { $0.severity == .warning } ?? []
    XCTAssertFalse(warnings.isEmpty, "warning emitted for user parse error")
  }

  /// When force = true, merge and apply configuration regardless of cached signature.
  func testApplyMergedWithForceFlag() throws {
    let defaults = UserDefaultsFactory.make()
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "png"
    """, to: builtInURL())
    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "webp"
    """, to: userURL())

    // 1. Initial apply (stores signatures)
    let result1 = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(result1.status, .applied)

    // 2. Normal apply again (skipped because signatures are unchanged)
    let result2 = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(result2.status, .skippedUnchanged)

    // 3. Force apply again (should not be skipped)
    let result3 = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults,
      force: true
    )
    XCTAssertEqual(result3.status, .applied)
  }
}
