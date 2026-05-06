cask "sprocket" do
  version "0.1.2"
  sha256 "c72e615ca5d00a9c75afe710fe423d4e08bfc6aa8ef94e189d8a5ed7ab7e679b"

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
