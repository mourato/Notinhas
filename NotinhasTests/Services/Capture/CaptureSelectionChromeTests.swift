//
//  CaptureSelectionChromeTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

final class CaptureSelectionChromeTests: XCTestCase {
  private let rect = CGRect(x: 100, y: 100, width: 200, height: 120)
  private let hitSize = CaptureSelectionChromeMetrics.handleHitSize
  private let cornerLength = CaptureSelectionChromeMetrics.cornerHandleLength
  private let edgeLength = CaptureSelectionChromeMetrics.edgeHandleLength
  private let thickness = CaptureSelectionChromeMetrics.handleThickness

  // MARK: - Hit geometry (Recording / AppKit convention)

  func testHitGeometry_mapsTopLeftCorner() {
    let topLeft = CGPoint(x: rect.minX, y: rect.maxY)
    XCTAssertEqual(
      CaptureSelectionHandleGeometry.handle(at: topLeft, in: rect, hitSize: hitSize),
      .topLeft
    )
  }

  func testHitGeometry_hitRectsAreNonEmptyForAllHandles() {
    for handle in CaptureSelectionHandleGeometry.allHandles {
      let hitRect = CaptureSelectionHandleGeometry.hitRect(for: handle, in: rect, hitSize: hitSize)
      XCTAssertFalse(hitRect.isEmpty, "Expected non-empty hit rect for \(handle)")
    }
  }

  func testHitGeometry_topEdgeSpansBetweenCorners() {
    let topEdgePoint = CGPoint(x: rect.minX + 40, y: rect.maxY)
    XCTAssertEqual(
      CaptureSelectionHandleGeometry.handle(at: topEdgePoint, in: rect, hitSize: hitSize),
      .top
    )

    let topHit = CaptureSelectionHandleGeometry.hitRect(for: .top, in: rect, hitSize: hitSize)
    XCTAssertEqual(topHit.minX, rect.minX + hitSize)
    XCTAssertEqual(topHit.width, rect.width - hitSize * 2)
    XCTAssertTrue(topHit.contains(topEdgePoint))
  }

  // MARK: - Corner L-bar rects (AppKit convention)

  func testCornerHandleBars_topLeftMatchesRecordingMath() {
    let anchor = CGPoint(x: rect.minX, y: rect.maxY)
    let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
      for: .topLeft,
      anchor: anchor,
      metrics: (cornerLength: cornerLength, thickness: thickness)
    )

    let halfThickness = thickness / 2
    XCTAssertEqual(
      bars.horizontal,
      CGRect(
        x: anchor.x - halfThickness,
        y: anchor.y - halfThickness,
        width: cornerLength,
        height: thickness
      )
    )
    XCTAssertEqual(
      bars.vertical,
      CGRect(
        x: anchor.x - halfThickness,
        y: anchor.y - cornerLength + halfThickness,
        width: thickness,
        height: cornerLength
      )
    )
  }

  func testCornerHandleBars_bottomRightMatchesRecordingMath() {
    let anchor = CGPoint(x: rect.maxX, y: rect.minY)
    let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
      for: .bottomRight,
      anchor: anchor,
      metrics: (cornerLength: cornerLength, thickness: thickness)
    )

    let halfThickness = thickness / 2
    XCTAssertEqual(
      bars.horizontal,
      CGRect(
        x: anchor.x - cornerLength + halfThickness,
        y: anchor.y - halfThickness,
        width: cornerLength,
        height: thickness
      )
    )
    XCTAssertEqual(
      bars.vertical,
      CGRect(
        x: anchor.x - halfThickness,
        y: anchor.y - halfThickness,
        width: thickness,
        height: cornerLength
      )
    )
  }

  // MARK: - Edge handle bar rects (AppKit convention)

  func testEdgeHandleBar_topMatchesRecordingMath() {
    let anchor = CGPoint(x: rect.midX, y: rect.maxY)
    let bar = CaptureSelectionHandleGeometry.edgeHandleBar(
      for: .top,
      anchor: anchor,
      metrics: (edgeLength: edgeLength, thickness: thickness)
    )

    let halfLength = edgeLength / 2
    let halfThickness = thickness / 2
    XCTAssertEqual(
      bar,
      CGRect(
        x: anchor.x - halfLength,
        y: anchor.y - halfThickness,
        width: edgeLength,
        height: thickness
      )
    )
  }

  func testEdgeHandleBar_leftMatchesRecordingMath() {
    let anchor = CGPoint(x: rect.minX, y: rect.midY)
    let bar = CaptureSelectionHandleGeometry.edgeHandleBar(
      for: .left,
      anchor: anchor,
      metrics: (edgeLength: edgeLength, thickness: thickness)
    )

    let halfLength = edgeLength / 2
    let halfThickness = thickness / 2
    XCTAssertEqual(
      bar,
      CGRect(
        x: anchor.x - halfThickness,
        y: anchor.y - halfLength,
        width: thickness,
        height: edgeLength
      )
    )
  }

  // MARK: - SwiftUI coordinate space

  func testHitGeometry_topLeftOrigin_mapsCornerAtMinY() {
    let localRect = CGRect(x: 0, y: 0, width: 200, height: 120)
    let topLeft = CGPoint(x: 0, y: 0)
    XCTAssertEqual(
      CaptureSelectionHandleGeometry.handle(
        at: topLeft,
        in: localRect,
        hitSize: hitSize,
        coordinateSpace: .topLeftOrigin
      ),
      .topLeft
    )
  }

  func testCornerHandleBars_topLeftOrigin_matchesRecordingCenteredLayout() {
    let anchor = CGPoint(x: 0, y: 0)
    let bars = CaptureSelectionHandleGeometry.cornerHandleBars(
      for: .topLeft,
      anchor: anchor,
      metrics: (cornerLength: cornerLength, thickness: thickness),
      coordinateSpace: .topLeftOrigin
    )

    let halfThickness = thickness / 2
    XCTAssertEqual(
      bars.horizontal,
      CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: cornerLength, height: thickness)
    )
    XCTAssertEqual(
      bars.vertical,
      CGRect(x: anchor.x - halfThickness, y: anchor.y - halfThickness, width: thickness, height: cornerLength)
    )
  }
}
