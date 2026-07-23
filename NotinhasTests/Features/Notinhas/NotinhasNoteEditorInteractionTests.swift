import CoreGraphics
@testable import Notinhas
import XCTest

final class NotinhasNoteEditorInteractionTests: XCTestCase {
  private let container = CGRect(x: 0, y: 0, width: 800, height: 600)
  private let panelSize = CGSize(width: 300, height: 200)
  private let selection = CGRect(x: 120, y: 140, width: 28, height: 28)

  func testInitialPlacementUsesAutomaticOriginOnce() {
    var placement = NotinhasNoteEditorPanelPlacement()

    let first = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )
    let second = placement.resolvedOrigin(
      selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.x, selection.maxX + 24, accuracy: 0.001)
  }

  func testPlacementRetainsOriginAcrossNoteChangesUntilReset() {
    var placement = NotinhasNoteEditorPanelPlacement()
    _ = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )

    placement.applyDrag(
      from: CGPoint(x: 180, y: 120),
      translation: CGSize(width: 40, height: 20),
      panelSize: panelSize,
      in: container
    )

    let retained = placement.resolvedOrigin(
      selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(retained.x, 220, accuracy: 0.001)
    XCTAssertEqual(retained.y, 140, accuracy: 0.001)
  }

  func testResetClearsTransientOrigin() {
    var placement = NotinhasNoteEditorPanelPlacement()
    _ = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )
    placement.reset()

    let automatic = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(automatic.x, selection.maxX + 24, accuracy: 0.001)
  }

  func testResolvedOriginReclampsAfterWorkAreaShrinks() {
    var placement = NotinhasNoteEditorPanelPlacement()
    _ = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )
    placement.applyDrag(
      from: CGPoint(x: 420, y: 320),
      translation: .zero,
      panelSize: panelSize,
      in: container
    )

    let shrunkenContainer = CGRect(x: 0, y: 0, width: 360, height: 280)
    let reclamped = placement.resolvedOrigin(
      selectionBounds: selection,
      panelSize: panelSize,
      in: shrunkenContainer
    )

    XCTAssertLessThanOrEqual(reclamped.x + panelSize.width, shrunkenContainer.maxX - 12)
    XCTAssertLessThanOrEqual(reclamped.y + panelSize.height, shrunkenContainer.maxY - 12)
  }

  func testBeginDragUsesSeededOriginAndEndDragClearsAnchor() {
    var placement = NotinhasNoteEditorPanelPlacement()

    placement.beginDrag(
      selectionBounds: selection,
      panelSize: panelSize,
      in: container
    )
    placement.updateDrag(
      translation: CGSize(width: 30, height: 10),
      panelSize: panelSize,
      in: container
    )
    placement.endDrag()

    let retained = placement.displayOrigin(
      selectionBounds: CGRect(x: 500, y: 400, width: 28, height: 28),
      panelSize: panelSize,
      in: container
    )

    XCTAssertEqual(retained.x, selection.maxX + 24 + 30, accuracy: 0.001)
    XCTAssertEqual(retained.y, selection.midY - panelSize.height / 2 + 10, accuracy: 0.001)
  }
}
