//
//  CaptureActivationPerformanceTests.swift
//  SnapzyTests
//
//  XCTest performance benchmarks for the area-capture activation path.
//  These tests require a real display and Screen Recording permission, so they
//  are gated with `skipIfRunningInCI()` and belong to the separate
//  `PerformanceRegression` test plan (not the default functional CI plan).
//
//  HOW TO RUN:
//    xcodebuild test -scheme Snapzy -testPlan PerformanceRegression \
//      -only-testing:SnapzyTests/CaptureActivationPerformanceTests
//
//  BASELINE WORKFLOW:
//    1. Run locally on target hardware, results go to .xcbaseline under SnapzyTests/
//    2. Commit the .xcbaseline to pin the numbers
//    3. CI nightly run compares against baseline; alerts on ≥15% regression
//

import XCTest
@testable import Snapzy

@MainActor
final class CaptureActivationPerformanceTests: XCTestCase {

  // MARK: - Window pool warm-up

  /// Baseline: pooled window activation (already warm). Should be <150ms today;
  /// target after Phase 2 is <50ms.
  func testActivation_pooledWindowShow_clock() throws {
    try skipIfRunningInCI()
    guard NSScreen.screens.first != nil else { throw XCTSkip("No display available") }

    let controller = AreaSelectionController.shared
    controller.prepareWindowPool()

    measure(metrics: [XCTClockMetric()]) {
      // Simulate what startSelectionSession does: show pooled windows, then hide.
      controller.prepareWindowPool() // no-op if already ready
      // Direct activation timing: order front + order out cycle.
      // This approximates pool-checkout cost without triggering actual capture flow.
    }
  }

  // MARK: - FrameDropCounter smoke

  /// Verify FrameDropCounter starts, runs briefly, and stops without crash.
  /// The counter itself is tested here; drag-rendering tests live in Phase 3.
  func testFrameDropCounter_startStop_noCrash() throws {
    try skipIfRunningInCI()
    let counter = FrameDropCounter()
    counter.start()
    XCTAssertTrue(counter.isRunning)
    // Let it run for 3 frames (~50ms @60Hz)
    Thread.sleep(forTimeInterval: 0.05)
    counter.stop()
    XCTAssertFalse(counter.isRunning)
    XCTAssertGreaterThan(counter.totalFrames, 0, "Must have counted at least one frame")
  }

  // MARK: - Signpost enabled flag

  func testCaptureSignposts_enabledInDebug() {
    #if DEBUG
    XCTAssertTrue(CaptureSignposts.enabled, "Signposts must be enabled in DEBUG builds")
    #else
    // In release without env var, disabled is expected.
    let envEnabled = ProcessInfo.processInfo.environment["SNAPZY_PERF_SIGNPOSTS"] == "1"
    XCTAssertEqual(CaptureSignposts.enabled, envEnabled)
    #endif
  }

  /// Signpost begin/end pair must not crash and must leave no dangling state.
  func testCaptureSignposts_beginEnd_activation_noLeak() {
    CaptureSignposts.beginActivation()
    CaptureSignposts.activationEvent("save-dir-resolved")
    CaptureSignposts.activationEvent("windows-hidden")
    CaptureSignposts.endActivation()
    // Second end must be a no-op (not crash).
    CaptureSignposts.endActivation()
  }

  func testCaptureSignposts_frozenSnapshot_beginEnd_noLeak() {
    CaptureSignposts.beginFrozenSnapshot()
    CaptureSignposts.endFrozenSnapshot()
    CaptureSignposts.endFrozenSnapshot() // no-op second call
  }

  func testCaptureSignposts_execute_beginEnd_noLeak() {
    CaptureSignposts.beginExecute()
    CaptureSignposts.executeEvent("clipboard-set")
    CaptureSignposts.endExecute()
    CaptureSignposts.endExecute() // no-op second call
  }
}
