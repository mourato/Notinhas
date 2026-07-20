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
}
