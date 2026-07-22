//
//  CaptureFloatingHUDWindowTests.swift
//  NotinhasTests
//

import AppKit
@testable import Notinhas
import SwiftUI
import XCTest

@MainActor
final class CaptureFloatingHUDWindowTests: XCTestCase {
  func testHUDWindow_usesTransparentNonActivatingHost() {
    let window = CaptureFloatingHUDWindow()
    window.setContent(AnyView(Text("HUD")))

    XCTAssertFalse(window.isOpaque)
    XCTAssertEqual(window.backgroundColor, .clear)
    XCTAssertFalse(window.canBecomeKey)
    XCTAssertTrue(window.contentView is NSHostingView<AnyView>)
    XCTAssertFalse(window.contentView is NSVisualEffectView)

    window.close()
  }
}
