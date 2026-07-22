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
  private var regionOverlayWindows: [ObjectIdentifier: RecordingRegionOverlayWindow] = [:]
  private var localEscapeMonitor: Any?
  private var globalEscapeMonitor: Any?
  private var screenParametersObserver: NSObjectProtocol?

  private var aspectLocked: Bool
  private var lockedAspectRatio: CGFloat?
  private var resizeStartRect: CGRect?
  private var activeResizeHandle: CaptureSelectionResizeHandle?

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

  deinit {
    if let screenParametersObserver {
      NotificationCenter.default.removeObserver(screenParametersObserver)
    }
    if let localEscapeMonitor {
      NSEvent.removeMonitor(localEscapeMonitor)
    }
    if let globalEscapeMonitor {
      NSEvent.removeMonitor(globalEscapeMonitor)
    }
    regionOverlayWindows.removeAll()
  }

  // MARK: - Session

  func present() {
    tearDownOverlays()
    observeScreenParameters()
    reconcileScreenOverlays()
    installEscapeMonitorsIfNeeded()
    publishRectChange()
  }

  func tearDown() {
    removeEscapeMonitors()
    removeScreenParametersObserver()
    tearDownOverlays()
    resizeStartRect = nil
    activeResizeHandle = nil
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

  private func makeRegionOverlay(for screen: NSScreen) -> RecordingRegionOverlayWindow {
    let overlay = RecordingRegionOverlayWindow(screen: screen, highlightRect: currentRect)
    overlay.interactionDelegate = self
    overlay.setInteractionEnabled(true)
    overlay.orderFrontRegardless()
    return overlay
  }

  private func observeScreenParameters() {
    guard screenParametersObserver == nil else { return }
    screenParametersObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.reconcileScreenOverlays()
    }
  }

  private func removeScreenParametersObserver() {
    if let screenParametersObserver {
      NotificationCenter.default.removeObserver(screenParametersObserver)
      self.screenParametersObserver = nil
    }
  }

  private func reconcileScreenOverlays() {
    let screens = NSScreen.screens
    let screenIDs = Set(screens.map(ObjectIdentifier.init))

    let removedScreenIDs = regionOverlayWindows.keys.filter { !screenIDs.contains($0) }
    for screenID in removedScreenIDs {
      guard let overlay = regionOverlayWindows[screenID] else { continue }
      overlay.interactionDelegate = nil
      overlay.close()
      regionOverlayWindows.removeValue(forKey: screenID)
    }

    for screen in screens {
      let screenID = ObjectIdentifier(screen)
      if let overlay = regionOverlayWindows[screenID] {
        overlay.updateHighlightRect(currentRect)
      } else {
        regionOverlayWindows[screenID] = makeRegionOverlay(for: screen)
      }
    }
  }

  private func tearDownOverlays() {
    for overlay in regionOverlayWindows.values {
      overlay.interactionDelegate = nil
      overlay.close()
    }
    regionOverlayWindows.removeAll()
  }

  private func updateRect(_ rect: CGRect, notifyDuringInteraction: Bool = true) {
    let normalizedRect = CaptureSelectionGeometry.normalized(rect)
    guard normalizedRect != currentRect else { return }

    currentRect = normalizedRect
    for overlay in regionOverlayWindows.values {
      overlay.updateHighlightRect(normalizedRect)
    }

    if notifyDuringInteraction {
      publishRectChange()
    }
  }

  private func finishInteraction(with rect: CGRect) {
    var finalRect = CaptureSelectionGeometry.normalized(rect)
    if aspectLocked, activeResizeHandle != nil {
      finalRect = aspectLockedResizeRect(from: rect)
    } else if aspectLocked, let ratio = lockedAspectRatio, ratio > 0 {
      finalRect = CaptureSelectionGeometry.rectByLockingAspectRatio(finalRect, aspectRatio: ratio)
    }
    updateRect(finalRect)
    resizeStartRect = nil
    activeResizeHandle = nil
  }

  private func beginResizeIfNeeded(with proposedRect: CGRect) {
    guard resizeStartRect == nil else { return }
    resizeStartRect = currentRect
    activeResizeHandle = inferResizeHandle(from: currentRect, to: proposedRect)
  }

  private func aspectLockedResizeRect(from proposedRect: CGRect) -> CGRect {
    guard let startRect = resizeStartRect,
          let handle = activeResizeHandle,
          let ratio = lockedAspectRatio,
          ratio > 0 else {
      return CaptureSelectionGeometry.normalized(proposedRect)
    }

    return CaptureSelectionGeometry.resizedRect(
      original: startRect,
      handle: handle,
      translation: resizeTranslation(from: startRect, to: proposedRect, handle: handle),
      aspectLocked: true,
      aspectRatio: ratio
    )
  }

  private func inferResizeHandle(from startRect: CGRect, to proposedRect: CGRect) -> CaptureSelectionResizeHandle {
    let tolerance: CGFloat = 0.01
    let leftChanged = abs(startRect.minX - proposedRect.minX) > tolerance
    let rightChanged = abs(startRect.maxX - proposedRect.maxX) > tolerance
    let bottomChanged = abs(startRect.minY - proposedRect.minY) > tolerance
    let topChanged = abs(startRect.maxY - proposedRect.maxY) > tolerance

    switch (leftChanged, rightChanged, bottomChanged, topChanged) {
    case (true, false, true, false): return .bottomLeft
    case (true, false, false, true): return .topLeft
    case (false, true, true, false): return .bottomRight
    case (false, true, false, true): return .topRight
    case (false, true, false, false): return .right
    case (true, false, false, false): return .left
    case (false, false, true, false): return .bottom
    case (false, false, false, true): return .top
    default: return .bottomRight
    }
  }

  private func resizeTranslation(
    from startRect: CGRect,
    to proposedRect: CGRect,
    handle: CaptureSelectionResizeHandle
  ) -> CGPoint {
    switch handle {
    case .topLeft:
      CGPoint(x: proposedRect.minX - startRect.minX, y: proposedRect.height - startRect.height)
    case .top:
      CGPoint(x: 0, y: proposedRect.height - startRect.height)
    case .topRight:
      CGPoint(x: proposedRect.width - startRect.width, y: proposedRect.height - startRect.height)
    case .left:
      CGPoint(x: proposedRect.minX - startRect.minX, y: 0)
    case .right:
      CGPoint(x: proposedRect.width - startRect.width, y: 0)
    case .bottomLeft:
      CGPoint(x: proposedRect.minX - startRect.minX, y: proposedRect.minY - startRect.minY)
    case .bottom:
      CGPoint(x: 0, y: proposedRect.minY - startRect.minY)
    case .bottomRight:
      CGPoint(x: proposedRect.width - startRect.width, y: proposedRect.minY - startRect.minY)
    }
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
    beginResizeIfNeeded(with: rect)
    updateRect(aspectLocked ? aspectLockedResizeRect(from: rect) : rect)
  }

  func overlayDidFinishResizing(_: RecordingRegionOverlayWindow) {
    finishInteraction(with: currentRect)
  }
}
