cask "sprocket" do
  version "0.1.7"
  sha256 "5af43a92cf7d3421f1fb268f91ec6ab183c4313a184909c3019a0c5ec5bfe0fd"

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
