//
//  NotinhasNoteEditorPanelPlacement.swift
//  Notinhas
//
//  Transient UI-space placement for the contextual note editor panel.
//

import CoreGraphics
import Foundation

struct NotinhasNoteEditorPanelPlacement: Equatable {
  private(set) var origin: CGPoint?
  private var dragAnchorOrigin: CGPoint?

  mutating func reset() {
    origin = nil
    dragAnchorOrigin = nil
  }

  /// Non-mutating origin for layout; falls back to automatic placement without persisting.
  func displayOrigin(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) -> CGPoint {
    if let origin {
      return NotinhasNoteGeometry.clampedEditorPanelOrigin(
        origin,
        panelSize: panelSize,
        in: containerBounds,
        margin: margin
      )
    }

    return NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selectionBounds,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }

  mutating func ensureSeeded(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) {
    guard origin == nil else { return }
    origin = NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selectionBounds,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }

  mutating func reclamp(
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) {
    guard let origin else { return }
    self.origin = NotinhasNoteGeometry.clampedEditorPanelOrigin(
      origin,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }

  mutating func resolvedOrigin(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) -> CGPoint {
    ensureSeeded(
      selectionBounds: selectionBounds,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
    return displayOrigin(
      selectionBounds: selectionBounds,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }

  mutating func beginDrag(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) {
    if dragAnchorOrigin == nil {
      ensureSeeded(
        selectionBounds: selectionBounds,
        panelSize: panelSize,
        in: containerBounds,
        margin: margin
      )
      dragAnchorOrigin = displayOrigin(
        selectionBounds: selectionBounds,
        panelSize: panelSize,
        in: containerBounds,
        margin: margin
      )
    }
  }

  mutating func updateDrag(
    translation: CGSize,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) {
    guard let dragAnchorOrigin else { return }
    applyDrag(
      from: dragAnchorOrigin,
      translation: translation,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }

  mutating func endDrag() {
    dragAnchorOrigin = nil
  }

  mutating func applyDrag(
    from startOrigin: CGPoint,
    translation: CGSize,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) {
    let proposed = CGPoint(
      x: startOrigin.x + translation.width,
      y: startOrigin.y + translation.height
    )
    origin = NotinhasNoteGeometry.clampedEditorPanelOrigin(
      proposed,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
  }
}
