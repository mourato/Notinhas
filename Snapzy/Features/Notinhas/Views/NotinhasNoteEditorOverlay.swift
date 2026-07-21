import AppKit
import SwiftUI

@MainActor
final class NotinhasNoteEditorOverlay: NSView {
  private let state: AnnotateState
  private let onCommit: () -> Void
  private let onCancel: () -> Void
  private let onDelete: () -> Void
  private let onLiveAppearanceChanged: () -> Void

  private var hostingView: NSHostingView<NotinhasNoteEditorView>?
  private var draftNote: NotinhasVisualNote?
  private var openingSnapshot: NotinhasVisualNote?

  init(
    state: AnnotateState,
    onCommit: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    onDelete: @escaping () -> Void,
    onLiveAppearanceChanged: @escaping () -> Void
  ) {
    self.state = state
    self.onCommit = onCommit
    self.onCancel = onCancel
    self.onDelete = onDelete
    self.onLiveAppearanceChanged = onLiveAppearanceChanged
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show(for noteID: UUID, in containerBounds: CGRect) {
    guard let note = state.notinhasNotes.first(where: { $0.id == noteID }) else { return }

    hostingView?.removeFromSuperview()

    openingSnapshot = note
    draftNote = note
    let displayNumber = state.notinhasDisplayNumber(for: noteID) ?? 1
    let editor = NotinhasNoteEditorView(
      displayNumber: displayNumber,
      text: Binding(
        get: { [self] in
          draftNote?.text ?? ""
        },
        set: { [self] newValue in
          guard var updated = draftNote else { return }
          updated.text = newValue
          draftNote = updated
        }
      ),
      color: Binding(
        get: { [self] in
          draftNote?.color
            ?? RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        },
        set: { [self] newValue in
          applyLiveAppearance(color: newValue, areaStyle: nil)
        }
      ),
      areaStyle: Binding(
        get: { [self] in
          draftNote?.areaStyle ?? .outline
        },
        set: { [self] newValue in
          applyLiveAppearance(color: nil, areaStyle: newValue)
        }
      ),
      showsAreaStyle: note.target.isRectangular,
      onCommit: { [weak self] in
        if let draftNote = self?.draftNote, let openingSnapshot = self?.openingSnapshot {
          self?.state.notinhasCommitNoteEdit(draft: draftNote, openingSnapshot: openingSnapshot)
        }
        self?.onCommit()
      },
      onCancel: { [weak self] in
        self?.cancelEditing()
      },
      onDelete: onDelete
    )

    let hosting = NSHostingView(rootView: editor)
    hosting.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosting)
    hostingView = hosting

    let anchor = NotinhasNoteGeometry.pinAnchor(for: note.target)
    let panelSize = CGSize(width: 300, height: note.target.isRectangular ? 260 : 240)
    var origin = CGPoint(x: anchor.x + 24, y: anchor.y - panelSize.height / 2)

    if origin.x + panelSize.width > containerBounds.maxX - 12 {
      origin.x = anchor.x - panelSize.width - 24
    }
    if origin.y < containerBounds.minY + 12 {
      origin.y = containerBounds.minY + 12
    }
    if origin.y + panelSize.height > containerBounds.maxY - 12 {
      origin.y = containerBounds.maxY - panelSize.height - 12
    }

    frame = CGRect(origin: origin, size: panelSize)
    hosting.frame = bounds
  }

  func cancelEditing() {
    if let openingSnapshot {
      state.notinhasRevertNote(to: openingSnapshot)
      onLiveAppearanceChanged()
    }
    onCancel()
  }

  func dismiss() {
    hostingView?.removeFromSuperview()
    hostingView = nil
    draftNote = nil
    openingSnapshot = nil
    removeFromSuperview()
  }

  private func applyLiveAppearance(color: RGBAColor?, areaStyle: NotinhasAreaStyle?) {
    guard var updated = draftNote else { return }
    if let color {
      updated.color = color
    }
    if let areaStyle {
      updated.areaStyle = areaStyle
    }
    draftNote = updated

    var liveNote = updated
    if let stateNote = state.notinhasNotes.first(where: { $0.id == updated.id }) {
      liveNote.text = stateNote.text
    }
    state.notinhasApplyLiveAppearance(liveNote)
    onLiveAppearanceChanged()
  }
}
