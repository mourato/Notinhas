//
//  SnapzyConfigurationAutoImporterSignatureTests.swift
//  SnapzyTests
//
//  Dual-signature tracking tests for applyMergedIfNeeded (Phase 03).
//  Merge-value behavior tests → SnapzyConfigurationAutoImporterMergedApplyTests.swift
//

import XCTest
@testable import Snapzy

@MainActor
final class SnapzyConfigurationAutoImporterSignatureTests: XCTestCase {
  private var tempDir: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SnapzySignatureTests-\(UUID().uuidString)", isDirectory: true)
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

  /// Neither file changed → skipped unchanged; both signatures persisted.
  func testSkipsUnchangedWhenBothSignaturesMatch() throws {
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

    let first = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(first.status, .applied)

    let second = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(second.status, .skippedUnchanged)
  }

  /// Built-in signature key and user-config signature key are stored independently.
  func testDualSignaturesStoredSeparately() throws {
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

    _ = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )

    let builtInSig = defaults.string(forKey: PreferencesKeys.configurationLastAppliedSignature)
    let userSig = defaults.string(forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature)

    XCTAssertNotNil(builtInSig)
    XCTAssertNotNil(userSig)
    XCTAssertNotEqual(builtInSig, userSig, "each file gets its own signature")
  }

  /// Changing only user-config triggers re-apply even when built-in is unchanged.
  func testChangingOnlyUserConfigTriggersReApply() throws {
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

    let first = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(first.status, .applied)
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp")

    try write("""
    schema_version = 1
    [capture.screenshot]
    format = "jpeg"
    """, to: userURL())

    let second = SnapzyConfigurationAutoImporter.applyMergedIfNeeded(
      builtInURL: builtInURL(),
      userURL: userURL(),
      defaults: defaults
    )
    XCTAssertEqual(second.status, .applied)
    XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "jpeg")
  }
}
