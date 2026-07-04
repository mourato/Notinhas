//
//  PreferencesUserConfigOverrideView+Actions.swift
//  Snapzy
//
//  User-initiated actions: toggle re-apply, path change, import, open, toast helpers.
//

import AppKit
import SwiftUI

extension PreferencesUserConfigOverrideView {

  func reApplyOnToggle() {
    Task { @MainActor in
      if userLayerEnabled {
        _ = SnapzyConfigurationAutoImporter.applyIfNeededOnLaunch(service: service, force: true)
      } else {
        let builtInURL = service.resolvedConfigFileURL
        _ = SnapzyConfigurationAutoImporter.applyIfNeeded(from: builtInURL, force: true)
      }
    }
  }

  func changePath() {
    SnapzyConfigurationAccessGranting.chooseUserConfigPath { _ in
      // Path persisted inside chooseUserConfigPath; @AppStorage refreshes automatically.
    }
  }

  func importUserConfig() {
    let panel = NSOpenPanel()
    panel.title = L10n.PreferencesAdvanced.importPanelTitle
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [tomlContentType]
    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let result = try service.importUserConfig(from: url)
      showImportNotice(for: result)
    } catch {
      showNotice(error.localizedDescription,
                 fallback: L10n.PreferencesAdvanced.userConfigImportFailed,
                 style: .error)
    }
  }

  func openUserConfig() {
    let userURL = service.resolvedUserConfigFileURL
    let fm = FileManager.default
    if !fm.fileExists(atPath: userURL.path) {
      try? fm.createDirectory(at: userURL.deletingLastPathComponent(),
                              withIntermediateDirectories: true)
      try? "".write(to: userURL, atomically: true, encoding: .utf8)
    }

    NSWorkspace.shared.open(userURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
      DispatchQueue.main.async {
        if let error {
          self.showNotice(error.localizedDescription,
                         fallback: L10n.PreferencesAdvanced.userConfigOpenUnavailable,
                         style: .error)
        } else {
          self.showNotice(L10n.PreferencesAdvanced.userConfigOpenSucceeded, style: .success)
        }
      }
    }
  }

  func showImportNotice(for result: SnapzyConfigurationImportResult) {
    showNotice(
      result.hasErrors
        ? L10n.PreferencesAdvanced.userConfigImportFailed
        : L10n.PreferencesAdvanced.userConfigImportSucceeded,
      style: result.hasErrors ? .error : .success)
  }

  func showNotice(_ message: String, fallback: String? = nil, style: AppToastStyle) {
    let text = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? fallback ?? L10n.PreferencesAdvanced.operationFinished
      : message
    AppToastManager.shared.show(message: text, style: style,
                                duration: style == .success ? 2.4 : 4.0)
  }
}
