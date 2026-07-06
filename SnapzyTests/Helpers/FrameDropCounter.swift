//
//  FrameDropCounter.swift
//  SnapzyTests
//
//  CVDisplayLink-based dropped-frame counter for Phase 3 drag-rendering tests.
//  Built in Phase 1 so Phase 3 can import it without setup churn.
//
//  Usage:
//    let counter = FrameDropCounter()
//    counter.start()
//    // ... simulate drag ...
//    counter.stop()
//    XCTAssertEqual(counter.droppedFrames, 0)
//

import CoreVideo
import Foundation

/// Counts frames where the actual presentation time exceeded the expected refresh interval by >50%.
/// Threshold of 50% (half a frame) is intentionally lenient to avoid flakiness from OS scheduling jitter.
final class FrameDropCounter {

  private var displayLink: CVDisplayLink?
  private(set) var totalFrames: Int = 0
  private(set) var droppedFrames: Int = 0
  private var lastTimestamp: CVTimeStamp?

  var isRunning: Bool { displayLink.map { CVDisplayLinkIsRunning($0) } ?? false }

  func start() {
    totalFrames = 0
    droppedFrames = 0
    lastTimestamp = nil

    var link: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(&link)
    guard let link else { return }

    let counter = Unmanaged.passRetained(self)
    CVDisplayLinkSetOutputCallback(link, { _, inNow, inOutputTime, _, _, userInfo -> CVReturn in
      let counter = Unmanaged<FrameDropCounter>.fromOpaque(userInfo!).takeUnretainedValue()
      counter.recordFrame(timestamp: inNow.pointee)
      return kCVReturnSuccess
    }, counter.toOpaque())

    displayLink = link
    CVDisplayLinkStart(link)
  }

  func stop() {
    guard let link = displayLink else { return }
    CVDisplayLinkStop(link)
    CVDisplayLinkSetOutputCallback(link, nil, nil)
    displayLink = nil
    // Balance the passRetained from start()
    Unmanaged.passUnretained(self).release()
  }

  private func recordFrame(timestamp: CVTimeStamp) {
    defer { lastTimestamp = timestamp }
    totalFrames += 1
    guard let last = lastTimestamp else { return }

    // Convert mach absolute time delta to seconds via mach_timebase_info.
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let deltaNs = Double(timestamp.hostTime &- last.hostTime)
      * Double(timebase.numer) / Double(timebase.denom)
    let deltaSec = deltaNs / 1_000_000_000

    let expectedSec = Double(timestamp.videoRefreshPeriod) / Double(timestamp.videoTimeScale)
    guard expectedSec > 0 else { return }

    // A frame is "dropped" if the gap is more than 1.5× the refresh period.
    if deltaSec > expectedSec * 1.5 {
      droppedFrames += 1
    }
  }
}
