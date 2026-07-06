//
//  FrozenReorderCharacterizationTests.swift
//  SnapzyTests
//
//  Phase 2 tests for the reordered frozen area-capture flow (overlay first,
//  snapshot in parallel). Pins the contracts the reorder relies on:
//  empty FrozenAreaCaptureSession, backdrop-pending controller session,
//  and the serial-flow kill-switch default.
//

import AppKit
import XCTest
@testable import Snapzy

@MainActor
final class FrozenReorderCharacterizationTests: XCTestCase {

  private func makeSolidImage(width: Int = 64, height: Int = 64) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
  }

  // MARK: - Empty FrozenAreaCaptureSession contract (reorder starts sessions empty)

  func testEmptyFrozenSession_hasNoBackdropsOrSnapshots() {
    let session = FrozenAreaCaptureSession.fromSnapshots([])
    XCTAssertTrue(session.backdrops.isEmpty)
    XCTAssertTrue(session.displayIDs.isEmpty)
    XCTAssertFalse(session.containsSnapshot(for: 1))
  }

  func testEmptyFrozenSession_addSnapshotLater_backdropBecomesAvailable() {
    let session = FrozenAreaCaptureSession.fromSnapshots([])
    let displayID: CGDirectDisplayID = 42
    let snapshot = FrozenDisplaySnapshot(
      displayID: displayID,
      screenFrame: CGRect(x: 0, y: 0, width: 64, height: 64),
      scaleFactor: 1,
      colorSpaceName: nil,
      image: makeSolidImage()
    )
    session.addSnapshot(snapshot)
    XCTAssertTrue(session.containsSnapshot(for: displayID))
    XCTAssertNotNil(session.backdrop(for: displayID))
    XCTAssertEqual(session.displayIDs, [displayID])
  }

  func testEmptyFrozenSession_cropAfterLateSnapshot_succeeds() throws {
    let session = FrozenAreaCaptureSession.fromSnapshots([])
    let displayID: CGDirectDisplayID = 42
    session.addSnapshot(
      FrozenDisplaySnapshot(
        displayID: displayID,
        screenFrame: CGRect(x: 0, y: 0, width: 64, height: 64),
        scaleFactor: 1,
        colorSpaceName: nil,
        image: makeSolidImage()
      )
    )
    let selection = AreaSelectionResult(
      target: .rect(CGRect(x: 8, y: 8, width: 16, height: 16)),
      displayID: displayID,
      mode: .screenshot
    )
    let crop = try session.cropImage(for: selection)
    XCTAssertEqual(crop.image.width, 16)
    XCTAssertEqual(crop.image.height, 16)
  }

  func testEmptyFrozenSession_cropWithoutSnapshot_throws() {
    let session = FrozenAreaCaptureSession.fromSnapshots([])
    let selection = AreaSelectionResult(
      target: .rect(CGRect(x: 0, y: 0, width: 10, height: 10)),
      displayID: 42,
      mode: .screenshot
    )
    XCTAssertThrowsError(try session.cropImage(for: selection))
  }

  // MARK: - Backdrop-pending controller session

  func testController_pendingFrozenSession_acceptsLateBackdropAndCancel() throws {
    guard let screen = NSScreen.screens.first, let displayID = screen.displayID else {
      throw XCTSkip("No display available")
    }
    let controller = AreaSelectionController.shared
    controller.prepareWindowPool()

    controller.startSelection(
      mode: .screenshot,
      backdrops: [:],
      applicationConfiguration: nil,
      expectsFrozenBackdrops: true
    ) { _ in }
    XCTAssertTrue(controller.isPresenting)

    // Late backdrop arrival (what applyLazyFrozenSnapshot does) must not crash and
    // must keep the session presenting.
    let backdrop = AreaSelectionBackdrop(
      displayID: displayID,
      image: makeSolidImage(width: 128, height: 128),
      scaleFactor: screen.backingScaleFactor
    )
    controller.applyBackdrop(backdrop, for: displayID)
    XCTAssertTrue(controller.isPresenting)

    controller.cancelSelection()
    XCTAssertFalse(controller.isPresenting)
  }

  func testController_pendingFrozenSession_cancelBeforeBackdrop_cleansUp() {
    let controller = AreaSelectionController.shared
    controller.prepareWindowPool()

    controller.startSelection(
      mode: .screenshot,
      backdrops: [:],
      applicationConfiguration: nil,
      expectsFrozenBackdrops: true
    ) { _ in }
    XCTAssertTrue(controller.isPresenting)
    controller.cancelSelection()
    XCTAssertFalse(controller.isPresenting)
  }

  // MARK: - Kill-switch

  func testFrozenSerialActivationKillSwitch_defaultsToOff() {
    // Fresh defaults: reordered flow is the default; kill-switch key absent → false.
    let defaults = UserDefaultsFactory.make()
    XCTAssertFalse(defaults.bool(forKey: ScreenCaptureViewModel.frozenSerialActivationKillSwitchKey))
    XCTAssertEqual(
      ScreenCaptureViewModel.frozenSerialActivationKillSwitchKey,
      "snapzy.frozen.serialActivation"
    )
  }
}
