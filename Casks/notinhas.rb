cask "notinhas" do
  version "1.29.1"
  sha256 "d761801001fe579144f4866f9413ba32c75d1a5dc94011f9b84ced1824f5a88c"

  url "https://github.com/duongductrong/Notinhas/releases/download/v#{version}/Notinhas-v#{version}.dmg"
  name "Notinhas"
  desc "Native macOS screenshots, recording, annotation, and editing from the menu bar"
  homepage "https://github.com/duongductrong/Notinhas"

  depends_on macos: :ventura

  app "Notinhas.app"

  zap trash: [
    "~/Library/Application Support/Notinhas",
    "~/Library/Application Support/Snapzy",
    "~/Library/Preferences/Notinhas.plist",
    "~/Library/Preferences/com.mourato.notinhas.plist",
    "~/Library/Preferences/com.trongduong.snapzy.plist",
    "~/Library/Caches/Notinhas",
    "~/Library/Caches/Snapzy",
  ]

  # NOTE (pre-notarization): Notinhas was previously unsigned — kept for reference.
  # Uncomment if a future build ships without Developer ID notarization.
  # caveats <<~EOS
  #   Notinhas is not signed with an Apple Developer ID certificate.
  #   On first launch, macOS may block the app. To open it:
  #     Right-click Notinhas.app → Open → Open
  #   Or run:
  #     xattr -cr /Applications/Notinhas.app
  # EOS

  caveats <<~EOS
    Notinhas is signed and notarized by Apple (Developer ID).
    On first launch, grant Screen Recording permission when prompted in System Settings.
  EOS
end
