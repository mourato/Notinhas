//
//  NotinhasVisualNote.swift
//  Snapzy
//
//  Stable model for a numbered Notinhas note on the canvas.
//

import Foundation

nonisolated struct NotinhasVisualNote: Codable, Equatable, Identifiable {
  let id: UUID
  var text: String
  var target: NotinhasNoteTarget
  var color: RGBAColor
  var areaStyle: NotinhasAreaStyle
  let creationOrder: Int

  init(
    id: UUID = UUID(),
    text: String = "",
    target: NotinhasNoteTarget,
    color: RGBAColor,
    areaStyle: NotinhasAreaStyle = .outline,
    creationOrder: Int
  ) {
    self.id = id
    self.text = text
    self.target = target
    self.color = color
    self.areaStyle = areaStyle
    self.creationOrder = creationOrder
  }

  var hasRenderableContent: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
