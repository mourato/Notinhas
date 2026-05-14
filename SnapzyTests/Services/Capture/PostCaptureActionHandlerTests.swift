//
//  PostCaptureActionHandlerTests.swift
//  SnapzyTests
//
//  Unit tests for PostCaptureActionHandler routing logic.
//

import XCTest
@testable import Snapzy

@MainActor
final class PostCaptureActionHandlerTests: XCTestCase {

  private var defaults: UserDefaults!
  private var preferences: PreferencesManager!
  private var tempDirectory: URL!
  private var tempFileURL: URL!

  override func setUp() async throws {
    try await super.setUp()
    defaults = UserDefaultsFactory.make()
    preferences = PreferencesManager(defaults: defaults)
    resetAfterCaptureActionsToDefaults()

    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("SnapzyTests_PostCapture_\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    // Create a minimal test image file
    tempFileURL = tempDirectory.appendingPathComponent("test_capture.png")
    guard let image = TestImageFactory.solidColor(width: 10, height: 10) else {
      XCTFail("Failed to create test image")
      return
    }
    let bitmapRep = NSBitmapImageRep(cgImage: image)
    let pngData = bitmapRep.representation(using: .png, properties: [:])
    try pngData?.write(to: tempFileURL)
  }

  override func tearDown() async throws {
    if let tempDirectory {
      try? FileManager.default.removeItem(at: tempDirectory)
    }
    try await super.tearDown()
  }

  private func resetAfterCaptureActionsToDefaults() {
    preferences.afterCaptureActions = Self.defaultAfterCaptureActions()
  }

  private static func defaultAfterCaptureActions() -> [AfterCaptureAction: [CaptureType: Bool]] {
    var defaults: [AfterCaptureAction: [CaptureType: Bool]] = [:]
    for action in AfterCaptureAction.allCases {
      defaults[action] = [:]
      for captureType in CaptureType.allCases {
        defaults[action]?[captureType] = defaultValue(for: action)
      }
    }
    return defaults
  }

  private static func defaultValue(for action: AfterCaptureAction) -> Bool {
    switch action {
    case .showQuickAccess, .save, .copyFile:
      return true
    case .openAnnotate, .uploadToCloud:
      return false
    }
  }

  // MARK: - PreferencesManager Routing Logic

  func testIsActionEnabled_defaultValues() {
    // Default: showQuickAccess and copyFile are ON for both types
    XCTAssertTrue(preferences.isActionEnabled(.showQuickAccess, for: .screenshot))
    XCTAssertTrue(preferences.isActionEnabled(.showQuickAccess, for: .recording))
    XCTAssertTrue(preferences.isActionEnabled(.copyFile, for: .screenshot))
    XCTAssertTrue(preferences.isActionEnabled(.copyFile, for: .recording))
    XCTAssertTrue(preferences.isActionEnabled(.save, for: .screenshot))
    XCTAssertTrue(preferences.isActionEnabled(.save, for: .recording))

    // Default: openAnnotate and uploadToCloud are OFF
    XCTAssertFalse(preferences.isActionEnabled(.openAnnotate, for: .screenshot))
    XCTAssertFalse(preferences.isActionEnabled(.openAnnotate, for: .recording))
    XCTAssertFalse(preferences.isActionEnabled(.uploadToCloud, for: .screenshot))
    XCTAssertFalse(preferences.isActionEnabled(.uploadToCloud, for: .recording))
  }

  func testSetAndCheckActionEnabled() {
    // Disable quickAccess for screenshots
    preferences.setAction(.showQuickAccess, for: .screenshot, enabled: false)
    XCTAssertFalse(preferences.isActionEnabled(.showQuickAccess, for: .screenshot))

    // Re-enable
    preferences.setAction(.showQuickAccess, for: .screenshot, enabled: true)
    XCTAssertTrue(preferences.isActionEnabled(.showQuickAccess, for: .screenshot))
  }

  // MARK: - Missing File Safety

  func testHandleScreenshotCapture_missingFile_doesNotAddToQuickAccess() async {
    let fakeQuickAccess = FakeQuickAccessManager()
    let handler = PostCaptureActionHandler(
      preferences: preferences,
      quickAccess: fakeQuickAccess,
      fileAccess: SandboxFileAccessManager.shared
    )
    let nonexistentURL = tempDirectory.appendingPathComponent("does_not_exist.png")

    await handler.handleScreenshotCapture(url: nonexistentURL)

    XCTAssertEqual(fakeQuickAccess.addedScreenshots.count, 0)
  }

  func testHandleVideoCapture_missingFile_doesNotAddToQuickAccess() async {
    let fakeQuickAccess = FakeQuickAccessManager()
    let handler = PostCaptureActionHandler(
      preferences: preferences,
      quickAccess: fakeQuickAccess,
      fileAccess: SandboxFileAccessManager.shared
    )
    let nonexistentURL = tempDirectory.appendingPathComponent("does_not_exist.mov")

    await handler.handleVideoCapture(url: nonexistentURL)

    XCTAssertEqual(fakeQuickAccess.addedVideos.count, 0)
  }

  func testHandleScreenshotCaptures_multipleFiles_addsAllToQuickAccess() async throws {
    preferences.setAction(.copyFile, for: .screenshot, enabled: false)
    let secondURL = tempDirectory.appendingPathComponent("test_capture_2.png")
    try FileManager.default.copyItem(at: tempFileURL, to: secondURL)
    let fakeQuickAccess = FakeQuickAccessManager()
    let handler = PostCaptureActionHandler(
      preferences: preferences,
      quickAccess: fakeQuickAccess,
      fileAccess: SandboxFileAccessManager.shared
    )

    await handler.handleScreenshotCaptures(urls: [tempFileURL, secondURL])

    XCTAssertEqual(fakeQuickAccess.addedScreenshots, [tempFileURL, secondURL])
  }

  func testHandleScreenshotCaptures_filtersMissingFiles() async throws {
    preferences.setAction(.copyFile, for: .screenshot, enabled: false)
    let missingURL = tempDirectory.appendingPathComponent("missing.png")
    let fakeQuickAccess = FakeQuickAccessManager()
    let handler = PostCaptureActionHandler(
      preferences: preferences,
      quickAccess: fakeQuickAccess,
      fileAccess: SandboxFileAccessManager.shared
    )

    await handler.handleScreenshotCaptures(urls: [missingURL, tempFileURL])

    XCTAssertEqual(fakeQuickAccess.addedScreenshots, [tempFileURL])
  }

  // MARK: - AfterCaptureAction Properties

  func testAfterCaptureAction_allCases() {
    let allCases = AfterCaptureAction.allCases
    XCTAssertEqual(allCases.count, 5)
    XCTAssertTrue(allCases.contains(.showQuickAccess))
    XCTAssertTrue(allCases.contains(.copyFile))
    XCTAssertTrue(allCases.contains(.save))
    XCTAssertTrue(allCases.contains(.openAnnotate))
    XCTAssertTrue(allCases.contains(.uploadToCloud))
  }

  func testAfterCaptureAction_displayNames_nonEmpty() {
    for action in AfterCaptureAction.allCases {
      XCTAssertFalse(action.displayName.isEmpty, "\(action.rawValue) has empty displayName")
    }
  }

  // MARK: - CaptureType Properties

  func testCaptureType_allCases() {
    XCTAssertEqual(CaptureType.allCases.count, 2)
    XCTAssertTrue(CaptureType.allCases.contains(.screenshot))
    XCTAssertTrue(CaptureType.allCases.contains(.recording))
  }

  func testCaptureType_rawValues() {
    XCTAssertEqual(CaptureType.screenshot.rawValue, "screenshot")
    XCTAssertEqual(CaptureType.recording.rawValue, "recording")
  }

  func testCaptureType_displayNames_nonEmpty() {
    for type in CaptureType.allCases {
      XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) has empty displayName")
    }
  }
}
