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

  func testSessionState_selectMode_updatesSelection() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var selected: AllInOneCaptureMode?
    state.onModeSelected = { selected = $0 }

    state.selectMode(.scrolling)

    XCTAssertEqual(state.selectedMode, .scrolling)
    XCTAssertEqual(selected, .scrolling)
  }

  func testSessionState_selectUnavailableMode_isIgnored() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)

    state.selectMode(.recording)

    XCTAssertEqual(state.selectedMode, .area)
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

  func testSessionState_confirmAndCancelInvokeCallbacks() {
    let state = AllInOneCaptureSessionState(videoEnabled: false)
    var confirmed = false
    var cancelled = false
    state.onConfirmCapture = { confirmed = true }
    state.onCancel = { cancelled = true }

    state.confirmCapture()
    state.cancel()

    XCTAssertTrue(confirmed)
    XCTAssertTrue(cancelled)
  }
}
