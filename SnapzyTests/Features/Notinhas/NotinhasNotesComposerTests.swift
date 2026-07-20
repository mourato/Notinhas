import AppKit
@testable import Snapzy
import XCTest

final class NotinhasNotesComposerTests: XCTestCase {
  private let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

  func testComposeAddsPanelWhenRenderableNotesExist() {
    let base = NSImage(size: NSSize(width: 200, height: 100))
    let note = NotinhasVisualNote(
      text: "Button color",
      target: .point(CGPoint(x: 20, y: 20)),
      color: red,
      creationOrder: 1
    )

    let composed = NotinhasNotesComposer.compose(
      baseImage: base,
      notes: [note],
      panelSide: .right
    )

    XCTAssertGreaterThan(composed.size.width, base.size.width)
    XCTAssertGreaterThanOrEqual(composed.size.height, base.size.height)
  }

  func testComposeReturnsBaseImageWhenNoRenderableNotes() {
    let base = NSImage(size: NSSize(width: 120, height: 80))
    let note = NotinhasVisualNote(text: " ", target: .point(.zero), color: red, creationOrder: 1)

    let composed = NotinhasNotesComposer.compose(
      baseImage: base,
      notes: [note],
      panelSide: .left
    )

    XCTAssertEqual(composed.size, base.size)
  }
}
