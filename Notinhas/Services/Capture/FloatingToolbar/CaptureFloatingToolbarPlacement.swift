//
//  CaptureFloatingToolbarPlacement.swift
//  Notinhas
//
//  Shared placement for floating capture HUD toolbars near a selection anchor.
//

import CoreGraphics

enum CaptureFloatingToolbarPlacement {
  static let screenEdgeInset: CGFloat = 10
  static let outsideSelectionGap: CGFloat = 20
  static let insideSelectionBottomInset: CGFloat = 24

  static func frameOrigin(
    toolbarSize: CGSize,
    anchorRect rect: CGRect,
    screenFrame: CGRect
  ) -> CGPoint {
    let x = rect.midX - toolbarSize.width / 2
    let minX = screenFrame.minX + screenEdgeInset
    let maxX = screenFrame.maxX - toolbarSize.width - screenEdgeInset
    let safeX = clampedOrigin(x, minimum: minX, maximum: maxX)

    let minY = screenFrame.minY + screenEdgeInset
    let maxY = screenFrame.maxY - toolbarSize.height - screenEdgeInset
    let belowSelectionY = rect.minY - toolbarSize.height - outsideSelectionGap
    let preferredY = belowSelectionY >= minY
      ? belowSelectionY
      : rect.minY + insideSelectionBottomInset
    let safeY = clampedOrigin(preferredY, minimum: minY, maximum: maxY)

    return CGPoint(x: safeX, y: safeY)
  }

  private static func clampedOrigin(_ origin: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
    guard maximum >= minimum else {
      // The toolbar cannot fit on this display. Keep its leading edge visible rather than
      // allowing a reversed clamp range to produce an unpredictable origin.
      return minimum
    }
    return max(minimum, min(origin, maximum))
  }
}
