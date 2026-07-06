//
//  MockShareableContentProvider.swift
//  SnapzyTests
//
//  TCC-safe mock for ShareableContentProviding.
//  Returns nil (no prefetch task) so tests never trigger Screen Recording permission prompts in CI.
//

import Foundation
@testable import Snapzy

final class MockShareableContentProvider: ShareableContentProviding {

  /// Number of times prefetchShareableContent was called.
  private(set) var prefetchCallCount = 0

  /// If set, returned as the prefetch task (allows tests to inject a custom task).
  var stubbedTask: ShareableContentPrefetchTask?

  func prefetchShareableContent(
    includeDesktopWindows: Bool,
    forceRefresh: Bool
  ) -> ShareableContentPrefetchTask? {
    prefetchCallCount += 1
    return stubbedTask
  }
}
