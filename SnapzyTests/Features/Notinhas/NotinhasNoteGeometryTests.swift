import CoreGraphics
@testable import Snapzy
import XCTest

final class NotinhasNoteGeometryTests: XCTestCase {
  private let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

  func testShouldCreateRectUsesDragThreshold() {
    XCTAssertFalse(NotinhasNoteGeometry.shouldCreateRect(dragDistance: 4))
    XCTAssertTrue(NotinhasNoteGeometry.shouldCreateRect(dragDistance: 12))
    XCTAssertFalse(NotinhasNoteGeometry.shouldBeginMove(dragDistance: 4))
    XCTAssertTrue(NotinhasNoteGeometry.shouldBeginMove(dragDistance: 12))
  }

  func testTranslatedPointStaysInsideBounds() {
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let translated = NotinhasNoteGeometry.translated(
      .point(CGPoint(x: 90, y: 50)),
      by: CGPoint(x: 20, y: 0),
      within: bounds
    )
    guard case .point(let point) = translated else {
      return XCTFail("Expected point target")
    }
    XCTAssertEqual(point.x, 100)
    XCTAssertEqual(point.y, 50)
  }

  func testTranslatedRectStaysInsideBounds() {
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let translated = NotinhasNoteGeometry.translated(
      .rect(CGRect(x: 70, y: 10, width: 20, height: 20)),
      by: CGPoint(x: 20, y: 0),
      within: bounds
    )
    guard case .rect(let rect) = translated else {
      return XCTFail("Expected rect target")
    }
    XCTAssertEqual(rect.origin.x, 80)
    XCTAssertEqual(rect.width, 20)
  }

  func testDisplayNumberUsesCreationOrderAmongRenderableNotes() {
    let first = NotinhasVisualNote(text: "One", target: .point(.zero), color: red, creationOrder: 1)
    let second = NotinhasVisualNote(text: "Two", target: .point(CGPoint(x: 10, y: 10)), color: red, creationOrder: 2)
    let empty = NotinhasVisualNote(text: "   ", target: .point(CGPoint(x: 20, y: 20)), color: red, creationOrder: 3)
    let notes = [first, second, empty]

    XCTAssertEqual(NotinhasNoteGeometry.displayNumber(for: second, in: notes), 2)
    XCTAssertEqual(NotinhasNoteGeometry.orderedRenderableNotes(notes).count, 2)
  }

  func testExportTransformedOffsetsPointAndRect() {
    let note = NotinhasVisualNote(
      text: "Move",
      target: .rect(CGRect(x: 10, y: 20, width: 30, height: 40)),
      color: red,
      creationOrder: 1
    )
    let transformed = NotinhasNoteGeometry.exportTransformed(
      note,
      cropOrigin: CGPoint(x: 5, y: 5),
      destinationOffset: CGPoint(x: 100, y: 200)
    )
    guard case .rect(let rect) = transformed.target else {
      return XCTFail("Expected rect target")
    }
    XCTAssertEqual(rect.origin.x, 105)
    XCTAssertEqual(rect.origin.y, 215)
  }

  func testNoteTargetRotationUsesImageSpaceTransform() {
    let size = CGSize(width: 100, height: 60)

    XCTAssertEqual(
      NotinhasNoteTarget.point(CGPoint(x: 10, y: 20)).rotated(oldSize: size, clockwise: true),
      .point(CGPoint(x: 20, y: 90))
    )
    XCTAssertEqual(
      NotinhasNoteTarget.rect(CGRect(x: 10, y: 20, width: 30, height: 15))
        .rotated(oldSize: size, clockwise: false),
      .rect(CGRect(x: 25, y: 10, width: 15, height: 30))
    )
  }

  func testEditorOriginPrefersRightOfLargeRect() {
    let container = CGRect(x: 0, y: 0, width: 800, height: 600)
    let selection = CGRect(x: 40, y: 80, width: 400, height: 220)
    let panelSize = CGSize(width: 300, height: 200)
    let origin = NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selection,
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(origin.x, selection.maxX + 24, accuracy: 0.001)
    XCTAssertGreaterThanOrEqual(origin.x, selection.maxX)
    XCTAssertEqual(origin.y, selection.midY - panelSize.height / 2, accuracy: 0.001)
  }

  func testEditorOriginFallsBackLeftWhenRightDoesNotFit() {
    let container = CGRect(x: 0, y: 0, width: 700, height: 400)
    let selection = CGRect(x: 350, y: 50, width: 280, height: 150)
    let panelSize = CGSize(width: 300, height: 200)
    let origin = NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selection,
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(origin.x, selection.minX - panelSize.width - 24, accuracy: 0.001)
    XCTAssertLessThan(origin.x + panelSize.width, selection.minX)
  }

  func testEditorOriginPlacesBesidePointPin() {
    let container = CGRect(x: 0, y: 0, width: 600, height: 400)
    let selection = CGRect(x: 106, y: 166, width: 28, height: 28)
    let panelSize = CGSize(width: 300, height: 180)
    let origin = NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selection,
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(origin.x, selection.maxX + 24, accuracy: 0.001)
  }

  func testSelectionDisplayBoundsScalesAndFlipsY() {
    let canvasBounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    let target = NotinhasNoteTarget.point(CGPoint(x: 50, y: 80))
    let displayBounds = NotinhasNoteGeometry.selectionDisplayBounds(
      for: target,
      canvasBounds: canvasBounds,
      displayScale: 2
    )

    XCTAssertEqual(displayBounds.origin.x, 72, accuracy: 0.001)
    XCTAssertEqual(displayBounds.width, 56, accuracy: 0.001)
    XCTAssertEqual(displayBounds.height, 56, accuracy: 0.001)
    XCTAssertEqual(displayBounds.origin.y, 12, accuracy: 0.001)
  }

  func testEditorPanelSizeClampsToSmallContainer() {
    let container = CGRect(x: 0, y: 0, width: 260, height: 180)
    let panelSize = NotinhasNoteGeometry.editorPanelSize(
      isRectangular: false,
      in: container
    )

    XCTAssertEqual(panelSize.width, 236, accuracy: 0.001)
    XCTAssertEqual(panelSize.height, 160, accuracy: 0.001)
  }
}
