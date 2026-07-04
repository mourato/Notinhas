//
//  SnapzyConfigurationService+Bookmarks.swift
//  Snapzy
//
//  Security-scoped bookmark resolution and filesystem path helpers.
//

import Foundation

extension SnapzyConfigurationService {
  func rememberConfigFileAccess(_ url: URL) throws {
    try rememberAccess(to: url, key: PreferencesKeys.configurationFileBookmark)
  }

  func rememberConfigDirectoryAccess(_ url: URL) throws {
    try rememberAccess(to: url, key: PreferencesKeys.configurationDirectoryBookmark)
  }

  func rememberAccess(to url: URL, key: String) throws {
    let bookmarkData = try url.standardizedFileURL.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    defaults.set(bookmarkData, forKey: key)
  }

  func resolvedConfigAccessURL(for targetURL: URL) -> URL? {
    if let fileURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationFileBookmark),
       normalizedPath(fileURL) == normalizedPath(targetURL) {
      return fileURL
    }

    if let directoryURL = resolveBookmarkURL(forKey: PreferencesKeys.configurationDirectoryBookmark) {
      let targetPath = normalizedPath(targetURL)
      let directoryPath = normalizedPath(directoryURL)
      if targetPath == directoryPath || targetPath.hasPrefix(directoryPath + "/") {
        return directoryURL
      }
    }

    return nil
  }

  func resolveBookmarkURL(forKey key: String, removeInvalidBookmark: Bool = true) -> URL? {
    guard let bookmarkData = defaults.data(forKey: key) else { return nil }

    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      ).standardizedFileURL

      if isStale { try? rememberAccess(to: url, key: key) }
      return url
    } catch {
      if removeInvalidBookmark { defaults.removeObject(forKey: key) }
      return nil
    }
  }

  func normalizedPath(_ url: URL) -> String {
    url.standardizedFileURL.resolvingSymlinksInPath().path
  }

  var isRunningSandboxed: Bool {
    ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
  }
}
