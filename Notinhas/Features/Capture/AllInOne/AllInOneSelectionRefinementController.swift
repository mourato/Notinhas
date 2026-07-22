//
//  AllInOneSelectionRefinementController.swift
//  Notinhas
//
//  Presents per-screen recording region overlays to refine an All-In-One capture selection.
//

import AppKit

@MainActor
final class AllInOneSelectionRefinementController: NSObject {
  var onRectChanged: ((CGRect) -> Void)?
  var onCancel: (() -> Void)?

  private var currentRect: CGRect
  private var regionOverlayWindows: [RecordingRegionOverlayWindow] = []
  private var localEscapeMonitor: Any?
  private var globalEscapeMonitor: Any?

  private var aspectLocked: Bool
  private var lockedAspectRatio: CGFloat?

  init(
    initialRect: CGRect,
    aspectLocked: Bool = false,
    aspectRatio: CGFloat? = nil
  ) {
    currentRect = CaptureSelectionGeometry.normalized(initialRect)
    self.aspectLocked = aspectLocked
    lockedAspectRatio = aspectRatio ?? CaptureSelectionGeometry.aspectRatio(of: initialRect)
    super.init()
  }

  // MARK: - Session

  func present() {
    tearDownOverlays()
    showRegionOverlays(for: currentRect)
    installEscapeMonitorsIfNeeded()
    publishRectChange()
  }

  func tearDown() {
    removeEscapeMonitors()
    tearDownOverlays()
    onRectChanged = nil
    onCancel = nil
  }

  func updateAspectLock(_ locked: Bool) {
    aspectLocked = locked
    if locked, lockedAspectRatio == nil {
      lockedAspectRatio = CaptureSelectionGeometry.aspectRatio(of: currentRect)
    }
    if locked, let ratio = lockedAspectRatio {
      updateRect(CaptureSelectionGeometry.rectByLockingAspectRatio(currentRect, aspectRatio: ratio))
    }
  }

  func updateLockedAspectRatio(_ ratio: CGFloat?) {
    lockedAspectRatio = ratio
    guard aspectLocked, let ratio, ratio > 0 else { return }
    updateRect(CaptureSelectionGeometry.rectByLockingAspectRatio(currentRect, aspectRatio: ratio))
  }

  func applyRect(_ rect: CGRect) {
    updateRect(rect)
  }

  var rect: CGRect {
    currentRect
  }

  // MARK: - Overlays

  private func showRegionOverlays(for rect: CGRect) {
    for screen in NSScreen.screens {
      let overlay = RecordingRegionOverlayWindow(screen: screen, highlightRect: rect)
      overlay.interactionDelegate = self
      overlay.setInteractionEnabled(true)
      overlay.orderFrontRegardless()
      regionOverlayWindows.append(overlay)
    }
  }

  private func tearDownOverlays() {
    for overlay in regionOverlayWindows {
      overlay.interactionDelegate = nil
      overlay.close()
    }
    regionOverlayWindows.removeAll()
  }

  private func updateRect(_ rect: CGRect, notifyDuringInteraction: Bool = true) {
    let normalizedRect = CaptureSelectionGeometry.normalized(rect)
    guard normalizedRect != currentRect else { return }

    currentRect = normalizedRect
    for overlay in regionOverlayWindows {
      overlay.updateHighlightRect(normalizedRect)
    }

    if notifyDuringInteraction {
      publishRectChange()
    }
  }

  private func finishInteraction(with rect: CGRect) {
    var finalRect = CaptureSelectionGeometry.normalized(rect)
    if aspectLocked, let ratio = lockedAspectRatio, ratio > 0 {
      finalRect = CaptureSelectionGeometry.rectByLockingAspectRatio(finalRect, aspectRatio: ratio)
    }
    updateRect(finalRect)
  }

  private func publishRectChange() {
    onRectChanged?(currentRect)
  }

  // MARK: - Escape

  private func installEscapeMonitorsIfNeeded() {
    guard localEscapeMonitor == nil else { return }

    localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard event.keyCode == 53 else { return event }
      guard let self else { return event }
      return handleEscape() ? nil : event
    }

    globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard event.keyCode == 53 else { return }
      DispatchQueue.main.async {
        _ = self?.handleEscape()
      }
    }
  }

  private func removeEscapeMonitors() {
    if let localEscapeMonitor {
      NSEvent.removeMonitor(localEscapeMonitor)
      self.localEscapeMonitor = nil
    }
    if let globalEscapeMonitor {
      NSEvent.removeMonitor(globalEscapeMonitor)
      self.globalEscapeMonitor = nil
    }
  }

  @discardableResult
  private func handleEscape() -> Bool {
    onCancel?()
    tearDown()
    return true
  }
}

// MARK: - RecordingRegionOverlayDelegate

extension AllInOneSelectionRefinementController: RecordingRegionOverlayDelegate {
  func overlayDidRequestReselection(_: RecordingRegionOverlayWindow) {}

  func overlay(_: RecordingRegionOverlayWindow, didMoveRegionTo rect: CGRect) {
    updateRect(rect)
  }

  func overlayDidFinishMoving(_: RecordingRegionOverlayWindow) {
    finishInteraction(with: currentRect)
  }

  func overlay(_: RecordingRegionOverlayWindow, didReselectWithRect rect: CGRect) {
    finishInteraction(with: rect)
  }

  func overlay(_: RecordingRegionOverlayWindow, didResizeRegionTo rect: CGRect) {
    updateRect(rect)
  }

  func overlayDidFinishResizing(_: RecordingRegionOverlayWindow) {
    finishInteraction(with: currentRect)
  }
}
