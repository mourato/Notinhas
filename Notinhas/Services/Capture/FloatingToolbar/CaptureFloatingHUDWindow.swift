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
  private var effectView: NSVisualEffectView?

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

    let effect = NSVisualEffectView()
    effect.material = .hudWindow
    effect.state = .active
    effect.blendingMode = .behindWindow
    effect.wantsLayer = true
    effect.layer?.cornerRadius = ToolbarConstants.toolbarCornerRadius
    effect.layer?.cornerCurve = .continuous
    effect.layer?.masksToBounds = true

    hosting.layer?.backgroundColor = .clear

    effect.addSubview(hosting)
    NSLayoutConstraint.activate([
      hosting.topAnchor.constraint(equalTo: effect.topAnchor),
      hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
      hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
      hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
    ])

    let fittingSize = hosting.fittingSize
    effect.frame = CGRect(origin: .zero, size: fittingSize)

    contentView = effect
    hostingView = hosting
    effectView = effect

    setContentSize(fittingSize)
    cachedContentSize = fittingSize
    invalidateShadow()
  }

  func show(anchorRect: CGRect, screen: NSScreen? = nil) {
    self.anchorRect = anchorRect
    positionNearAnchor(screen: screen)
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

    effectView?.frame = CGRect(origin: .zero, size: fittingSize)
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
