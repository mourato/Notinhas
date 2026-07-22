//
//  AllInOneCaptureSessionState.swift
//  Notinhas
//
//  Observable session state shared between All-In-One HUD views and the coordinator.
//

import Combine
import CoreGraphics
import Foundation

@MainActor
final class AllInOneCaptureSessionState: ObservableObject {
  @Published var selectedMode: AllInOneCaptureMode = .area
  @Published var currentRect: CGRect?
  @Published private(set) var availableModes: [AllInOneCaptureMode]

  var onModeSelected: (AllInOneCaptureMode) -> Void = { _ in }
  var onRectChanged: (CGRect) -> Void = { _ in }
  var onConfirmCapture: () -> Void = {}
  var onCancel: () -> Void = {}

  init(videoEnabled: Bool = VideoModuleAvailability.isEnabled) {
    availableModes = AllInOneCaptureMode.availableModes(videoEnabled: videoEnabled)
  }

  func selectMode(_ mode: AllInOneCaptureMode) {
    guard availableModes.contains(mode) else { return }
    selectedMode = mode
    onModeSelected(mode)
  }

  func updateRect(_ rect: CGRect) {
    currentRect = rect
    onRectChanged(rect)
  }

  func confirmCapture() {
    onConfirmCapture()
  }

  func cancel() {
    onCancel()
  }
}
