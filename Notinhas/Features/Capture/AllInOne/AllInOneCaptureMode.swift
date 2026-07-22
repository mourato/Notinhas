//
//  AllInOneCaptureMode.swift
//  Notinhas
//
//  Capture modes available in the All-In-One session toolbar.
//

import Foundation

enum AllInOneCaptureMode: String, CaseIterable, Identifiable, Equatable {
  case area
  case fullscreen
  case window
  case annotate
  case scrolling
  case ocr
  case recording

  var id: String {
    rawValue
  }

  static func availableModes(videoEnabled: Bool) -> [AllInOneCaptureMode] {
    var modes: [AllInOneCaptureMode] = [.area, .fullscreen, .window, .annotate, .scrolling, .ocr]
    if videoEnabled {
      modes.append(.recording)
    }
    return modes
  }

  var systemImage: String {
    switch self {
    case .area: "rectangle.dashed"
    case .fullscreen: "rectangle.inset.filled"
    case .window: "macwindow"
    case .annotate: "pencil.and.scribble"
    case .scrolling: "arrow.up.and.down"
    case .ocr: "text.viewfinder"
    case .recording: "record.circle"
    }
  }

  var title: String {
    switch self {
    case .area: L10n.Actions.captureArea
    case .fullscreen: L10n.Actions.captureFullscreen
    case .window: L10n.AllInOne.windowMode
    case .annotate: L10n.Actions.captureAreaAnnotate
    case .scrolling: L10n.Actions.scrollingCapture
    case .ocr: L10n.Actions.captureTextOCR
    case .recording: L10n.Actions.recordVideo
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .area: L10n.AllInOne.modeAreaAccessibility
    case .fullscreen: L10n.AllInOne.modeFullscreenAccessibility
    case .window: L10n.AllInOne.modeWindowAccessibility
    case .annotate: L10n.AllInOne.modeAnnotateAccessibility
    case .scrolling: L10n.AllInOne.modeScrollingAccessibility
    case .ocr: L10n.AllInOne.modeOCRAccessibility
    case .recording: L10n.AllInOne.modeRecordingAccessibility
    }
  }

  var preservesSelectionRect: Bool {
    switch self {
    case .area, .annotate, .scrolling, .ocr, .recording:
      true
    case .fullscreen, .window:
      false
    }
  }

  var showsDimensionsBar: Bool {
    preservesSelectionRect
  }
}
