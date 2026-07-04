//
//  PreferencesUserConfigDiffSheet.swift
//  Snapzy
//
//  Sheet listing differing leaf keys between user-config.toml and built-in
//  config.toml. User selects keys to promote (copy) into built-in.
//  Direction: user-config → built-in ONLY. User-config is never modified.
//

import SwiftUI

struct PreferencesUserConfigDiffSheet: View {
  @Environment(\.dismiss) private var dismiss

  private let service = SnapzyConfigurationService.shared
  @State private var entries: [SnapzyConfigurationDiffEntry] = []
  @State private var selected: Set<String> = []

  var body: some View {
    VStack(spacing: 0) {
      headerBar

      if entries.isEmpty {
        emptyState
      } else {
        diffList
      }

      Divider()
      actionBar
    }
    .frame(minWidth: 520, minHeight: 380)
    .onAppear { reload() }
  }

  // MARK: - Sub-views

  private var headerBar: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(L10n.PreferencesAdvanced.userConfigPromoteSheetTitle)
        .font(.headline)
      Text(L10n.PreferencesAdvanced.userConfigOverridePromoteDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 36))
        .foregroundStyle(.secondary)
      Text(L10n.PreferencesAdvanced.userConfigPromoteNoChanges)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var diffList: some View {
    List(entries, id: \.dottedKey) { entry in
      DiffRow(entry: entry, isSelected: selected.contains(entry.dottedKey)) {
        if selected.contains(entry.dottedKey) {
          selected.remove(entry.dottedKey)
        } else {
          selected.insert(entry.dottedKey)
        }
      }
    }
    .listStyle(.inset)
  }

  private var actionBar: some View {
    HStack {
      Button(allSelected ? L10n.PreferencesAdvanced.userConfigPromoteDeselectAll
                         : L10n.PreferencesAdvanced.userConfigPromoteSelectAll) {
        toggleSelectAll()
      }
      .buttonStyle(.link)
      .controlSize(.small)

      Spacer()

      Button(L10n.Common.cancel, role: .cancel) { dismiss() }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .keyboardShortcut(.cancelAction)

      Button(L10n.PreferencesAdvanced.userConfigPromoteConfirmButton) {
        promote()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .disabled(selected.isEmpty)
      .keyboardShortcut(.defaultAction)
    }
    .padding()
  }

  // MARK: - Actions

  private var allSelected: Bool {
    !entries.isEmpty && selected.count == entries.count
  }

  private func toggleSelectAll() {
    if allSelected {
      selected = []
    } else {
      selected = Set(entries.map(\.dottedKey))
    }
  }

  private func reload() {
    entries = service.userConfigDiff()
    selected = Set(entries.map(\.dottedKey))
  }

  private func promote() {
    let keyPaths = entries
      .filter { selected.contains($0.dottedKey) }
      .map(\.keyPath)
    do {
      try service.promoteUserKeysToBuiltIn(keyPaths)
      AppToastManager.shared.show(
        message: L10n.PreferencesAdvanced.userConfigPromoteSucceeded,
        style: .success, duration: 2.4)
      dismiss()
    } catch {
      AppToastManager.shared.show(
        message: error.localizedDescription.isEmpty
          ? L10n.PreferencesAdvanced.userConfigPromoteFailed
          : error.localizedDescription,
        style: .error, duration: 4.0)
    }
  }
}

// MARK: - Row

private struct DiffRow: View {
  let entry: SnapzyConfigurationDiffEntry
  let isSelected: Bool
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Toggle("", isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
        .labelsHidden()
        .accessibilityLabel(entry.dottedKey)

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.dottedKey)
          .font(.system(.body, design: .monospaced))
          .fontWeight(.medium)

        HStack(spacing: 6) {
          if let base = entry.baseValue {
            Text(valueLabel(base))
              .font(.caption)
              .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Text(valueLabel(entry.overrideValue ?? .string("")))
            .font(.caption)
            .foregroundStyle(.primary)
        }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { onToggle() }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }

  private func valueLabel(_ value: SimpleTOMLValue) -> String {
    SimpleTOMLSerializer.inlineValue(value) ?? "(table)"
  }
}
