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
    let safeX = max(minX, min(x, maxX))

    let minY = screenFrame.minY + screenEdgeInset
    let maxY = screenFrame.maxY - toolbarSize.height - screenEdgeInset
    let belowSelectionY = rect.minY - toolbarSize.height - outsideSelectionGap
    let preferredY = belowSelectionY >= minY
      ? belowSelectionY
      : rect.minY + insideSelectionBottomInset
    let safeY = max(minY, min(preferredY, maxY))

    return CGPoint(x: safeX, y: safeY)
  }
}
