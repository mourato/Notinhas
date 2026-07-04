//
//  PreferencesUserConfigOverrideView.swift
//  Snapzy
//
//  "User Config Override" group for Settings > Advanced.
//  Enable toggle + gated rows: path, import, open, write-mode, promote diff.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesUserConfigOverrideView: View {
  @AppStorage(PreferencesKeys.configurationUserLayerEnabled)
  var userLayerEnabled = false

  @AppStorage(PreferencesKeys.configurationUserLayerFilePath)
  var userLayerFilePath = ""

  @AppStorage(PreferencesKeys.configurationUserLayerWriteMode)
  var userLayerWriteMode = SnapzyConfigurationWriteMode.defaultMode.rawValue

  @ObservedObject var configSyncCoordinator = SnapzyConfigurationSyncCoordinator.shared

  @State var isDiffSheetPresented = false

  let service = SnapzyConfigurationService.shared
  let tomlContentType = UTType(filenameExtension: "toml") ?? .plainText

  var resolvedPathDisplay: String {
    let path = userLayerFilePath.isEmpty
      ? SnapzyConfigurationPaths.collapsingHomePath(
          SnapzyConfigurationPaths.suggestedUserConfigURL.path)
      : userLayerFilePath
    return path.isEmpty ? "~/.config/snapzy/user-config.toml" : path
  }

  var configFileName: String {
    let path = userLayerFilePath.isEmpty
      ? SnapzyConfigurationPaths.suggestedUserConfigURL.path
      : userLayerFilePath
    return (path as NSString).lastPathComponent
  }

  var body: some View {
    Section(L10n.PreferencesAdvanced.userConfigOverrideSection) {
      SettingRow(
        icon: "doc.badge.gearshape",
        title: L10n.PreferencesAdvanced.userConfigOverrideEnabledTitle,
        description: L10n.PreferencesAdvanced.userConfigOverrideEnabledDescription
      ) {
        Toggle("", isOn: $userLayerEnabled)
          .labelsHidden()
          .onChange(of: userLayerEnabled) { _ in reApplyOnToggle() }
      }

      if userLayerEnabled {
        SettingRow(
          icon: "doc.text",
          title: L10n.PreferencesAdvanced.userConfigOverridePathTitle,
          description: resolvedPathDisplay
        ) {
          Button(L10n.PreferencesAdvanced.userConfigOverrideChangeButton) { changePath() }
            .buttonStyle(.bordered).controlSize(.small)
        }

        SettingRow(
          icon: "square.and.arrow.down",
          title: L10n.PreferencesAdvanced.userConfigOverrideImportTitle,
          description: L10n.PreferencesAdvanced.userConfigOverrideImportDescription
        ) {
          Button(L10n.PreferencesAdvanced.userConfigOverrideImportButton) { importUserConfig() }
            .buttonStyle(.bordered).controlSize(.small)
        }
        SettingRow(
          icon: "arrow.triangle.branch",
          title: L10n.PreferencesAdvanced.userConfigOverrideWriteModeTitle,
          description: L10n.PreferencesAdvanced.userConfigOverrideWriteModeDescription
        ) {
          Picker("", selection: $userLayerWriteMode) {
            Text(L10n.PreferencesAdvanced.userConfigOverrideWriteModePerKey)
              .tag(SnapzyConfigurationWriteMode.perKey.rawValue)
            Text(L10n.PreferencesAdvanced.userConfigOverrideWriteModePrimary)
              .tag(SnapzyConfigurationWriteMode.primary.rawValue)
          }
          .pickerStyle(.segmented)
          .frame(width: 200)
          .labelsHidden()
        }

        SettingRow(
          icon: "arrow.triangle.2.circlepath",
          title: L10n.PreferencesAdvanced.configSyncStatusTitle.replacingOccurrences(of: "config.toml", with: configFileName),
          description: configSyncStatusDescription
        ) {
          StatusBadge(configuration: configSyncBadgeConfiguration)
        }

        SettingRow(
          icon: "arrow.down.doc",
          title: L10n.PreferencesAdvanced.userConfigOverridePromoteTitle,
          description: L10n.PreferencesAdvanced.userConfigOverridePromoteDescription
        ) {
          Button(L10n.PreferencesAdvanced.userConfigOverridePromoteButton) {
            isDiffSheetPresented = true
          }
          .buttonStyle(.bordered).controlSize(.small)
        }

        HStack {
          Spacer()

          Button(L10n.PreferencesAdvanced.userConfigOverrideOpenButton) {
            openUserConfig()
          }
          .buttonStyle(.link)
          .controlSize(.small)
        }
      }
    }
    .sheet(isPresented: $isDiffSheetPresented) {
      PreferencesUserConfigDiffSheet()
    }
  }
}
