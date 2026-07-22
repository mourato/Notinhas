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
}
