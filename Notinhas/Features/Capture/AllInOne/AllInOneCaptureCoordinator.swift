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
  private var frozenSession: FrozenAreaCaptureSession?
  private var frozenBackdropHost = AllInOneFrozenBackdropHost()
  private let timerScheduler = AllInOneTimerScheduler()
  private var isActive = false
  private var isAwaitingInitialSelection = false
  private var sessionGeneration = UUID()

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
    let generation = UUID()
    sessionGeneration = generation

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

    if viewModel.isFreezeAreaCaptureEnabled {
      Task { @MainActor [weak self] in
        await self?.startWithFrozenSessionIfNeeded(generation: generation)
      }
    } else {
      continueStartup()
    }
  }

  func cancel() {
    guard isActive else {
      timerScheduler.cancel()
      return
    }

    sessionGeneration = UUID()
    tearDownSession(invalidateFrozenSession: true)
    DiagnosticLogger.shared.log(.info, .capture, "All-In-One capture session cancelled")
  }

  // MARK: - Private

  private func startWithFrozenSessionIfNeeded(generation: UUID) async {
    guard isActive, sessionGeneration == generation, let viewModel else { return }

    switch await viewModel.prepareAllInOneFrozenSelectionSession() {
    case .success(let session):
      guard isActive, sessionGeneration == generation else {
        session.invalidate()
        return
      }
      frozenSession = session
      continueStartup()
    case .failure(let error):
      guard isActive, sessionGeneration == generation else { return }
      viewModel.lastCaptureResult = .failure(error)
      tearDownSession(invalidateFrozenSession: true)
    }
  }

  private func continueStartup() {
    guard isActive else { return }

    installHUDs(using: sessionState!)

    let screenFrames = NSScreen.screens.map(\.frame)
    if let lastRect = CaptureLastSelectionStore.load(userDefaults: .standard, screens: screenFrames) {
      showFrozenBackdropHostIfNeeded()
      beginRefinement(with: lastRect)
    } else {
      startInitialAreaSelection()
    }
  }

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

    let backdrops = frozenSession?.backdrops ?? [:]
    AreaSelectionController.shared.startSelection(
      mode: .screenshot,
      backdrops: backdrops,
      completion: { [weak self] result in
        guard let self else { return }
        isAwaitingInitialSelection = false
        viewModel?.setAllInOneSelectionBlocking(false)

        guard isActive else { return }

        guard let result else {
          cancel()
          return
        }

        showFrozenBackdropHostIfNeeded()
        beginRefinement(with: result.rect)
      }
    )

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
      aspectRatio: aspectRatio,
      frozenBackdrops: frozenSession?.backdrops
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

  private func showFrozenBackdropHostIfNeeded() {
    guard let backdrops = frozenSession?.backdrops, !backdrops.isEmpty else { return }
    frozenBackdropHost.present(backdrops: backdrops)
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
    let freezeEnabled = viewModel.isFreezeAreaCaptureEnabled
    let transferredSession = frozenSession
    frozenSession = nil

    if let rect, mode.preservesSelectionRect {
      CaptureLastSelectionStore.save(rect, userDefaults: .standard)
    }

    if case let .timer(rect) = command {
      guard let rect else {
        transferredSession?.invalidate()
        DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture ignored: no selection")
        return
      }

      transferredSession?.invalidate()
      let capturedViewModel = viewModel
      let capturedRect = rect
      tearDownSession(invalidateFrozenSession: false)
      timerScheduler.scheduleAreaCapture { [capturedViewModel] in
        capturedViewModel.captureAreaWithFreshFrozenSession(at: capturedRect)
      }
      DiagnosticLogger.shared.log(.info, .capture, "All-In-One timer capture scheduled")
      return
    }

    tearDownSession(invalidateFrozenSession: false)

    switch command {
    case let .area(rect):
      if freezeEnabled {
        guard let transferredSession, let rect else {
          transferredSession?.invalidate()
          viewModel.lastCaptureResult = .failure(.captureFailed(L10n.ScreenCapture.unableToCaptureSelectedArea))
          return
        }
        viewModel.captureArea(at: rect, from: transferredSession)
      } else if let rect {
        viewModel.captureArea(at: rect)
      } else {
        viewModel.captureArea()
      }
    case .fullscreen:
      transferredSession?.invalidate()
      viewModel.captureFullscreen()
    case .window:
      transferredSession?.invalidate()
      viewModel.captureApplication()
    case let .annotate(rect):
      if freezeEnabled {
        guard let transferredSession, let rect else {
          transferredSession?.invalidate()
          viewModel.lastCaptureResult = .failure(.captureFailed(L10n.ScreenCapture.unableToCaptureSelectedArea))
          return
        }
        viewModel.captureAreaAnnotate(at: rect, from: transferredSession)
      } else if let rect {
        viewModel.captureAreaAnnotate(at: rect)
      } else {
        viewModel.captureAreaAnnotate()
      }
    case let .scrolling(rect):
      transferredSession?.invalidate()
      if let rect {
        viewModel.captureScrolling(at: rect)
      } else {
        viewModel.captureScrolling()
      }
    case let .ocr(rect):
      if freezeEnabled {
        guard let transferredSession, let rect else {
          transferredSession?.invalidate()
          viewModel.lastCaptureResult = .failure(.captureFailed(L10n.ScreenCapture.unableToCaptureSelectedArea))
          return
        }
        viewModel.captureOCR(at: rect, from: transferredSession)
      } else if let rect {
        viewModel.captureOCR(at: rect)
      } else {
        viewModel.captureOCR()
      }
    case .timer:
      transferredSession?.invalidate()
    case .recording:
      transferredSession?.invalidate()
      #if NOTINHAS_VIDEO_MODULE
        viewModel.startRecordingFlow()
      #endif
    }
  }

  private func tearDownSession(invalidateFrozenSession: Bool) {
    isActive = false
    let ownsInitialSelection = isAwaitingInitialSelection
    isAwaitingInitialSelection = false
    timerScheduler.cancel()
    viewModel?.setAllInOneSelectionBlocking(false)

    refinementController?.onCancel = nil
    refinementController?.onRectChanged = nil
    refinementController?.tearDown()
    refinementController = nil

    frozenBackdropHost.tearDown()

    if invalidateFrozenSession {
      frozenSession?.invalidate()
    }
    frozenSession = nil

    if ownsInitialSelection {
      AreaSelectionController.shared.cancelSelection()
    }

    modeHUD?.close()
    actionHUD?.close()
    modeHUD = nil
    actionHUD = nil
    sessionState = nil
    viewModel = nil
  }
}
