//
//  HistoryFloatingPanelController.swift
//  Notinhas
//
//  Controller for managing the floating history panel lifecycle
//

import AppKit
import Foundation
import SwiftUI

/// Manages the floating history panel with animated transitions
@MainActor
final class HistoryFloatingPanelController {
    var onPanelDidResignKey: (() -> Void)?

    private enum VisibilityState {
        case hidden
        case showing
        case visible
        case hiding
    }

    private struct Presentation {
        let content: AnyView
        let size: CGSize
        let position: HistoryPanelPosition
        let cornerRadius: CGFloat
    }

    private var panel: HistoryFloatingPanel?
    private weak var containerView: HistoryFloatingContainerView?
    private weak var hostingView: NSHostingView<AnyView>?
    private var position: HistoryPanelPosition = .topCenter
    private var state: VisibilityState = .hidden
    private var pendingPresentation: Presentation?
    private var pendingHide = false
    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Show SwiftUI content in floating panel with a soft fade + slide animation.
    func show(
        _ content: some View,
        size: CGSize,
        position: HistoryPanelPosition,
        cornerRadius: CGFloat,
    ) {
        requestShow(
            Presentation(
                content: AnyView(content),
                size: size,
                position: position,
                cornerRadius: cornerRadius,
            ),
        )
    }

    /// Update panel position
    func updatePosition(_ newPosition: HistoryPanelPosition) {
        position = newPosition
        repositionPanel()
    }

    /// Hide panel with fade animation
    func hide() {
        pendingPresentation = nil

        switch state {
        case .hidden, .hiding:
            return
        case .showing:
            pendingHide = true
        case .visible:
            performHide()
        }
    }

    /// Check if panel is onscreen or transitioning.
    var isVisible: Bool {
        state != .hidden
    }

    /// Check if panel is intended to stay open.
    var isPresenting: Bool {
        state == .showing || state == .visible
    }

    func focusPanel() {
        guard let panel else { return }
        // Avoid re-activating the app for this non-activating panel; doing so can
        // churn focus and destabilize the expanded history scroll position.
        guard !panel.isKeyWindow else { return }
        panel.makeKeyAndOrderFront(nil)
    }

    private func requestShow(_ presentation: Presentation) {
        pendingHide = false

        switch state {
        case .hidden:
            performShow(presentation)
        case .showing:
            pendingPresentation = presentation
        case .visible:
            applyPresentation(presentation, animated: !reduceMotion)
        case .hiding:
            pendingPresentation = presentation
        }
    }

    private func performShow(_ presentation: Presentation) {
        position = presentation.position
        let hostingView: NSHostingView<AnyView> = NSHostingView(rootView: presentation.content)
        let size = naturalPanelSize(for: hostingView, width: presentation.size.width)
        let targetFrame = frame(for: size, position: presentation.position)
        let panel = HistoryFloatingPanel(contentRect: targetFrame)
        panel.onDidResignKey = { [weak self] in
            self?.handlePanelDidResignKey()
        }
        installContent(
            hostingView,
            on: panel,
            size: size,
            cornerRadius: presentation.cornerRadius,
        )

        self.panel = panel
        state = .showing

        if reduceMotion {
            panel.alphaValue = 0
            panel.setFrame(targetFrame, display: false)
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.finishShow()
                }
            }
            return
        }

        panel.alphaValue = 0
        panel.setFrame(transitionFrame(for: targetFrame, isShowing: true), display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.22, 1.0, 0.36, 1.0,
            )
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.finishShow()
            }
        }
    }

    private func finishShow() {
        state = .visible

        if pendingHide {
            pendingHide = false
            performHide()
            return
        }

        if let pendingPresentation {
            self.pendingPresentation = nil
            requestShow(pendingPresentation)
        }
    }

    private func performHide() {
        guard let panel else {
            state = .hidden
            return
        }

        state = .hiding
        let targetFrame = reduceMotion ? panel.frame : transitionFrame(for: panel.frame, isShowing: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.14 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if !reduceMotion {
                panel.animator().setFrame(targetFrame, display: true)
            }
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.close()
            MainActor.assumeIsolated {
                self?.panel = nil
                self?.hostingView = nil
                self?.state = .hidden
                self?.resumePendingPresentationIfNeeded()
            }
        }
    }

    private func resumePendingPresentationIfNeeded() {
        guard let pendingPresentation else { return }
        self.pendingPresentation = nil
        performShow(pendingPresentation)
    }

    private func applyPresentation(_ presentation: Presentation, animated: Bool) {
        guard let panel else { return }
        position = presentation.position
        updatePanelChrome(on: panel, cornerRadius: presentation.cornerRadius)

        DispatchQueue.main.async { [weak self, panel] in
            guard let self, self.panel === panel, let hostingView else { return }

            hostingView.layoutSubtreeIfNeeded()
            let size = naturalPanelSize(for: hostingView, width: presentation.size.width)
            syncHostFrames(to: size)
            let targetFrame = frame(for: size, position: presentation.position)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(
                        controlPoints: 0.2, 0.9, 0.3, 1.0,
                    )
                    panel.animator().setFrame(targetFrame, display: true)
                }
            } else {
                panel.setFrame(targetFrame, display: true)
            }
        }
    }

    private func installContent(
        _ hostingView: NSHostingView<AnyView>,
        on panel: HistoryFloatingPanel,
        size: CGSize,
        cornerRadius: CGFloat,
    ) {
        // Frame-based hosting (HUD pattern): avoid top+bottom Auto Layout pins that
        // make later fittingSize / refresh reads report the already-constrained height.
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.sizingOptions = .intrinsicContentSize
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]

        let containerView = HistoryFloatingContainerView()
        containerView.frame = NSRect(origin: .zero, size: size)
        containerView.autoresizingMask = [.width, .height]
        containerView.cornerRadius = cornerRadius
        containerView.addSubview(hostingView)

        panel.contentView = containerView
        self.containerView = containerView
        self.hostingView = hostingView
        updatePanelChrome(on: panel, cornerRadius: cornerRadius)
    }

    private func syncHostFrames(to size: CGSize) {
        let bounds = NSRect(origin: .zero, size: size)
        containerView?.frame = bounds
        hostingView?.frame = bounds
    }

    private func naturalPanelSize(
        for hostingView: NSHostingView<AnyView>,
        width: CGFloat,
    ) -> CGSize {
        let fittingHeight = idealContentHeight(for: hostingView, width: width)
        return HistoryFloatingLayout.panelSize(
            fittingHeight: fittingHeight,
            on: ScreenUtility.activeScreen(),
        )
    }

    /// Ideal SwiftUI height at a fixed width, ignoring the host's current frame height.
    private func idealContentHeight(
        for hostingView: NSHostingView<AnyView>,
        width: CGFloat,
    ) -> CGFloat {
        hostingView.sizingOptions = .intrinsicContentSize

        if hostingView.superview == nil {
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 0)
            return max(hostingView.fittingSize.height, 1)
        }

        // Temporarily release the short panel frame so fittingSize can report the
        // intrinsic SwiftUI height instead of the already-applied window height.
        let previousFrame = hostingView.frame
        let previousMask = hostingView.autoresizingMask
        hostingView.autoresizingMask = []
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 0)
        hostingView.layoutSubtreeIfNeeded()
        let height = max(hostingView.fittingSize.height, 1)
        hostingView.frame = previousFrame
        hostingView.autoresizingMask = previousMask
        return height
    }

    private func updatePanelChrome(on panel: HistoryFloatingPanel, cornerRadius: CGFloat) {
        panel.appearance = ThemeManager.shared.nsAppearance
        containerView?.cornerRadius = cornerRadius
        panel.applyCornerRadius(cornerRadius)
        panel.invalidateShadow()
    }

    private func frame(for size: CGSize, position: HistoryPanelPosition) -> NSRect {
        let screen = ScreenUtility.activeScreen()
        let origin = position.calculateOrigin(
            for: size,
            on: screen,
            padding: panelPadding(for: position),
        )
        return NSRect(origin: origin, size: size)
    }

    private func panelPadding(for position: HistoryPanelPosition) -> CGFloat {
        switch position {
        case .topCenter:
            HistoryFloatingLayout.topPanelPadding
        case .bottomCenter:
            HistoryFloatingLayout.bottomPanelPadding
        case .center:
            0
        }
    }

    private func transitionFrame(for targetFrame: NSRect, isShowing: Bool) -> NSRect {
        let deltaY: CGFloat = switch position {
        case .topCenter:
            18
        case .bottomCenter:
            -18
        case .center:
            -10
        }
        let direction = isShowing ? deltaY : -deltaY
        var frame = targetFrame
        frame.origin.y += direction
        return frame
    }

    private func handlePanelDidResignKey() {
        guard state == .showing || state == .visible else { return }
        onPanelDidResignKey?()
    }

    private func repositionPanel() {
        guard let panel, state != .hiding else { return }
        let size = panel.frame.size
        let screen = ScreenUtility.activeScreen()
        let origin = position.calculateOrigin(
            for: size,
            on: screen,
            padding: panelPadding(for: position),
        )

        if reduceMotion {
            panel.setFrameOrigin(origin)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrameOrigin(origin)
            }
        }
    }
}

@MainActor
private final class HistoryFloatingContainerView: NSVisualEffectView {
    private var defaultsObserver: NSObjectProtocol?
    var cornerRadius: CGFloat = NSWindow.defaultCornerRadius {
        didSet {
            applyStyle()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    isolated deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyStyle()
    }

    private func configureLayer() {
        state = .active
        blendingMode = .behindWindow
        wantsLayer = true
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyStyle()
            }
        }
        applyStyle()
    }

    private func applyStyle() {
        let style = HistoryBackgroundStyle.currentStoredStyle()
        appearance = ThemeManager.shared.nsAppearance
        window?.appearance = ThemeManager.shared.nsAppearance
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        switch style {
        case .hud:
            blendingMode = .behindWindow
            material = .hudWindow
            layer?.backgroundColor = resolvedHUDBackgroundColor.cgColor
        case .solid:
            blendingMode = .withinWindow
            material = .contentBackground
            layer?.backgroundColor = resolvedSolidBackgroundColor.cgColor
        }
    }

    private var resolvedHUDBackgroundColor: NSColor {
        switch effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua:
            NSColor(
                srgbRed: 0.07,
                green: 0.08,
                blue: 0.11,
                alpha: 0.12,
            )
        default:
            NSColor(
                srgbRed: 1.0,
                green: 1.0,
                blue: 1.0,
                alpha: 0.14,
            )
        }
    }

    private var resolvedSolidBackgroundColor: NSColor {
        WindowSurfacePalette.backgroundColor(for: effectiveAppearance)
    }
}
