//
//  AreaSelectionWindowCharacterizationTests.swift
//  SnapzyTests
//
//  Characterization tests pinning AreaSelectionWindow / AreaSelectionController
//  behavior BEFORE any performance refactoring. Green on unmodified behavior;
//  a failure here means a refactor broke a behavioral contract.
//

import AppKit
import XCTest
@testable import Snapzy

@MainActor
final class AreaSelectionWindowCharacterizationTests: XCTestCase {

  // MARK: - Window properties

  func testWindow_styleMask_containsBorderlessAndNonactivating() throws {
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No screen available") }
    let window = AreaSelectionWindow(screen: screen, pooled: false)
    XCTAssertTrue(window.styleMask.contains(.borderless))
    XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
  }

  func testWindow_isOpaque_false() throws {
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No screen available") }
    let window = AreaSelectionWindow(screen: screen, pooled: false)
    XCTAssertFalse(window.isOpaque)
  }

  func testWindow_backgroundColorAlpha_nearZero() throws {
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No screen available") }
    let window = AreaSelectionWindow(screen: screen, pooled: false)
    let alpha = window.backgroundColor?.alphaComponent ?? 1
    XCTAssertLessThan(alpha, 0.02, "Window must be nearly transparent for crosshair compositing")
  }

  func testWindow_level_aboveNormal() throws {
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No screen available") }
    let window = AreaSelectionWindow(screen: screen, pooled: false)
    XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.normal.rawValue)
  }

  func testPooledWindow_prepareWindowPool_isIdempotent() {
    let controller = AreaSelectionController.shared
    controller.prepareWindowPool()
    controller.prepareWindowPool() // second call must be a no-op, not crash
  }

  // MARK: - Defaults

  func testFreezesAreaCapture_defaultIsFalse() {
    let defaults = UserDefaultsFactory.make()
    let value = defaults.object(forKey: PreferencesKeys.screenshotFreezeArea) as? Bool ?? false
    XCTAssertFalse(value, "freezesAreaCapture must default to false (live mode is default)")
  }

  func testFreezesAreaCapture_explicitTrueIsRead() {
    let defaults = UserDefaultsFactory.make()
    defaults.set(true, forKey: PreferencesKeys.screenshotFreezeArea)
    let value = defaults.object(forKey: PreferencesKeys.screenshotFreezeArea) as? Bool ?? false
    XCTAssertTrue(value)
  }

  // MARK: - A-key mode toggle contract

  func testSetInteractionMode_toggleBetweenModes_doesNotCrash() throws {
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No screen available") }
    let view = AreaSelectionOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
    view.setInteractionMode(.applicationWindow, resetSelection: false)
    view.setInteractionMode(.manualRegion, resetSelection: false)
    view.setInteractionMode(.applicationWindow, resetSelection: true)
    view.setInteractionMode(.manualRegion, resetSelection: true)
    // No assertion beyond no-crash: mode toggle is the A-key behavioral contract.
  }

  // MARK: - RecaptureReason discrimination

  func testRecaptureReason_twoDistinctCasesExist() {
    let spaceChange = RecaptureReason.spaceChange
    let appActivation = RecaptureReason.appActivation
    XCTAssertNotEqual("\(spaceChange)", "\(appActivation)")
  }

  // MARK: - Coordinate spaces

  func testPrimaryDisplay_quartzOrigin_isZero() throws {
    guard let mainDisplayID = NSScreen.screens.first?.displayID else {
      throw XCTSkip("No screen available")
    }
    let quartzBounds = CGDisplayBounds(mainDisplayID)
    XCTAssertEqual(quartzBounds.origin.x, 0, accuracy: 0.5)
    XCTAssertEqual(quartzBounds.origin.y, 0, accuracy: 0.5)
  }

  func testDisplay_quartzAndAppKit_sizesAgree() throws {
    guard !NSScreen.screens.isEmpty else { throw XCTSkip("No screen available") }
    for screen in NSScreen.screens {
      guard let displayID = screen.displayID else { continue }
      let quartz = CGDisplayBounds(displayID)
      XCTAssertEqual(quartz.width, screen.frame.width, accuracy: 1.0,
        "Width mismatch for display \(displayID)")
      XCTAssertEqual(quartz.height, screen.frame.height, accuracy: 1.0,
        "Height mismatch for display \(displayID)")
    }
  }
}
