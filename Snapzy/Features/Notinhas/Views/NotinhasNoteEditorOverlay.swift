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
    state.notinhasEditorOpeningSnapshot = note
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
          applyLiveAppearance(color: newValue, areaStyle: nil, areaStrokeWidth: nil)
        }
      ),
      areaStyle: Binding(
        get: { [self] in
          draftNote?.areaStyle ?? .outline
        },
        set: { [self] newValue in
          applyLiveAppearance(color: nil, areaStyle: newValue, areaStrokeWidth: nil)
        }
      ),
      areaStrokeWidth: Binding(
        get: { [self] in
          draftNote?.areaStrokeWidth ?? NotinhasVisualNote.defaultAreaStrokeWidth
        },
        set: { [self] newValue in
          applyLiveAppearance(color: nil, areaStyle: nil, areaStrokeWidth: newValue)
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
    hosting.layoutSubtreeIfNeeded()

    let anchor = NotinhasNoteGeometry.pinAnchor(for: note.target)
    let fitting = hosting.fittingSize
    let width = max(300, ceil(fitting.width))
    let preferredHeight = max(note.target.isRectangular ? 280 : 200, ceil(fitting.height))
    let maxHeight = max(200, containerBounds.height - 24)
    let panelSize = CGSize(width: width, height: min(preferredHeight, maxHeight))
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
    // Canvas onCancel closes with revertLiveAppearance so Cancel and click-away share one path.
    onCancel()
  }

  func dismiss() {
    hostingView?.removeFromSuperview()
    hostingView = nil
    draftNote = nil
    openingSnapshot = nil
    removeFromSuperview()
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
    onLiveAppearanceChanged()
  }
}
