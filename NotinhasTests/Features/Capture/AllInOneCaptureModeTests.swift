//
//  AllInOneCaptureModeTests.swift
//  NotinhasTests
//
//  Unit tests for All-In-One capture mode availability and stability.
//

@testable import Notinhas
import XCTest

final class AllInOneCaptureModeTests: XCTestCase {
  func testAvailableModes_withoutVideo_excludesRecording() {
    let modes = AllInOneCaptureMode.availableModes(videoEnabled: false)

    XCTAssertEqual(
      modes,
      [.area, .fullscreen, .window, .annotate, .scrolling, .ocr]
    )
    XCTAssertFalse(modes.contains(.recording))
  }

  func testAvailableModes_withVideo_includesRecordingLast() {
    let modes = AllInOneCaptureMode.availableModes(videoEnabled: true)

    XCTAssertEqual(modes.last, .recording)
    XCTAssertTrue(modes.contains(.recording))
    XCTAssertEqual(modes.count, 7)
  }

  func testRawValues_areStable() {
    XCTAssertEqual(AllInOneCaptureMode.area.rawValue, "area")
    XCTAssertEqual(AllInOneCaptureMode.fullscreen.rawValue, "fullscreen")
    XCTAssertEqual(AllInOneCaptureMode.window.rawValue, "window")
    XCTAssertEqual(AllInOneCaptureMode.annotate.rawValue, "annotate")
    XCTAssertEqual(AllInOneCaptureMode.scrolling.rawValue, "scrolling")
    XCTAssertEqual(AllInOneCaptureMode.ocr.rawValue, "ocr")
    XCTAssertEqual(AllInOneCaptureMode.recording.rawValue, "recording")
  }

  func testPreservesSelectionRect_matchesExpectedModes() {
    XCTAssertTrue(AllInOneCaptureMode.area.preservesSelectionRect)
    XCTAssertTrue(AllInOneCaptureMode.annotate.preservesSelectionRect)
    XCTAssertTrue(AllInOneCaptureMode.scrolling.preservesSelectionRect)
    XCTAssertTrue(AllInOneCaptureMode.ocr.preservesSelectionRect)
    XCTAssertTrue(AllInOneCaptureMode.recording.preservesSelectionRect)
    XCTAssertFalse(AllInOneCaptureMode.fullscreen.preservesSelectionRect)
    XCTAssertFalse(AllInOneCaptureMode.window.preservesSelectionRect)
  }

  func testTitlesAndAccessibilityLabels_areNonEmpty() {
    for videoEnabled in [false, true] {
      for mode in AllInOneCaptureMode.availableModes(videoEnabled: videoEnabled) {
        XCTAssertFalse(mode.title.isEmpty, mode.rawValue)
        XCTAssertFalse(mode.accessibilityLabel.isEmpty, mode.rawValue)
        XCTAssertFalse(mode.systemImage.isEmpty, mode.rawValue)
      }
    }
  }
}
