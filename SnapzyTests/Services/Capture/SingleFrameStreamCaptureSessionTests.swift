//
//  SingleFrameStreamCaptureSessionTests.swift
//  SnapzyTests
//
//  Regression tests for GitHub issue #286: the macOS 13 single-frame SCStream
//  fallback must always terminate (first frame, stream error, timeout or
//  cancellation) and resume its continuation exactly once — it must never hang
//  forever. Tests drive the session's state machine directly so no Screen
//  Recording permission is required.
//

import CoreGraphics
import XCTest
@testable import Snapzy

@MainActor
final class SingleFrameStreamCaptureSessionTests: XCTestCase {

  /// Arms a session (continuation installed, timeout ticking) and returns it along
  /// with the task awaiting the frame. No SCStream is created.
  private func armedSession(
    timeout: TimeInterval
  ) -> (session: SingleFrameStreamCaptureSession, task: Task<CGImage, Error>) {
    let session = SingleFrameStreamCaptureSession()
    let task = Task<CGImage, Error> {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
        session.arm(continuation: continuation, timeout: timeout)
      }
    }
    return (session, task)
  }

  private func makeTestImage() -> CGImage {
    let context = CGContext(
      data: nil,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
  }

  func testFinish_firstResultWins_secondFinishIgnored() async throws {
    let (session, task) = armedSession(timeout: 60)

    let image = makeTestImage()
    session.finish(.success(image))
    // Second resume attempt must be ignored (a double resume would trap).
    session.finish(.failure(CaptureError.cancelled))

    let result = try await task.value
    XCTAssertEqual(result.width, 1)
    XCTAssertEqual(result.height, 1)
  }

  func testTimeout_noFrameArriving_throwsWithinBoundedTime() async {
    let (session, task) = armedSession(timeout: 0.2)

    let startedAt = Date()
    do {
      _ = try await task.value
      XCTFail("Expected a timeout error, got a frame")
    } catch {
      // The wait must terminate promptly — before the fix it hung forever.
      XCTAssertLessThan(Date().timeIntervalSince(startedAt), 5)
      guard case CaptureError.captureFailed = error else {
        XCTFail("Expected CaptureError.captureFailed, got \(error)")
        return
      }
    }
    _ = session // keep the session alive across the await
  }

  func testCancel_pendingWait_throwsCancelledPromptly() async {
    let (session, task) = armedSession(timeout: 60)

    let startedAt = Date()
    session.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected a cancellation error, got a frame")
    } catch {
      XCTAssertLessThan(Date().timeIntervalSince(startedAt), 5)
      guard case CaptureError.cancelled = error else {
        XCTFail("Expected CaptureError.cancelled, got \(error)")
        return
      }
    }
  }

  func testFinishFailure_propagatesError() async {
    let (session, task) = armedSession(timeout: 60)

    session.finish(.failure(CaptureError.noDisplayFound))

    do {
      _ = try await task.value
      XCTFail("Expected an error, got a frame")
    } catch {
      guard case CaptureError.noDisplayFound = error else {
        XCTFail("Expected CaptureError.noDisplayFound, got \(error)")
        return
      }
    }
  }

  func testTimeout_afterSuccessfulFinish_doesNotResumeAgain() async throws {
    let (session, task) = armedSession(timeout: 0.1)

    session.finish(.success(makeTestImage()))
    _ = try await task.value

    // Let the (cancelled) timeout lapse; a late fire or finish must not resume twice.
    try await Task.sleep(nanoseconds: 300_000_000)
    session.finish(.failure(CaptureError.cancelled))
  }
}
