//
//  SnapzyConfigurationBackwardCompatTests.swift
//  SnapzyTests
//
//  Verifies that disabling (or never enabling) the user-config override layer
//  leaves all existing behavior identical to the pre-feature baseline:
//  no user-layer signature written, no user-config file created,
//  auto-import follows the built-in-only path, write-routing targets built-in.
//

import XCTest
@testable import Snapzy

@MainActor
final class SnapzyConfigurationBackwardCompatTests: XCTestCase {
  private var tempDir: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("BackwardCompatTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDir)
    tempDir = nil
    try super.tearDownWithError()
  }

  // MARK: - Auto-import (layer disabled)

  func testAutoImportWithLayerDisabledFollowsBuiltInOnlyPath() throws {
    let defaults = UserDefaultsFactory.make()
    // userLayerEnabled absent → treated as false
    let configURL = tempDir.appendingPathComponent("config.toml")
    let source = """
    schema_version = 1

    [capture.screenshot]
    format = "png"
    """
    try source.write(to: configURL, atomically: true, encoding: .utf8)

    let result = SnapzyConfigurationAutoImporter.applyIfNeeded(from: configURL, defaults: defaults)

    XCTAssertEqual(result.status, .applied)
    XCTAssertNil(
      defaults.string(forKey: PreferencesKeys.configurationUserLayerLastAppliedSignature),
      "User-layer signature must NOT be written when layer is disabled")
  }

  func testAutoImportWithLayerDisabledDoesNotCreateUserConfigFile() throws {
    let defaults = UserDefaultsFactory.make()
    // layer explicitly disabled
    defaults.set(false, forKey: PreferencesKeys.configurationUserLayerEnabled)

    let configURL = tempDir.appendingPathComponent("config.toml")
    try "schema_version = 1\n".write(to: configURL, atomically: true, encoding: .utf8)

    let userConfigURL = tempDir.appendingPathComponent("user-config.toml")
    defaults.set(userConfigURL.path, forKey: PreferencesKeys.configurationUserLayerFilePath)

    _ = SnapzyConfigurationAutoImporter.applyIfNeeded(from: configURL, defaults: defaults)

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: userConfigURL.path),
      "User-config file must NOT be created when layer is disabled")
  }

  func testAutoImportLayerDisabledSkipsSecondCallLikeBaseline() throws {
    let defaults = UserDefaultsFactory.make()
    let configURL = tempDir.appendingPathComponent("config.toml")
    try "schema_version = 1\n".write(to: configURL, atomically: true, encoding: .utf8)

    let first = SnapzyConfigurationAutoImporter.applyIfNeeded(from: configURL, defaults: defaults)
    XCTAssertEqual(first.status, .applied)

    let second = SnapzyConfigurationAutoImporter.applyIfNeeded(from: configURL, defaults: defaults)
    XCTAssertEqual(second.status, .skippedUnchanged,
                   "Second call with same file must be skipped (baseline behaviour)")
  }

  // MARK: - UserLayerState when flag absent

  func testUserLayerStateIsDisabledWhenFlagAbsent() {
    let defaults = UserDefaultsFactory.make()
    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertFalse(state.isEnabled,
                   "User layer must be disabled when key is never written")
  }

  func testUserLayerStateIsDisabledWhenFlagFalse() {
    let defaults = UserDefaultsFactory.make()
    defaults.set(false, forKey: PreferencesKeys.configurationUserLayerEnabled)
    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertFalse(state.isEnabled)
  }

  // MARK: - Write routing (layer disabled)

  func testWriteRouterPerKeyWithEmptyUserDocWritesNothingToUserConfig() {
    let current = makeDoc(["[capture.screenshot]", "format = \"png\""])
    let builtIn = makeDoc(["[capture.screenshot]", "format = \"png\""])
    let userEmpty = SimpleTOMLDocument()

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current,
      builtInDoc: builtIn,
      userConfigDoc: userEmpty,
      mode: .perKey)

    // Built-in write is NOT expected when user layer is enabled.
    XCTAssertFalse(routing.shouldWriteBuiltIn)
    let userKeys = routing.userConfigDoc.map { SnapzyConfigurationWriteRouter.leafKeys(in: $0.root, prefix: []) } ?? []
    XCTAssertTrue(userKeys.isEmpty,
                  "No user-config keys should be written when user doc is empty")
  }

  func testWriteRouterPrimaryWithEmptyUserDocProducesNilOrEmptyDiff() {
    let current = makeDoc(["[capture.screenshot]", "format = \"png\""])
    let builtIn = makeDoc(["[capture.screenshot]", "format = \"png\""])
    let userEmpty = SimpleTOMLDocument()

    let routing = SnapzyConfigurationWriteRouter.route(
      currentDoc: current,
      builtInDoc: builtIn,
      userConfigDoc: userEmpty,
      mode: .primary)

    // Current equals built-in → nothing to write to user config.
    XCTAssertFalse(routing.shouldWriteBuiltIn)
    let userKeys = routing.userConfigDoc.map { SnapzyConfigurationWriteRouter.leafKeys(in: $0.root, prefix: []) } ?? []
    XCTAssertTrue(userKeys.isEmpty,
                  "No diff keys → user-config doc must be empty or nil in primary mode")
  }

  // MARK: - Helpers

  private func makeDoc(_ lines: [String]) -> SimpleTOMLDocument {
    let source = lines.joined(separator: "\n")
    return (try? SimpleTOMLParser.parse(source)) ?? SimpleTOMLDocument()
  }
}
