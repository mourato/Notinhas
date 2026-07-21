import SwiftUI

/// SwiftUI overlay for editing Notinhas notes on the annotate canvas viewport.
struct NotinhasNoteEditorCanvasOverlay: View {
  @ObservedObject var state: AnnotateState
  let scale: CGFloat
  let canvasBounds: CGRect
  let imageOffset: CGPoint
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
      .offsetBy(dx: imageOffset.x, dy: imageOffset.y)
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

      ZStack(alignment: .topLeading) {
        Color.clear

        NotinhasNoteEditorView(
          displayNumber: displayNumber,
          panelWidth: panelSize.width,
          text: draftTextBinding,
          color: draftColorBinding,
          areaStyle: draftAreaStyleBinding,
          areaStrokeWidth: draftAreaStrokeWidthBinding,
          showsAreaStyle: note.target.isRectangular,
          onCommit: commitEditing,
          onCancel: cancelEditing,
          onDelete: deleteEditing
        )
        .offset(x: origin.x, y: origin.y)
      }
      .frame(width: hostSize.width, height: hostSize.height)
      .onAppear {
        syncDraft(for: note)
      }
      .onChange(of: editingID) { _ in
        if let current = state.notinhasNotes.first(where: { $0.id == editingID }) {
          syncDraft(for: current)
        }
      }
    }
  }

  private var draftTextBinding: Binding<String> {
    Binding(
      get: { draftNote?.text ?? "" },
      set: { newValue in
        guard var updated = draftNote else { return }
        updated.text = newValue
        draftNote = updated
      }
    )
  }

  private var draftColorBinding: Binding<RGBAColor> {
    Binding(
      get: {
        draftNote?.color ?? RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
      },
      set: { newValue in
        applyLiveAppearance(color: newValue, areaStyle: nil, areaStrokeWidth: nil)
      }
    )
  }

  private var draftAreaStyleBinding: Binding<NotinhasAreaStyle> {
    Binding(
      get: { draftNote?.areaStyle ?? .outline },
      set: { newValue in
        applyLiveAppearance(color: nil, areaStyle: newValue, areaStrokeWidth: nil)
      }
    )
  }

  private var draftAreaStrokeWidthBinding: Binding<CGFloat> {
    Binding(
      get: {
        draftNote?.areaStrokeWidth ?? NotinhasVisualNote.defaultAreaStrokeWidth
      },
      set: { newValue in
        applyLiveAppearance(color: nil, areaStyle: nil, areaStrokeWidth: newValue)
      }
    )
  }

  private func syncDraft(for note: NotinhasVisualNote) {
    draftNote = note
    openingSnapshot = note
    state.notinhasEditorOpeningSnapshot = note
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
    color: RGBAColor?,
    areaStyle: NotinhasAreaStyle?,
    areaStrokeWidth: CGFloat?
  ) {
    guard var updated = draftNote else { return }
    if let color {
      updated.color = color
    }
    if let areaStyle {
      updated.areaStyle = areaStyle
    }
    if let areaStrokeWidth {
      updated.areaStrokeWidth = NotinhasVisualNote.clampedAreaStrokeWidth(areaStrokeWidth)
    }
    draftNote = updated

    var liveNote = updated
    if let stateNote = state.notinhasNotes.first(where: { $0.id == updated.id }) {
      liveNote.text = stateNote.text
    }
    state.notinhasApplyLiveAppearance(liveNote)
  }
}
