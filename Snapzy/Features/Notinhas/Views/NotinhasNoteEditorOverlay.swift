import AppKit
import SwiftUI

@MainActor
final class NotinhasNoteEditorOverlay: NSView {
  private let state: AnnotateState
  private let onCommit: () -> Void
  private let onCancel: () -> Void
  private let onDelete: () -> Void

  private var hostingView: NSHostingView<NotinhasNoteEditorView>?
  private var draftNote: NotinhasVisualNote?

  init(
    state: AnnotateState,
    onCommit: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    self.state = state
    self.onCommit = onCommit
    self.onCancel = onCancel
    self.onDelete = onDelete
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
          guard var updated = draftNote else { return }
          updated.color = newValue
          draftNote = updated
        }
      ),
      areaStyle: Binding(
        get: { [self] in
          draftNote?.areaStyle ?? .outline
        },
        set: { [self] newValue in
          guard var updated = draftNote else { return }
          updated.areaStyle = newValue
          draftNote = updated
        }
      ),
      showsAreaStyle: note.target.isRectangular,
      onCommit: { [weak self] in
        if let draftNote = self?.draftNote {
          self?.state.notinhasUpdateNote(draftNote)
        }
        self?.onCommit()
      },
      onCancel: onCancel,
      onDelete: onDelete
    )

    let hosting = NSHostingView(rootView: editor)
    hosting.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hosting)
    hostingView = hosting

    let anchor = NotinhasNoteGeometry.pinAnchor(for: note.target)
    let panelSize = CGSize(width: 300, height: note.target.isRectangular ? 220 : 180)
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

  func dismiss() {
    hostingView?.removeFromSuperview()
    hostingView = nil
    draftNote = nil
    removeFromSuperview()
  }
}
