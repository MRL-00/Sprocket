cask "sprocket" do
  version "0.2.1"
  sha256 "522d02b49de4d95f2279c396326d88e1a78ba28bab1ed75637abee5055ea8052"

  url "https://github.com/MRL-00/Sprocket/releases/download/v#{version}/Sprocket-#{version}-macos.zip"
  name "Sprocket"
  desc "Tiny macOS menu bar app for GitHub Actions status"
  homepage "https://github.com/MRL-00/Sprocket"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Sprocket.app"

  zap trash: [
    "~/Library/Application Support/Sprocket",
    "~/Library/Preferences/nz.matt.sprocket.plist",
  ]
end
