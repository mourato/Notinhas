//
//  PreferencesUserConfigOverrideView+Status.swift
//  Snapzy
//
//  Sync-status description text and StatusBadge configuration helpers.
//

import SwiftUI

extension PreferencesUserConfigOverrideView {

  var configSyncStatusDescription: String {
    let rawText: String
    switch configSyncCoordinator.status {
    case .idle:             rawText = L10n.PreferencesAdvanced.configSyncIdleDescription
    case .scheduled:        rawText = L10n.PreferencesAdvanced.configSyncQueuedDescription
    case .syncing:          rawText = L10n.PreferencesAdvanced.configSyncWritingDescription
    case .upToDate(let d):  rawText = L10n.PreferencesAdvanced.configSyncUpToDateDescription(timeText(d))
    case .synced(let d):    rawText = L10n.PreferencesAdvanced.configSyncSyncedDescription(timeText(d))
    case .needsPermission:  rawText = L10n.PreferencesAdvanced.configAccessRequiredToast
    case .conflict:         rawText = L10n.PreferencesAdvanced.configSyncNeedsConfirmation
    case .failed(let m):    rawText = m.isEmpty ? L10n.PreferencesAdvanced.openConfigUnavailable : m
    }
    return rawText.replacingOccurrences(of: "config.toml", with: configFileName)
  }

  var configSyncBadgeConfiguration: StatusBadge.Configuration {
    let configFileName = self.configFileName
    switch configSyncCoordinator.status {
    case .idle, .upToDate, .synced:
      let label = L10n.PreferencesAdvanced.configSyncBadgeSynced.replacingOccurrences(of: "config.toml", with: configFileName)
      return .init(label: label,
                   systemImage: "checkmark.circle.fill", tint: .green)
    case .scheduled:
      let label = L10n.PreferencesAdvanced.configSyncBadgeQueued.replacingOccurrences(of: "config.toml", with: configFileName)
      return .init(label: label,
                   systemImage: "clock.fill", tint: .blue)
    case .syncing:
      let label = L10n.PreferencesAdvanced.configSyncBadgeSyncing.replacingOccurrences(of: "config.toml", with: configFileName)
      return .init(label: label,
                   tint: .blue, showsProgress: true)
    case .needsPermission:
      return .init(label: L10n.PreferencesAdvanced.configSyncBadgeAccessNeeded,
                   systemImage: "lock.fill", tint: .orange)
    case .conflict:
      return .init(label: L10n.PreferencesAdvanced.configSyncBadgeReviewNeeded,
                   systemImage: "exclamationmark.triangle.fill", tint: .orange)
    case .failed:
      return .init(label: L10n.PreferencesAdvanced.configSyncBadgeFailed,
                   systemImage: "xmark.octagon.fill", tint: .red)
    }
  }

  func timeText(_ date: Date) -> String {
    DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
  }
}
