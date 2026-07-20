import Foundation

enum NotinhasImgurConfiguration {
  static let clientIDUserDefaultsKey = "notinhas.imgur.clientID"
  static let panelSideUserDefaultsKey = PreferencesKeys.notinhasNotesPanelSide

  static var clientID: String? {
    if let stored = UserDefaults.standard.string(forKey: clientIDUserDefaultsKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
      return stored
    }
    if let plist = Bundle.main.object(forInfoDictionaryKey: "IMGUR_CLIENT_ID") as? String {
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
