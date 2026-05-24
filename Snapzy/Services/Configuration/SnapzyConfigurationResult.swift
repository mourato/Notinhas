//
//  SnapzyConfigurationResult.swift
//  Snapzy
//
//  Import/export result models for TOML configuration.
//

import Foundation

enum SnapzyConfigurationIssueSeverity {
  case warning
  case error
}

struct SnapzyConfigurationIssue: Identifiable {
  let id = UUID()
  let severity: SnapzyConfigurationIssueSeverity
  let message: String
}

struct SnapzyConfigurationImportResult {
  let appliedChangeCount: Int
  let issues: [SnapzyConfigurationIssue]

  var hasErrors: Bool {
    issues.contains { $0.severity == .error }
  }
}

enum SnapzyConfigurationSyncDecision: Equatable {
  case alreadyCurrent
  case syncAutomatically
  case askBeforeReplacing
}

enum SnapzyConfigurationSyncStatus: Equatable {
  case alreadyCurrent
  case synced
  case needsConfirmation
}

struct SnapzyConfigurationSyncResult {
  let status: SnapzyConfigurationSyncStatus
  let fileURL: URL
}
