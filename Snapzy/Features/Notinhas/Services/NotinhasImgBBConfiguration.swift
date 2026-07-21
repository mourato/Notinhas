import Foundation

enum NotinhasImgBBConfiguration {
  static let apiKeyUserDefaultsKey = "notinhas.imgbb.apiKey"
  static let panelSideUserDefaultsKey = PreferencesKeys.notinhasNotesPanelSide

  static var apiKey: String? {
    if let stored = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
      return stored
    }
    if let plist = Bundle.main.object(forInfoDictionaryKey: "IMGBB_API_KEY") as? String {
      let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty {
        return trimmed
      }
    }
    return nil
  }

  static var panelSide: NotinhasNotesPanelSide {
    migratePanelSideIfNeeded()
    return NotinhasNotesPanelSide.resolved(from: UserDefaults.standard.string(forKey: panelSideUserDefaultsKey))
  }

  static func migratePanelSideIfNeeded(defaults: UserDefaults = .standard) {
    guard defaults.object(forKey: PreferencesKeys.notinhasNotesPanelSide) == nil,
          let legacyValue = defaults.string(forKey: PreferencesKeys.legacyNotinhasNotesPanelSide)
    else { return }
    defaults.set(legacyValue, forKey: PreferencesKeys.notinhasNotesPanelSide)
  }
}
