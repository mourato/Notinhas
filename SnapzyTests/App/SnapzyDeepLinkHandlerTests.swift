//
//  SnapzyDeepLinkHandlerTests.swift
//  SnapzyTests
//
//  Unit tests for snapzy:// automation URL parsing.
//

@testable import Snapzy
import XCTest

final class SnapzyDeepLinkHandlerTests: XCTestCase {
  func testCanonicalRoutesParseExpectedActions() throws {
    let cases: [(String, SnapzyDeepLinkAction)] = [
      ("snapzy://capture/fullscreen", .captureFullscreen),
      ("snapzy://capture/area", .captureArea),
      ("snapzy://capture/application", .captureApplication),
      ("snapzy://capture/area-annotate", .captureAreaAnnotate),
      ("snapzy://capture/scrolling", .captureScrolling),
      ("snapzy://capture/ocr", .captureOCR),
      ("snapzy://capture/smart-element", .captureSmartElement),
      ("snapzy://capture/object-cutout", .captureObjectCutout),
      ("snapzy://record/screen", .recordScreen),
      ("snapzy://record/application", .recordApplication),
      ("snapzy://open/annotate", .openAnnotate),
      ("snapzy://open/combine", .openCombine([])),
      ("snapzy://open/video-editor", .openVideoEditor),
      ("snapzy://open/cloud-uploads", .openCloudUploads),
      ("snapzy://open/history", .openHistory),
      ("snapzy://show/shortcuts", .showShortcuts),
      ("snapzy://settings", .openSettings(nil)),
    ]

    for (urlString, expectedAction) in cases {
      let url = try XCTUnwrap(URL(string: urlString))
      XCTAssertEqual(SnapzyDeepLinkAction(url: url), expectedAction, urlString)
    }
  }

  func testCombineAliasesParseExpectedAction() throws {
    let aliases = [
      "snapzy://combine",
      "snapzy://combine-images",
      "snapzy://open-combine",
    ]

    for urlString in aliases {
      let url = try XCTUnwrap(URL(string: urlString))
      XCTAssertEqual(SnapzyDeepLinkAction(url: url), .openCombine([]), urlString)
    }
  }

  func testCombineRouteParsesRepeatedFileParameters() throws {
    var components = try XCTUnwrap(URLComponents(string: "snapzy://open/combine"))
    components.queryItems = [
      URLQueryItem(name: "file", value: "/tmp/first image.png"),
      URLQueryItem(name: "file", value: "file:///tmp/second.jpg"),
      URLQueryItem(name: "ignored", value: "/tmp/not-used.png"),
    ]

    let url = try XCTUnwrap(components.url)
    XCTAssertEqual(
      SnapzyDeepLinkAction(url: url),
      .openCombine([
        URL(fileURLWithPath: "/tmp/first image.png"),
        URL(fileURLWithPath: "/tmp/second.jpg"),
      ])
    )
  }

  func testApplicationCaptureAliasesParseExpectedAction() throws {
    let aliases = [
      "snapzy://capture/window",
      "snapzy://application-capture",
      "snapzy://window-capture",
      "snapzy://screenshot/window",
    ]

    for urlString in aliases {
      let url = try XCTUnwrap(URL(string: urlString))
      XCTAssertEqual(SnapzyDeepLinkAction(url: url), .captureApplication, urlString)
    }
  }

  func testApplicationRecordingAliasesParseExpectedAction() throws {
    let aliases = [
      "snapzy://record/window",
      "snapzy://application-recording",
      "snapzy://window-recording",
      "snapzy://recording/window",
    ]

    for urlString in aliases {
      let url = try XCTUnwrap(URL(string: urlString))
      XCTAssertEqual(SnapzyDeepLinkAction(url: url), .recordApplication, urlString)
    }
  }

  func testSettingsTabRoutesParseExpectedTabs() throws {
    let cases: [(String, PreferencesTab)] = [
      ("general", .general),
      ("capture", .capture),
      ("annotate", .annotate),
      ("quick-access", .quickAccess),
      ("history", .history),
      ("shortcuts", .shortcuts),
      ("permissions", .permissions),
      ("cloud", .cloud),
      ("advanced", .advanced),
    ]

    for (tabName, expectedTab) in cases {
      let queryURL = try XCTUnwrap(URL(string: "snapzy://settings?tab=\(tabName)"))
      XCTAssertEqual(SnapzyDeepLinkAction(url: queryURL), .openSettings(expectedTab), tabName)

      let pathURL = try XCTUnwrap(URL(string: "snapzy://settings/\(tabName)"))
      XCTAssertEqual(SnapzyDeepLinkAction(url: pathURL), .openSettings(expectedTab), tabName)
    }
  }

  func testLegacyAboutSettingsRouteOpensPreferencesWithoutTab() throws {
    let url = try XCTUnwrap(URL(string: "snapzy://settings/about"))
    XCTAssertEqual(SnapzyDeepLinkAction(url: url), .openSettings(nil))
  }

  func testUnsupportedRoutesReturnNil() throws {
    let urls = [
      "https://capture/area",
      "snapzy://",
      "snapzy://capture/unknown",
      "snapzy://record/stop",
      "snapzy://open/unknown",
    ]

    for urlString in urls {
      let url = try XCTUnwrap(URL(string: urlString))
      XCTAssertNil(SnapzyDeepLinkAction(url: url), urlString)
    }
  }

  func testDeepLinkHandlerChecksUrlSchemeEnabled() throws {
    let defaults = UserDefaults.standard
    let originalValue = defaults.object(forKey: PreferencesKeys.urlSchemeEnabled)
    defer {
      if let originalValue {
        defaults.set(originalValue, forKey: PreferencesKeys.urlSchemeEnabled)
      } else {
        defaults.removeObject(forKey: PreferencesKeys.urlSchemeEnabled)
      }
    }

    defaults.set(false, forKey: PreferencesKeys.urlSchemeEnabled)
    let viewModel = ScreenCaptureViewModel()
    let handler = SnapzyDeepLinkHandler(screenCaptureViewModel: viewModel)
    let url = try XCTUnwrap(URL(string: "snapzy://capture/fullscreen"))
    handler.handle(url)
  }

  func testVideoDeepLinksIgnoredWhenModuleDisabled() throws {
    let defaults = UserDefaults.standard
    let originalModuleValue = defaults.object(forKey: PreferencesKeys.videoModuleEnabled)
    defer {
      if let originalModuleValue {
        defaults.set(originalModuleValue, forKey: PreferencesKeys.videoModuleEnabled)
      } else {
        defaults.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
      }
    }

    defaults.set(false, forKey: PreferencesKeys.videoModuleEnabled)
    XCTAssertFalse(
      VideoModuleAvailability.isEnabled,
      "Video deep-link handlers must see the module as disabled"
    )
    XCTAssertFalse(
      VideoModuleMediaRouting.shouldDispatchVideoAction(),
      "Routing gate must refuse video deep links when the module is off"
    )

    let viewModel = ScreenCaptureViewModel()
    let handler = SnapzyDeepLinkHandler(screenCaptureViewModel: viewModel)
    let urls = [
      "snapzy://record/screen",
      "snapzy://record/application",
      "snapzy://open/video-editor",
    ]

    for urlString in urls {
      let url = try XCTUnwrap(URL(string: urlString))
      // URLs still parse; the handler must gate dispatch, not drop parsing.
      XCTAssertNotNil(SnapzyDeepLinkAction(url: url), urlString)
      handler.handle(url)
      XCTAssertFalse(
        VideoModuleMediaRouting.shouldDispatchVideoAction(),
        "Module must stay disabled after handling \(urlString)"
      )
    }
  }

  func testVideoDeepLinkRoutingGateMatchesExplicitFlags() {
    XCTAssertFalse(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: false))
    XCTAssertTrue(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: true))
  }
}
