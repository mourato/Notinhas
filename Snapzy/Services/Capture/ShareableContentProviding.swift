//
//  ShareableContentProviding.swift
//  Snapzy
//
//  Minimal protocol seam over ScreenCaptureKit prefetch so unit tests can
//  inject a mock and avoid triggering the Screen Recording TCC prompt in CI.
//  ScreenCaptureManager already conforms (extension below).
//

import Foundation
import ScreenCaptureKit

/// Wraps the SCShareableContent prefetch API used by the area-capture hot path.
/// Conforming types: ScreenCaptureManager (production), MockShareableContentProvider (tests).
protocol ShareableContentProviding: AnyObject {
  func prefetchShareableContent(
    includeDesktopWindows: Bool,
    forceRefresh: Bool
  ) -> ShareableContentPrefetchTask?
}

extension ScreenCaptureManager: ShareableContentProviding {}
