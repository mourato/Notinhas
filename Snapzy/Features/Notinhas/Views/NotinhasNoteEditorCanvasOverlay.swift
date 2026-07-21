import SwiftUI

/// SwiftUI overlay for editing Notinhas notes on the annotate canvas viewport.
/// Empty space must not hit-test so canvas click-away still reaches `DrawingCanvasNSView`.
struct NotinhasNoteEditorCanvasOverlay: View {
  @ObservedObject var state: AnnotateState
  let scale: CGFloat
  let canvasBounds: CGRect
  let hostSize: CGSize

  @State private var draftNote: NotinhasVisualNote?
  @State private var openingSnapshot: NotinhasVisualNote?

  var body: some View {
    if let editingID = state.notinhasEditingNoteID,
       let note = state.notinhasNotes.first(where: { $0.id == editingID }) {
      let hostBounds = CGRect(origin: .zero, size: hostSize)
      let selectionDisplay = NotinhasNoteGeometry.selectionDisplayBounds(
        for: note.target,
        canvasBounds: canvasBounds,
        displayScale: scale,
        pinDiameter: note.pinDiameter
      )
      let panelSize = NotinhasNoteGeometry.editorPanelSize(
        isRectangular: note.target.isRectangular,
        in: hostBounds
      )
      let origin = NotinhasNoteGeometry.editorOrigin(
        forSelectionBounds: selectionDisplay,
        panelSize: panelSize,
        in: hostBounds
      )
      let displayNumber = state.notinhasDisplayNumber(for: editingID) ?? 1

      // Layout host only — no full-bleed clear fill, so empty space passes hits to the canvas.
      ZStack(alignment: .topLeading) {
        NotinhasNoteEditorView(
          displayNumber: displayNumber,
          panelWidth: panelSize.width,
          maxPanelHeight: panelSize.height,
          text: draftTextBinding(for: note),
          color: draftColorBinding(for: note),
          areaStyle: draftAreaStyleBinding(for: note),
          areaStrokeWidth: draftAreaStrokeWidthBinding(for: note),
          showsAreaStyle: note.target.isRectangular,
          onCommit: commitEditing,
          onCancel: cancelEditing,
          onDelete: deleteEditing
        )
        .offset(x: origin.x, y: origin.y)
      }
      .frame(width: hostSize.width, height: hostSize.height, alignment: .topLeading)
      .task(id: editingID) {
        ensureDraftSeeded(from: note)
      }
    }
  }

  private func draftTextBinding(for note: NotinhasVisualNote) -> Binding<String> {
    Binding(
      get: { activeDraft(for: note).text },
      set: { newValue in
        updateDraft(from: note) { $0.text = newValue }
      }
    )
  }

  private func draftColorBinding(for note: NotinhasVisualNote) -> Binding<RGBAColor> {
    Binding(
      get: { activeDraft(for: note).color },
      set: { newValue in
        applyLiveAppearance(from: note, color: newValue, areaStyle: nil, areaStrokeWidth: nil)
      }
    )
  }

  private func draftAreaStyleBinding(for note: NotinhasVisualNote) -> Binding<NotinhasAreaStyle> {
    Binding(
      get: { activeDraft(for: note).areaStyle },
      set: { newValue in
        applyLiveAppearance(from: note, color: nil, areaStyle: newValue, areaStrokeWidth: nil)
      }
    )
  }

  private func draftAreaStrokeWidthBinding(for note: NotinhasVisualNote) -> Binding<CGFloat> {
    Binding(
      get: { activeDraft(for: note).areaStrokeWidth },
      set: { newValue in
        applyLiveAppearance(from: note, color: nil, areaStyle: nil, areaStrokeWidth: newValue)
      }
    )
  }

  private func activeDraft(for note: NotinhasVisualNote) -> NotinhasVisualNote {
    if let draftNote, draftNote.id == note.id {
      return draftNote
    }
    return note
  }

  private func ensureDraftSeeded(from note: NotinhasVisualNote) {
    if draftNote?.id != note.id {
      draftNote = note
    }
    if openingSnapshot?.id != note.id {
      openingSnapshot = note
      state.notinhasEditorOpeningSnapshot = note
    }
  }

  private func updateDraft(from note: NotinhasVisualNote, mutate: (inout NotinhasVisualNote) -> Void) {
    ensureDraftSeeded(from: note)
    guard var updated = draftNote, updated.id == note.id else { return }
    mutate(&updated)
    draftNote = updated
  }

  private func commitEditing() {
    if let draftNote, let openingSnapshot {
      state.notinhasCommitNoteEdit(draft: draftNote, openingSnapshot: openingSnapshot)
    }
    state.notinhasCloseEditor(discardIfEmpty: true)
  }

  private func cancelEditing() {
    state.notinhasCloseEditor(discardIfEmpty: true, revertLiveAppearance: true)
  }

  private func deleteEditing() {
    if let editingID = state.notinhasEditingNoteID {
      state.notinhasDeleteNote(id: editingID)
    }
  }

  private func applyLiveAppearance(
    from note: NotinhasVisualNote,
    color: RGBAColor?,
    areaStyle: NotinhasAreaStyle?,
    areaStrokeWidth: CGFloat?
  ) {
    updateDraft(from: note) { updated in
      if let color {
        updated.color = color
      }
      if let areaStyle {
        updated.areaStyle = areaStyle
      }
      if let areaStrokeWidth {
        updated.areaStrokeWidth = NotinhasVisualNote.clampedAreaStrokeWidth(areaStrokeWidth)
      }
    }

    guard let updated = draftNote else { return }
    var liveNote = updated
    if let stateNote = state.notinhasNotes.first(where: { $0.id == updated.id }) {
      liveNote.text = stateNote.text
    }
    state.notinhasApplyLiveAppearance(liveNote)
  }
}
