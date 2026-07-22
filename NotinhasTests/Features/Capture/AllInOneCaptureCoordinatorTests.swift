//
//  AllInOneCaptureCoordinatorTests.swift
//  NotinhasTests
//
//  Unit tests for All-In-One coordinator session state.
//

@testable import Notinhas
import SwiftUI
import XCTest

@MainActor
final class AllInOneCaptureCoordinatorTests: XCTestCase {
  override func tearDown() {
    AllInOneCaptureCoordinator.shared.cancel()
    super.tearDown()
  }

  func testCoordinator_startsInactive() {
    XCTAssertFalse(AllInOneCaptureCoordinator.shared.isSessionActive)
  }

  func testSessionState_defaultsToAreaMode() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    XCTAssertEqual(state.selectedMode, .area)
    XCTAssertNil(state.currentRect)
    XCTAssertEqual(state.availableModes, AllInOneCaptureMode.availableModes(videoEnabled: false))
  }

  func testSessionState_activateMode_updatesSelectionAndInvokesAction() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    let rect = CGRect(x: 40, y: 50, width: 320, height: 180)
    state.currentRect = rect
    var activated: AllInOneCaptureMode?
    state.onModeActivated = { activated = $0 }

    state.activateMode(.timer)

    XCTAssertEqual(state.selectedMode, .timer)
    XCTAssertEqual(activated, .timer)
    XCTAssertEqual(state.currentRect, rect)
  }

  func testSessionState_activateUnavailableMode_isIgnored() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var activated = false
    state.onModeActivated = { _ in activated = true }

    state.activateMode(.recording)

    XCTAssertEqual(state.selectedMode, .area)
    XCTAssertFalse(activated)
  }

  func testFloatingHUD_canBeRaisedAboveCaptureOverlay() {
    let window = CaptureFloatingHUDWindow()
    window.setContent(AnyView(Text("All-In-One")))
    window.showAboveCaptureOverlay()

    XCTAssertEqual(window.level, .screenSaver)
    window.close()
  }

  func testSessionState_updateRectPublishesSelection() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    let rect = CGRect(x: 40, y: 50, width: 320, height: 180)
    var publishedRect: CGRect?
    state.onRectChanged = { publishedRect = $0 }

    state.updateRect(rect)

    XCTAssertEqual(state.currentRect, rect)
    XCTAssertEqual(publishedRect, rect)
  }

  func testSessionState_cancelInvokesCallback() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var cancelled = false
    state.onCancel = { cancelled = true }

    state.cancel()

    XCTAssertTrue(cancelled)
  }
}
