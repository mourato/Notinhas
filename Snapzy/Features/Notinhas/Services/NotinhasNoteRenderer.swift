import AppKit
import CoreGraphics

enum NotinhasNoteRenderer {
  static let pinRadius: CGFloat = 14
  static let selectionStrokeWidth: CGFloat = 2

  static func draw(
    notes: [NotinhasVisualNote],
    selectedNoteID: UUID?,
    in context: CGContext,
    imageBounds: CGRect
  ) {
    context.saveGState()
    context.clip(to: imageBounds)
    defer { context.restoreGState() }

    let ordered = notes.sorted {
      if $0.creationOrder == $1.creationOrder {
        return $0.id.uuidString < $1.id.uuidString
      }
      return $0.creationOrder < $1.creationOrder
    }
    for (index, note) in ordered.enumerated() {
      let displayNumber = index + 1
      let isSelected = note.id == selectedNoteID
      draw(note: note, displayNumber: displayNumber, isSelected: isSelected, in: context, imageBounds: imageBounds)
    }
  }

  static func draw(
    note: NotinhasVisualNote,
    displayNumber: Int,
    isSelected: Bool,
    in context: CGContext,
    imageBounds _: CGRect
  ) {
    switch note.target {
    case .point(let center):
      drawPointTarget(
        center: center,
        color: note.color.nsColor,
        displayNumber: displayNumber,
        isSelected: isSelected,
        in: context
      )
    case .rect(let rect):
      drawRectangleTarget(
        rect: rect,
        style: note.areaStyle,
        color: note.color.nsColor,
        displayNumber: displayNumber,
        isSelected: isSelected,
        in: context
      )
    }
  }

  static func drawPointTarget(
    center: CGPoint,
    color: NSColor,
    displayNumber: Int,
    isSelected: Bool,
    in context: CGContext
  ) {
    let circleRect = CGRect(
      x: center.x - pinRadius,
      y: center.y - pinRadius,
      width: pinRadius * 2,
      height: pinRadius * 2
    )

    context.saveGState()

    AnnotationNumberedBadgeDrawer.draw(
      value: displayNumber,
      in: circleRect,
      fillColor: color.withAlphaComponent(0.92),
      in: context
    )

    if isSelected {
      context.setStrokeColor(NSColor.white.cgColor)
      context.setLineWidth(selectionStrokeWidth)
      context.strokeEllipse(in: circleRect.insetBy(dx: -2, dy: -2))
    }

    context.restoreGState()
  }

  static func drawRectangleTarget(
    rect: CGRect,
    style: NotinhasAreaStyle,
    color: NSColor,
    displayNumber: Int,
    isSelected: Bool,
    in context: CGContext
  ) {
    context.saveGState()
    let standardized = rect.standardized

    switch style {
    case .outline:
      context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
      context.setLineWidth(2)
      context.stroke(standardized)
    case .tinted:
      context.setFillColor(color.withAlphaComponent(0.18).cgColor)
      context.fill(standardized)
      context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
      context.setLineWidth(1.5)
      context.stroke(standardized)
    case .hatched:
      context.setStrokeColor(color.withAlphaComponent(0.95).cgColor)
      context.setLineWidth(2)
      context.stroke(standardized)
      drawHatch(in: standardized, color: color, context: context)
    }

    if isSelected {
      context.setStrokeColor(NSColor.white.cgColor)
      context.setLineWidth(selectionStrokeWidth)
      context.stroke(standardized.insetBy(dx: -2, dy: -2))
    }

    let pinCenter = NotinhasNoteGeometry.pinCenter(for: standardized)
    let circleRect = CGRect(
      x: pinCenter.x - pinRadius,
      y: pinCenter.y - pinRadius,
      width: pinRadius * 2,
      height: pinRadius * 2
    )
    AnnotationNumberedBadgeDrawer.draw(
      value: displayNumber,
      in: circleRect,
      fillColor: color.withAlphaComponent(0.92),
      in: context
    )

    context.restoreGState()
  }

  private static func drawHatch(in rect: CGRect, color: NSColor, context: CGContext) {
    context.saveGState()
    context.clip(to: rect)
    context.setStrokeColor(color.withAlphaComponent(0.35).cgColor)
    context.setLineWidth(1)
    let spacing: CGFloat = 8
    var offset: CGFloat = rect.minX - rect.height
    while offset < rect.maxX + rect.height {
      context.move(to: CGPoint(x: offset, y: rect.minY))
      context.addLine(to: CGPoint(x: offset + rect.height, y: rect.maxY))
      offset += spacing
    }
    context.strokePath()
    context.restoreGState()
  }
}
