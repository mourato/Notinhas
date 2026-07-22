//
//  CaptureFloatingToolbarPlacementTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureFloatingToolbarPlacementTests: XCTestCase {
  func testCaptureFloatingToolbarPlacement_usesOutsideGapWhenBelowSelectionFits() {
    let toolbarSize = CGSize(width: 240, height: 44)
    let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let selectionRect = CGRect(x: 300, y: 220, width: 400, height: 300)

    let origin = CaptureFloatingToolbarPlacement.frameOrigin(
      toolbarSize: toolbarSize,
      anchorRect: selectionRect,
      screenFrame: screenFrame
    )

    XCTAssertEqual(origin.x, selectionRect.midX - toolbarSize.width / 2)
    XCTAssertEqual(
      origin.y,
      selectionRect.minY - toolbarSize.height - CaptureFloatingToolbarPlacement.outsideSelectionGap
    )
  }

  func testCaptureFloatingToolbarPlacement_usesInsideBottomInsetNearScreenBottom() {
    let toolbarSize = CGSize(width: 240, height: 44)
    let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let selectionRect = CGRect(x: 300, y: 24, width: 400, height: 300)

    let origin = CaptureFloatingToolbarPlacement.frameOrigin(
      toolbarSize: toolbarSize,
      anchorRect: selectionRect,
      screenFrame: screenFrame
    )

    XCTAssertEqual(
      origin.y,
      selectionRect.minY + CaptureFloatingToolbarPlacement.insideSelectionBottomInset
    )
  }

  func testCaptureFloatingToolbarPlacement_clampsInsideInsetToVisibleScreen() {
    let toolbarSize = CGSize(width: 240, height: 44)
    let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 100)
    let selectionRect = CGRect(x: 300, y: 24, width: 400, height: 60)

    let origin = CaptureFloatingToolbarPlacement.frameOrigin(
      toolbarSize: toolbarSize,
      anchorRect: selectionRect,
      screenFrame: screenFrame
    )

    XCTAssertEqual(
      origin.y,
      screenFrame.maxY - toolbarSize.height - CaptureFloatingToolbarPlacement.screenEdgeInset
    )
  }
}
