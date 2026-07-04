//
//  SnapzyConfigurationUserLayerPathsTests.swift
//  SnapzyTests
//
//  Tests for user-layer path resolution and write mode defaults (Phase 02).
//

import XCTest
@testable import Snapzy

final class SnapzyConfigurationUserLayerPathsTests: XCTestCase {

  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: "test.userLayerPaths.\(name)")!
    defaults.removePersistentDomain(forName: "test.userLayerPaths.\(name)")
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: "test.userLayerPaths.\(name)")
    defaults = nil
    super.tearDown()
  }

  // MARK: - Default state

  func testDefaultEnabledIsFalse() {
    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertFalse(state.isEnabled)
  }

  func testDefaultWriteModeIsPerKey() {
    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.writeMode, .perKey)
  }

  func testDefaultPathIsSuggestedUserConfigURL() {
    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    let expected = SnapzyConfigurationPaths.suggestedUserConfigURL
    XCTAssertEqual(state.resolvedFileURL, expected)
  }

  func testSuggestedUserConfigURLEndsWithUserConfigToml() {
    let url = SnapzyConfigurationPaths.suggestedUserConfigURL
    XCTAssertEqual(url.lastPathComponent, "user-config.toml")
  }

  func testSuggestedUserConfigURLIsInsideSnapzyDir() {
    let userConfig = SnapzyConfigurationPaths.suggestedUserConfigURL
    let configDir = SnapzyConfigurationPaths.suggestedConfigDirectoryURL
    XCTAssertEqual(userConfig.deletingLastPathComponent(), configDir)
  }

  // MARK: - Custom stored path (tilde-collapsed)

  func testStoredTildePathExpands() {
    defaults.set("~/.config/snapzy/my-overrides.toml", forKey: PreferencesKeys.configurationUserLayerFilePath)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    let path = state.resolvedFileURL.path

    XCTAssertFalse(path.hasPrefix("~"), "Path should be expanded, got: \(path)")
    XCTAssertTrue(path.hasSuffix("my-overrides.toml"), "Got: \(path)")
    XCTAssertFalse(path.contains("~"), "Should contain no tilde after expansion")
  }

  func testStoredAbsolutePathPreserved() {
    let absolute = "/Users/test/dotfiles/user-config.toml"
    defaults.set(absolute, forKey: PreferencesKeys.configurationUserLayerFilePath)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.resolvedFileURL.path, absolute)
  }

  func testEmptyStoredPathFallsBackToDefault() {
    defaults.set("", forKey: PreferencesKeys.configurationUserLayerFilePath)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.resolvedFileURL, SnapzyConfigurationPaths.suggestedUserConfigURL)
  }

  // MARK: - Write mode resolution

  func testPrimaryWriteModeStoredAndResolved() {
    defaults.set(SnapzyConfigurationWriteMode.primary.rawValue,
                 forKey: PreferencesKeys.configurationUserLayerWriteMode)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.writeMode, .primary)
  }

  func testPerKeyWriteModeStoredAndResolved() {
    defaults.set(SnapzyConfigurationWriteMode.perKey.rawValue,
                 forKey: PreferencesKeys.configurationUserLayerWriteMode)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.writeMode, .perKey)
  }

  func testUnknownWriteModeRawValueDefaultsToPerKey() {
    defaults.set("bogusMode", forKey: PreferencesKeys.configurationUserLayerWriteMode)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertEqual(state.writeMode, .perKey)
  }

  // MARK: - Enabled flag

  func testEnabledFlagStoredTrue() {
    defaults.set(true, forKey: PreferencesKeys.configurationUserLayerEnabled)

    let state = SnapzyConfigurationUserLayerState(defaults: defaults)
    XCTAssertTrue(state.isEnabled)
  }

  // MARK: - Paths collapse/expand round-trip

  func testCollapseExpandRoundTrip() {
    let original = SnapzyConfigurationPaths.suggestedUserConfigURL.path
    let collapsed = SnapzyConfigurationPaths.collapsingHomePath(original)
    let expanded = SnapzyConfigurationPaths.expandedUserPath(collapsed)
    XCTAssertEqual(expanded, original)
  }
}
