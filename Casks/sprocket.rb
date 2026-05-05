cask "sprocket" do
  version "0.1.0"
  sha256 "26cf5d777f26a890a337313a692131227b408323b5b85686779e2c54c6c3d332"

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
