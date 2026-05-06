cask "sprocket" do
  version "0.1.6"
  sha256 "6346a1e1889ac8e86e7a13b8422fceddeef1b3589ea939b9aec3f7b61ac63400"

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
