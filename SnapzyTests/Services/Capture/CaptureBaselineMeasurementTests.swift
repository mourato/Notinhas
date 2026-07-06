//
//  CaptureBaselineMeasurementTests.swift
//  SnapzyTests
//
//  Phase 1 baseline measurement harness — replaces manual Instruments runs.
//  Each test exercises the REAL activation/render/snapshot code path and prints
//  `BASELINE ...` lines; numbers are recorded in
//  plans/20260705-2323-capture-performance/reports/baseline-numbers.md.
//
//  These orders real overlay windows front for a few hundred ms — local only,
//  never CI (skipIfRunningInCI + PerformanceRegression plan membership).
//

import AppKit
import QuartzCore
import XCTest
@testable import Snapzy

@MainActor
final class CaptureBaselineMeasurementTests: XCTestCase {

  private func percentile(_ sorted: [Double], _ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let idx = Int((Double(sorted.count - 1) * p).rounded())
    return sorted[idx]
  }

  private func report(_ label: String, _ samples: [Double]) {
    let s = samples.sorted()
    let fmt = { (v: Double) in String(format: "%.2f", v) }
    let line =
      "BASELINE \(label): n=\(s.count) min=\(fmt(s.first ?? 0))ms "
      + "p50=\(fmt(percentile(s, 0.5)))ms p95=\(fmt(percentile(s, 0.95)))ms "
      + "max=\(fmt(s.last ?? 0))ms samples=\(s.map(fmt))"
    print(line)
    // xcodebuild does not surface test-host stdout; persist to temp file so the
    // harness (or a human) can read numbers after the run.
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("snapzy-baseline.txt")
    let data = (line + "\n").data(using: .utf8)!
    if let handle = try? FileHandle(forWritingTo: out) {
      handle.seekToEndOfFile()
      handle.write(data)
      try? handle.close()
    } else {
      try? data.write(to: out)
    }
  }

  /// Live-mode activation: startSelection (pooled) → synchronous return ("interactive")
  /// and → next CA commit ("visible" proxy). This is the same path the Cmd+Shift+4
  /// live flow takes after CaptureViewModel prelude.
  func testBaseline_liveActivation_sessionStartToFirstCommit() throws {
    try skipIfRunningInCI()
    guard NSScreen.screens.first != nil else { throw XCTSkip("No display") }

    let controller = AreaSelectionController.shared
    controller.prepareWindowPool()
    // Warm-up cycle (first activation pays one-time costs we measure separately below).
    controller.startSelection { _ in }
    controller.cancelSelection()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    var interactiveMs: [Double] = []
    var commitMs: [Double] = []

    for _ in 0..<10 {
      let commitDone = expectation(description: "ca-commit")
      let t0 = CACurrentMediaTime()
      controller.startSelection { _ in }
      let t1 = CACurrentMediaTime()
      CATransaction.setCompletionBlock {
        commitMs.append((CACurrentMediaTime() - t0) * 1000)
        commitDone.fulfill()
      }
      interactiveMs.append((t1 - t0) * 1000)
      wait(for: [commitDone], timeout: 5)
      controller.cancelSelection()
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    report("live-activation-interactive", interactiveMs)
    report("live-activation-first-commit", commitMs)
    XCTAssertEqual(commitMs.count, 10)
  }

  /// Cold-ish first activation after pool rebuild is not measurable here (pool is a
  /// singleton already warmed); instead measure raw window construction cost — the
  /// dominant term of a cold start.
  func testBaseline_windowConstruction_cost() throws {
    try skipIfRunningInCI()
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No display") }

    var ms: [Double] = []
    for _ in 0..<5 {
      let t0 = CACurrentMediaTime()
      let window = AreaSelectionWindow(screen: screen, pooled: true)
      ms.append((CACurrentMediaTime() - t0) * 1000)
      window.close()
    }
    report("window-construction", ms)
    XCTAssertEqual(ms.count, 5)
  }

  /// Frozen-mode dominant cost: CGDisplayCreateImage via captureFastDisplaySnapshot.
  /// Without Screen Recording permission the image is wallpaper-only but timing is
  /// still representative of the WindowServer round-trip.
  func testBaseline_frozenSnapshot_fastPath() throws {
    try skipIfRunningInCI()
    guard let displayID = NSScreen.screens.first?.displayID else { throw XCTSkip("No display") }

    let manager = ScreenCaptureManager.shared
    var ms: [Double] = []
    for _ in 0..<5 {
      let t0 = CACurrentMediaTime()
      let snapshot = manager.captureFastDisplaySnapshot(
        displayID: displayID,
        showCursor: false,
        excludeDesktopIcons: false,
        excludeDesktopWidgets: false
      )
      let dt = (CACurrentMediaTime() - t0) * 1000
      guard snapshot != nil else {
        throw XCTSkip("captureFastDisplaySnapshot returned nil (fast path unavailable)")
      }
      ms.append(dt)
    }
    report("frozen-snapshot-fastpath", ms)
    XCTAssertEqual(ms.count, 5)
  }

  /// Per-frame drag rendering cost: renderManualSelection on a real overlay window.
  /// Target: well under one 120Hz frame (8.3ms); ideally <2ms.
  func testBaseline_renderManualSelection_perFrame() throws {
    try skipIfRunningInCI()
    guard let screen = NSScreen.screens.first else { throw XCTSkip("No display") }

    let window = AreaSelectionWindow(screen: screen, pooled: false)
    let view = window.overlayView
    view.setInteractionMode(.manualRegion, resetSelection: true)

    let iterations = 600
    var ms: [Double] = []
    ms.reserveCapacity(iterations)
    for i in 0..<iterations {
      // Simulate a growing drag from (100,100), varying every frame like real mouse input.
      let rect = CGRect(x: 100, y: 100, width: 50 + CGFloat(i), height: 40 + CGFloat(i) * 0.7)
      let point = CGPoint(x: rect.maxX, y: rect.maxY)
      let t0 = CACurrentMediaTime()
      view.renderManualSelection(screenRect: rect, currentScreenPoint: point)
      ms.append((CACurrentMediaTime() - t0) * 1000)
    }
    window.close()

    report("render-manual-selection-per-frame", ms)
    XCTAssertEqual(ms.count, iterations)
  }
}
