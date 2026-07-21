import AppKit
import Foundation

// MARK: - Notinhas Annotate State

extension AnnotateState {
  func notinhasAddNote(_ note: NotinhasVisualNote) {
    saveState()
    notinhasNotes.append(note)
    notinhasSelectedNoteID = note.id
    notinhasEditingNoteID = note.id
  }

  func notinhasUpdateNote(_ note: NotinhasVisualNote) {
    guard let index = notinhasNotes.firstIndex(where: { $0.id == note.id }) else { return }
    guard notinhasNotes[index] != note else { return }
    saveState()
    notinhasNotes[index] = note
  }

  func notinhasDeleteNote(id: UUID) {
    guard notinhasNotes.contains(where: { $0.id == id }) else { return }
    saveState()
    notinhasNotes.removeAll { $0.id == id }
    if notinhasSelectedNoteID == id {
      notinhasSelectedNoteID = nil
    }
    if notinhasEditingNoteID == id {
      notinhasEditingNoteID = nil
    }
  }

  func notinhasSelectNote(id: UUID?, beginEditing: Bool = true) {
    notinhasSelectedNoteID = id
    if beginEditing, let id {
      notinhasEditingNoteID = id
    } else {
      notinhasEditingNoteID = nil
    }
  }

  func notinhasBeginMovingNote(id: UUID) {
    guard let note = notinhasNotes.first(where: { $0.id == id }) else { return }
    notinhasMovingNoteID = id
    notinhasMoveOriginalTarget = note.target
  }

  func notinhasUpdateMovingNote(
    to imagePoint: CGPoint,
    imageBounds: CGRect,
    from startPoint: CGPoint
  ) {
    guard let id = notinhasMovingNoteID,
          let original = notinhasMoveOriginalTarget,
          let index = notinhasNotes.firstIndex(where: { $0.id == id }) else { return }
    let delta = CGPoint(x: imagePoint.x - startPoint.x, y: imagePoint.y - startPoint.y)
    notinhasNotes[index].target = NotinhasNoteGeometry.translated(
      original,
      by: delta,
      within: imageBounds
    )
  }

  func notinhasCommitMovingNote() {
    guard let id = notinhasMovingNoteID,
          let original = notinhasMoveOriginalTarget,
          let index = notinhasNotes.firstIndex(where: { $0.id == id }) else {
      notinhasCancelMovingNote()
      return
    }

    let finalTarget = notinhasNotes[index].target
    if finalTarget != original {
      var checkpointNotes = notinhasNotes
      checkpointNotes[index].target = original
      saveNotinhasNotesUndoCheckpoint(checkpointNotes)
    }

    notinhasMovingNoteID = nil
    notinhasMoveOriginalTarget = nil
  }

  func notinhasCancelMovingNote() {
    if let id = notinhasMovingNoteID,
       let original = notinhasMoveOriginalTarget,
       let index = notinhasNotes.firstIndex(where: { $0.id == id }) {
      notinhasNotes[index].target = original
    }
    notinhasMovingNoteID = nil
    notinhasMoveOriginalTarget = nil
  }

  func notinhasCloseEditor(discardIfEmpty: Bool = true) {
    notinhasCancelMovingNote()
    if discardIfEmpty,
       let editingID = notinhasEditingNoteID,
       let note = notinhasNotes.first(where: { $0.id == editingID }),
       note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      notinhasNotes.removeAll { $0.id == editingID }
    }
    notinhasEditingNoteID = nil
    notinhasDraftNote = nil
    notinhasIsDrawingNote = false
    notinhasNoteDrawStart = nil
  }

  func notinhasNote(at point: CGPoint) -> NotinhasVisualNote? {
    for note in notinhasNotes.reversed() {
      if NotinhasNoteGeometry.hitTest(note: note, at: point) {
        return note
      }
    }
    return nil
  }

  func notinhasDisplayNumber(for noteID: UUID) -> Int? {
    guard let note = notinhasNotes.first(where: { $0.id == noteID }) else { return nil }
    return NotinhasNoteGeometry.canvasDisplayNumber(for: noteID, in: notinhasNotes)
  }

  func notinhasRestoreNotes(_ notes: [NotinhasVisualNote]) {
    notinhasCancelMovingNote()
    notinhasNotes = notes
    notinhasSelectedNoteID = nil
    notinhasEditingNoteID = nil
    notinhasDraftNote = nil
    notinhasIsDrawingNote = false
    notinhasNoteDrawStart = nil
  }

  func notinhasClearDrawingState() {
    notinhasDraftNote = nil
    notinhasIsDrawingNote = false
    notinhasNoteDrawStart = nil
  }

  func notinhasBeginDrawing(at point: CGPoint, color: RGBAColor) {
    notinhasNoteDrawStart = point
    notinhasIsDrawingNote = true
    notinhasDraftNote = NotinhasVisualNote(
      target: .point(point),
      color: color,
      creationOrder: NotinhasNoteGeometry.nextCreationOrder(in: notinhasNotes)
    )
  }

  func notinhasUpdateDrawing(to point: CGPoint, imageBounds: CGRect) {
    guard let start = notinhasNoteDrawStart, var draft = notinhasDraftNote else { return }
    let distance = hypot(point.x - start.x, point.y - start.y)
    if NotinhasNoteGeometry.shouldCreateRect(dragDistance: distance) {
      draft.target = .rect(NotinhasNoteGeometry.clampedRect(from: start, to: point, within: imageBounds))
    } else {
      draft.target = .point(NotinhasNoteGeometry.clampedPoint(start, within: imageBounds))
    }
    notinhasDraftNote = draft
  }

  func notinhasCommitDraft(color: RGBAColor) {
    guard var draft = notinhasDraftNote else { return }
    draft.color = color
    notinhasAddNote(draft)
    notinhasClearDrawingState()
  }
}
