//
//  AllInOneCaptureCoordinator.swift
//  Notinhas
//
//  Owns the All-In-One capture session: HUD toolbars, selection refinement, and dispatch.
//

import AppKit
import SwiftUI

@MainActor
final class AllInOneCaptureCoordinator {
  static let shared = AllInOneCaptureCoordinator()

  private weak var viewModel: ScreenCaptureViewModel?
  private var sessionState: AllInOneCaptureSessionState?
  private var modeHUD: CaptureFloatingHUDWindow?
  private var actionHUD: CaptureFloatingHUDWindow?
  private var refinementController: AllInOneSelectionRefinementController?
  private let timerScheduler = AllInOneTimerScheduler()
  private var isActive = false
  private var isAwaitingInitialSelection = false

  private init() {}

  var isSessionActive: Bool {
    isActive
  }

  func start(from viewModel: ScreenCaptureViewModel) {
    timerScheduler.cancel()
    if isActive {
      cancel()
    }

    self.viewModel = viewModel
    isActive = true

    let state = AllInOneCaptureSessionState()
    state.onModeActivated = { [weak self] mode in
      self?.activate(mode)
    }
    state.onRectChanged = { [weak self] rect in
      self?.applyRect(rect)
    }
    state.onCancel = { [weak self] in
      self?.cancel()
    }
    sessionState = state

    installHUDs(using: state)

    let screenFrames = NSScreen.screens.map(\.frame)
    if let lastRect = CaptureLastSelectionStore.load(userDefaults: .standard, screens: screenFrames) {
      beginRefinement(with: lastRect)
    } else {
      startInitialAreaSelection()
    }
  }

  func cancel() {
    guard isActive else {
      timerScheduler.cancel()
      return
    }

    isActive = false
    let ownsInitialSelection = isAwaitingInitialSelection
    isAwaitingInitialSelection = false
    timerScheduler.cancel()
    viewModel?.setAllInOneSelectionBlocking(false)

    refinementController?.onCancel = nil
    refinementController?.onRectChanged = nil
    refinementController?.tearDown()
    refinementController = nil

    if ownsInitialSelection {
      AreaSelectionController.shared.cancelSelection()
    }

    modeHUD?.close()
    actionHUD?.close()
    modeHUD = nil
    actionHUD = nil
    sessionState = nil
    viewModel = nil

    DiagnosticLogger.shared.log(.info, .capture, "All-In-One capture session cancelled")
  }

  // MARK: - Private

  private func installHUDs(using state: AllInOneCaptureSessionState) {
    let modeWindow = CaptureFloatingHUDWindow()
    modeWindow.setContent(AnyView(AllInOneCaptureToolbarView(session: state)))

    let actionWindow = CaptureFloatingHUDWindow()
    actionWindow.setContent(AnyView(AllInOneActionToolbarView(session: state)))

    modeHUD = modeWindow
    actionHUD = actionWindow
    positionHUDs()
  }

  private func startInitialAreaSelection() {
    isAwaitingInitialSelection = true
    viewModel?.setAllInOneSelectionBlocking(true)

    AreaSelectionController.shared.startSelection { [weak self] rect in
      guard let self else { return }
      isAwaitingInitialSelection = false
      viewModel?.setAllInOneSelectionBlocking(false)

      guard isActive else { return }

      guard let rect else {
        cancel()
        return
      }

      beginRefinement(with: rect)
    }

    // AreaSelectionController presents screen-saver-level panels. Reassert the All-In-One
    // controls above them so the user can change modes before completing the first drag.
    DispatchQueue.main.async { [weak self] in
      guard let self, isActive, isAwaitingInitialSelection else { return }
      positionHUDs()
      modeHUD?.showAboveCaptureOverlay()
      actionHUD?.showAboveCaptureOverlay()
    }
  }

  private func beginRefinement(with rect: CGRect) {
    let normalized = CaptureSelectionGeometry.normalized(rect)
    sessionState?.currentRect = normalized
    positionHUDs()

    guard sessionState?.selectedMode.showsDimensionsBar == true else {
      return
    }

    let aspectLocked = UserDefaults.standard.bool(forKey: PreferencesKeys.captureAllInOneAspectRatioLocked)
    let aspectRatio = CaptureSelectionGeometry.aspectRatio(of: normalized)

    refinementController?.onCancel = nil
    refinementController?.onRectChanged = nil
    refinementController?.tearDown()

    let controller = AllInOneSelectionRefinementController(
      initialRect: normalized,
      aspectLocked: aspectLocked,
      aspectRatio: aspectRatio
    )
    controller.onRectChanged = { [weak self] updated in
      self?.handleRefinementRectChanged(updated)
    }
    controller.onCancel = { [weak self] in
      self?.cancel()
    }
    refinementController = controller
    controller.present()
  }

  private func handleRefinementRectChanged(_ rect: CGRect) {
    sessionState?.currentRect = rect
    positionHUDs()
  }

  private func applyRect(_ rect: CGRect) {
    let normalized = CaptureSelectionGeometry.normalized(rect)
    sessionState?.currentRect = normalized
    refinementController?.applyRect(normalized)
    positionHUDs()
  }

  private func positionHUDs() {
    let anchorRect = sessionState?.currentRect ?? defaultAnchorRect()

    if let actionHUD {
      actionHUD.refreshContentSize()
      actionHUD.show(anchorRect: anchorRect)
    }

    if let modeHUD, let actionHUD {
      modeHUD.refreshContentSize()
      let modeAnchor = modeToolbarAnchor(for: anchorRect, actionToolbarSize: actionHUD.frame.size)
      modeHUD.show(anchorRect: modeAnchor)
    } else if let modeHUD {
      modeHUD.refreshContentSize()
      modeHUD.show(anchorRect: anchorRect)
    }
  }

  private func modeToolbarAnchor(for selectionRect: CGRect, actionToolbarSize: CGSize) -> CGRect {
    CGRect(
      x: selectionRect.midX,
      y: selectionRect.maxY + actionToolbarSize.height + CaptureFloatingToolbarPlacement.outsideSelectionGap + 6,
      width: 1,
      height: 1
    )
  }

  private func defaultAnchorRect() -> CGRect {
    let screen = ScreenUtility.activeScreen()
    let frame = screen.visibleFrame
    return CGRect(
      x: frame.midX - 160,
      y: frame.midY - 120,
      width: 320,
      height: 240
    )
  }

  private func activate(_ mode: AllInOneCaptureMode) {
    guard isActive, let viewModel, let sessionState else { return }

    let rect = sessionState.currentRect
    let command = AllInOneCaptureCommand.make(for: mode, rect: rect)

    if let rect, mode.preservesSelectionRect {
      CaptureLastSelectionStore.save(rect, userDefaults: .standard)
    }

    if case let .timer(rect) = command {
      guard let rect else {
        DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture ignored: no selection")
        return
      }

      let capturedViewModel = viewModel
      let capturedRect = rect
      cancel()
      timerScheduler.scheduleAreaCapture { [capturedViewModel] in
        capturedViewModel.captureArea(at: capturedRect)
      }
      DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture scheduled")
      return
    }

    cancel()

    switch command {
    case let .area(rect):
      if let rect {
        viewModel.captureArea(at: rect)
      } else {
        viewModel.captureArea()
      }
    case .fullscreen:
      viewModel.captureFullscreen()
    case .window:
      viewModel.captureApplication()
    case let .annotate(rect):
      if let rect {
        viewModel.captureAreaAnnotate(at: rect)
      } else {
        viewModel.captureAreaAnnotate()
      }
    case let .scrolling(rect):
      if let rect {
        viewModel.captureScrolling(at: rect)
      } else {
        viewModel.captureScrolling()
      }
    case let .ocr(rect):
      if let rect {
        viewModel.captureOCR(at: rect)
      } else {
        viewModel.captureOCR()
      }
    case .timer:
      break
    case .recording:
      #if NOTINHAS_VIDEO_MODULE
        viewModel.startRecordingFlow()
      #endif
    }
  }
}
