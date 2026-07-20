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

  func notinhasSelectNote(id: UUID?) {
    notinhasSelectedNoteID = id
    if let id {
      notinhasEditingNoteID = id
    }
  }

  func notinhasCloseEditor(discardIfEmpty: Bool = true) {
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
