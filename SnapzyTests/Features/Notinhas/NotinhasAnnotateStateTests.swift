@testable import Snapzy
import XCTest

@MainActor
final class NotinhasAnnotateStateTests: XCTestCase {
  private func makeState() -> AnnotateState {
    AnnotateState(defaults: UserDefaultsFactory.make())
  }

  private func makeNote(text: String = "Note") -> NotinhasVisualNote {
    NotinhasVisualNote(
      text: text,
      target: .point(.zero),
      color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
      creationOrder: 1
    )
  }

  func testAddingNoteCreatesOneUndoCheckpoint() {
    let state = makeState()
    let note = makeNote()

    state.notinhasAddNote(note)
    XCTAssertEqual(state.notinhasNotes, [note])

    state.undo()
    XCTAssertTrue(state.notinhasNotes.isEmpty)
  }

  func testUpdatingNoteUndoRestoresOriginalValue() {
    let state = makeState()
    let original = makeNote(text: "Before")
    var edited = original
    edited.text = "After"
    state.notinhasNotes = [original]

    state.notinhasUpdateNote(edited)
    state.undo()

    XCTAssertEqual(state.notinhasNotes, [original])
  }

  func testDeletingNoteUndoRestoresNote() {
    let state = makeState()
    let note = makeNote()
    state.notinhasNotes = [note]

    state.notinhasDeleteNote(id: note.id)
    state.undo()

    XCTAssertEqual(state.notinhasNotes, [note])
  }

  func testMovingNoteCreatesOneUndoCheckpoint() {
    let state = makeState()
    let note = makeNote()
    state.notinhasNotes = [note]
    let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

    state.notinhasBeginMovingNote(id: note.id)
    state.notinhasUpdateMovingNote(
      to: CGPoint(x: 30, y: 0),
      imageBounds: bounds,
      from: .zero
    )
    state.notinhasCommitMovingNote()

    guard case .point(let movedPoint) = state.notinhasNotes[0].target else {
      return XCTFail("Expected point target")
    }
    XCTAssertEqual(movedPoint.x, 30, accuracy: 0.001)

    state.undo()
    XCTAssertEqual(state.notinhasNotes[0].target, note.target)
  }

  func testCancelMovingNoteDoesNotCreateUndoCheckpoint() {
    let state = makeState()
    let note = makeNote()
    state.notinhasNotes = [note]
    let bounds = CGRect(x: 0, y: 0, width: 200, height: 200)

    state.notinhasBeginMovingNote(id: note.id)
    state.notinhasUpdateMovingNote(
      to: CGPoint(x: 30, y: 0),
      imageBounds: bounds,
      from: .zero
    )
    state.notinhasCancelMovingNote()

    XCTAssertEqual(state.notinhasNotes[0].target, note.target)
    state.undo()
    XCTAssertEqual(state.notinhasNotes, [note])
  }
}
