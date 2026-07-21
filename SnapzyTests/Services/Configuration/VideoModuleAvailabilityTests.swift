//
//  VideoModuleAvailabilityTests.swift
//  SnapzyTests
//
//  Tests for compile-time and runtime Video module availability.
//

@testable import Snapzy
import XCTest

final class VideoModuleAvailabilityTests: XCTestCase {
  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
    super.tearDown()
  }

  func testRuntimeDefaultIsOffWhenKeyUnset() {
    UserDefaults.standard.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
    XCTAssertFalse(VideoModuleAvailability.isEnabled)
  }

  func testSetEnabledRoundTrip() {
    guard VideoModuleAvailability.isCompiledIn else {
      return
    }

    XCTAssertFalse(VideoModuleAvailability.isEnabled)

    VideoModuleAvailability.setEnabled(true)
    XCTAssertTrue(VideoModuleAvailability.isEnabled)

    VideoModuleAvailability.setEnabled(false)
    XCTAssertFalse(VideoModuleAvailability.isEnabled)
  }

  func testDisabledWhenNotCompiledIn() {
    guard !VideoModuleAvailability.isCompiledIn else {
      return
    }

    VideoModuleAvailability.setEnabled(true)
    XCTAssertFalse(VideoModuleAvailability.isEnabled)
  }
}
