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

  mutating func reset() {
    origin = nil
  }

  mutating func resolvedOrigin(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) -> CGPoint {
    if let origin {
      let clamped = NotinhasNoteGeometry.clampedEditorPanelOrigin(
        origin,
        panelSize: panelSize,
        in: containerBounds,
        margin: margin
      )
      self.origin = clamped
      return clamped
    }

    let automatic = NotinhasNoteGeometry.editorOrigin(
      forSelectionBounds: selectionBounds,
      panelSize: panelSize,
      in: containerBounds,
      margin: margin
    )
    origin = automatic
    return automatic
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
