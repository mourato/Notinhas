//
//  SnapzyConfigurationUserLayer.swift
//  Snapzy
//
//  Model types for the optional user-config.toml override layer.
//  Sandbox is OFF — all file access is direct (no security-scoped bookmarks).
//

import Foundation

/// Controls where in-app setting changes are written when the user layer is active.
enum SnapzyConfigurationWriteMode: String {
  /// Changed key is written to user-config only if that key already exists there;
  /// otherwise falls back to the built-in config.toml. User-config stays lean.
  case perKey

  /// All changed keys go to user-config (growing the overrides set); built-in stays
  /// read-only base. Still lean — only keys the user actually changed land there.
  case primary

  static let defaultMode: Self = .perKey
}

/// Lightweight snapshot of the user-layer preference state from UserDefaults.
struct SnapzyConfigurationUserLayerState {
  let isEnabled: Bool
  let resolvedFileURL: URL
  let writeMode: SnapzyConfigurationWriteMode

  init(defaults: UserDefaults = .standard) {
    isEnabled = defaults.bool(forKey: PreferencesKeys.configurationUserLayerEnabled)

    let storedPath = defaults.string(forKey: PreferencesKeys.configurationUserLayerFilePath) ?? ""
    if storedPath.isEmpty {
      resolvedFileURL = SnapzyConfigurationPaths.suggestedUserConfigURL
    } else {
      let expanded = SnapzyConfigurationPaths.expandedUserPath(storedPath)
      resolvedFileURL = URL(fileURLWithPath: expanded)
    }

    let rawMode = defaults.string(forKey: PreferencesKeys.configurationUserLayerWriteMode) ?? ""
    writeMode = SnapzyConfigurationWriteMode(rawValue: rawMode) ?? .defaultMode
  }
}
