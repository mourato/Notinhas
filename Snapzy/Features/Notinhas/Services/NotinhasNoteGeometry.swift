//
//  NotinhasNoteGeometry.swift
//  Snapzy
//
//  Pure geometry helpers for Notinhas notes.
//

import CoreGraphics
import Foundation

nonisolated enum NotinhasNoteGeometry {
  static let pinDiameter: CGFloat = 28
  static let dragThreshold: CGFloat = 8
  static let minimumRectSize: CGFloat = 24

  static func shouldCreateRect(dragDistance: CGFloat) -> Bool {
    exceedsDragThreshold(dragDistance)
  }

  static func shouldBeginMove(dragDistance: CGFloat) -> Bool {
    exceedsDragThreshold(dragDistance)
  }

  private static func exceedsDragThreshold(_ dragDistance: CGFloat) -> Bool {
    dragDistance >= dragThreshold
  }

  static func translated(
    _ target: NotinhasNoteTarget,
    by delta: CGPoint,
    within bounds: CGRect
  ) -> NotinhasNoteTarget {
    switch target {
    case .point(let center):
      return .point(clampedPoint(
        CGPoint(x: center.x + delta.x, y: center.y + delta.y),
        within: bounds
      ))
    case .rect(let rect):
      let standardized = rect.standardized
      var translated = CGRect(
        x: standardized.origin.x + delta.x,
        y: standardized.origin.y + delta.y,
        width: standardized.width,
        height: standardized.height
      )
      if translated.width > bounds.width {
        translated.origin.x = bounds.minX
      } else {
        translated.origin.x = max(bounds.minX, min(translated.origin.x, bounds.maxX - translated.width))
      }
      if translated.height > bounds.height {
        translated.origin.y = bounds.minY
      } else {
        translated.origin.y = max(bounds.minY, min(translated.origin.y, bounds.maxY - translated.height))
      }
      return .rect(translated)
    }
  }

  static func clampedRect(from start: CGPoint, to end: CGPoint, within bounds: CGRect) -> CGRect {
    let standardized = CGRect(
      x: min(start.x, end.x),
      y: min(start.y, end.y),
      width: abs(end.x - start.x),
      height: abs(end.y - start.y)
    ).standardized

    let minSizeRect = minimumSizedRect(standardized)
    return minSizeRect.intersection(bounds.standardized)
  }

  static func clampedPoint(_ point: CGPoint, within bounds: CGRect) -> CGPoint {
    CGPoint(
      x: max(bounds.minX, min(point.x, bounds.maxX)),
      y: max(bounds.minY, min(point.y, bounds.maxY))
    )
  }

  static func pinCenter(for rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX, y: rect.midY)
  }

  static func pinAnchor(for target: NotinhasNoteTarget) -> CGPoint {
    target.pinCenter
  }

  static func displayNumber(for note: NotinhasVisualNote, in notes: [NotinhasVisualNote]) -> Int {
    let ordered = orderedRenderableNotes(notes)
    guard let index = ordered.firstIndex(where: { $0.id == note.id }) else {
      return notes.filter(\.hasRenderableContent).count + 1
    }
    return index + 1
  }

  static func nextCreationOrder(in notes: [NotinhasVisualNote]) -> Int {
    (notes.map(\.creationOrder).max() ?? 0) + 1
  }

  static func notesAfterDeletion(
    removing id: UUID,
    from notes: [NotinhasVisualNote]
  ) -> [NotinhasVisualNote] {
    notes.filter { $0.id != id }
  }

  static func orderedRenderableNotes(_ notes: [NotinhasVisualNote]) -> [NotinhasVisualNote] {
    notes
      .filter(\.hasRenderableContent)
      .sorted { lhs, rhs in
        if lhs.creationOrder == rhs.creationOrder {
          return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.creationOrder < rhs.creationOrder
      }
  }

  static func hitTest(note: NotinhasVisualNote, at point: CGPoint) -> Bool {
    selectionBounds(for: note)
      .insetBy(dx: -6, dy: -6)
      .contains(point)
  }

  static func selectionBounds(for note: NotinhasVisualNote) -> CGRect {
    selectionBounds(for: note.target, pinDiameter: note.pinDiameter)
  }

  static func selectionBounds(
    for target: NotinhasNoteTarget,
    pinDiameter: CGFloat = pinDiameter
  ) -> CGRect {
    switch target {
    case .point(let point):
      return CGRect(
        x: point.x - pinDiameter / 2,
        y: point.y - pinDiameter / 2,
        width: pinDiameter,
        height: pinDiameter
      )
    case .rect(let rect):
      let standardized = rect.standardized
      let center = pinCenter(for: standardized)
      let pinBounds = CGRect(
        x: center.x - pinDiameter / 2,
        y: center.y - pinDiameter / 2,
        width: pinDiameter,
        height: pinDiameter
      )
      return standardized.union(pinBounds)
    }
  }

  static func exportTransformed(
    _ note: NotinhasVisualNote,
    cropOrigin: CGPoint,
    destinationOffset: CGPoint
  ) -> NotinhasVisualNote {
    var transformed = note
    switch note.target {
    case .point(let point):
      transformed.target = .point(CGPoint(
        x: point.x - cropOrigin.x + destinationOffset.x,
        y: point.y - cropOrigin.y + destinationOffset.y
      ))
    case .rect(let rect):
      transformed.target = .rect(CGRect(
        x: rect.origin.x - cropOrigin.x + destinationOffset.x,
        y: rect.origin.y - cropOrigin.y + destinationOffset.y,
        width: rect.width,
        height: rect.height
      ))
    }
    return transformed
  }

  static func canvasDisplayNumber(for noteID: UUID, in notes: [NotinhasVisualNote]) -> Int? {
    let ordered = notes.sorted { lhs, rhs in
      if lhs.creationOrder == rhs.creationOrder {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.creationOrder < rhs.creationOrder
    }
    guard let index = ordered.firstIndex(where: { $0.id == noteID }) else { return nil }
    return index + 1
  }

  private static func minimumSizedRect(_ rect: CGRect) -> CGRect {
    guard rect.width < minimumRectSize || rect.height < minimumRectSize else {
      return rect
    }
    return CGRect(
      x: rect.origin.x,
      y: rect.origin.y,
      width: max(rect.width, minimumRectSize),
      height: max(rect.height, minimumRectSize)
    )
  }
}
