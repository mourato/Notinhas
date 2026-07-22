//
//  CaptureFloatingHUDWindow.swift
//  Notinhas
//
//  Reusable borderless floating panel for capture HUD toolbars.
//

import AppKit
import SwiftUI

@MainActor
final class CaptureFloatingHUDWindow: NSPanel {
  private var anchorRect: CGRect = .zero
  private var cachedContentSize: CGSize?
  private var hostingView: NSHostingView<AnyView>?

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    configureWindow()
  }

  func setContent(_ view: AnyView) {
    let themedView = view.preferredColorScheme(ThemeManager.shared.systemAppearance)
    let hosting = NSHostingView(rootView: AnyView(themedView))
    hosting.translatesAutoresizingMaskIntoConstraints = false
    hosting.wantsLayer = true
    hosting.layer?.backgroundColor = .clear

    let fittingSize = hosting.fittingSize
    hosting.frame = CGRect(origin: .zero, size: fittingSize)

    contentView = hosting
    hostingView = hosting

    setContentSize(fittingSize)
    cachedContentSize = fittingSize
    invalidateShadow()
  }

  func show(anchorRect: CGRect, screen: NSScreen? = nil) {
    self.anchorRect = anchorRect
    positionNearAnchor(screen: screen)
    orderFrontRegardless()
  }

  func showAboveCaptureOverlay() {
    level = .screenSaver
    orderFrontRegardless()
  }

  func updateAnchorRect(_ rect: CGRect) {
    anchorRect = rect
    positionNearAnchor(screen: nil)
  }

  func refreshContentSize() {
    guard let hostingView else { return }

    hostingView.layoutSubtreeIfNeeded()
    let fittingSize = hostingView.fittingSize

    hostingView.frame = CGRect(origin: .zero, size: fittingSize)
    setContentSize(fittingSize)
    cachedContentSize = fittingSize
    invalidateShadow()
    positionNearAnchor(screen: nil)
  }

  override var canBecomeKey: Bool {
    false
  }

  override var canBecomeMain: Bool {
    false
  }

  private func configureWindow() {
    isFloatingPanel = true
    isOpaque = false
    backgroundColor = .clear
    sharingType = .none
    level = .popUpMenu
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    hasShadow = true
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    appearance = ThemeManager.shared.nsAppearance
  }

  private func positionNearAnchor(screen: NSScreen?) {
    guard let size = cachedContentSize ?? contentView?.fittingSize else { return }

    let resolvedScreen = screen
      ?? NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) })
      ?? ScreenUtility.activeScreen()
    let screenFrame = resolvedScreen.visibleFrame

    let origin = CaptureFloatingToolbarPlacement.frameOrigin(
      toolbarSize: size,
      anchorRect: anchorRect,
      screenFrame: screenFrame
    )

    setFrameOrigin(origin)
  }
}
