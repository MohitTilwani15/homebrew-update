cask "homebew-menubar" do
  version "0.1.0"
  sha256 "REPLACE_WITH_ZIP_SHA256"

  url "https://github.com/MohitTilwani15/homebrew-update/releases/download/v#{version}/Homebew-Menubar-#{version}.zip",
      verified: "github.com/MohitTilwani15/homebrew-update/"
  name "Homebew Menubar"
  desc "Menu bar app that keeps Homebrew packages up to date"
  homepage "https://github.com/MohitTilwani15/homebrew-update"

  depends_on macos: ">= :ventura"

  app "Homebew Menubar.app"

  zap trash: [
    "~/Library/Application Support/Homebew Menubar",
    "~/Library/Caches/com.mohittilwani.homebew-menubar",
    "~/Library/HTTPStorages/com.mohittilwani.homebew-menubar",
    "~/Library/Preferences/com.mohittilwani.homebew-menubar.plist",
    "~/Library/Saved Application State/com.mohittilwani.homebew-menubar.savedState",
  ]
end
