# Sprocket

![alt text](<marketing.png>)
**CI status, without the tabs.**
Sprocket is a tiny macOS menu bar app that watches GitHub Actions across every
repo you can see — personal, org, collaborator. One glyph reflects the worst
current state across every watched repo (failure → running → rate-limited →
success); click for the full list; get notified the moment something turns red.

- **Aggregate status** — one menu bar glyph reflects the worst current state across every watched repo.
- **Live polling** — ETag-aware. Repos with running jobs poll every 15 s. Battery-aware backoff.
- **Failure first** — notified on transitions to failure, timed_out, action_required. Coalesced bursts.
- **Menu bar or terminal** — the `sprocket` CLI shares Keychain with the app; drop it in tmux, your shell prompt, or a script.
- **Bring your own OAuth app** — your token never leaves your Mac. No shared rate-limit pool, no analytics.

> "I tab into GitHub fifty times a day to check if CI passed. Sprocket replaces
> that with a glance at the menu bar."

The popover ships Variation A: header with avatar and repo count, segmented
filter (All / Running / Failing / Recent), org switcher, run rows with status
dot · repo · workflow · title · branch/event chips · author avatar, and a
rate-limit footer that's always visible.

## Requirements

- macOS 26 (Tahoe) or newer
- Apple Silicon
- Swift 6.0 toolchain (Xcode 16+)

## Install

Download `Sprocket-<version>-macos.zip` from the
[latest GitHub release][releases], unzip it, and move `Sprocket.app` to
`/Applications`.

Or install with Homebrew:

```sh
brew tap MRL-00/Sprocket https://github.com/MRL-00/Sprocket
brew install --cask sprocket
```

[releases]: https://github.com/MRL-00/Sprocket/releases/latest

## Build

```sh
swift build                   # debug
swift build -c release        # release
swift test                    # SprocketKit tests (Swift Testing)
```

Build a runnable `Sprocket.app` bundle:

```sh
./Scripts/package_app.sh                       # release
VERSION=0.2.0 ./Scripts/package_app.sh         # release with bundle version
SPROCKET_SIGNING=adhoc ./Scripts/package_app.sh # ad-hoc codesign
open build/Sprocket.app
```

## Release

GitHub releases are created from version tags:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The release workflow builds `Sprocket.app`, archives it as
`Sprocket-0.2.0-macos.zip`, uploads the zip and checksum to GitHub Releases,
generates release notes, and commits the updated Homebrew cask checksum back to
`main`.

To update the cask by hand from a local artifact:

```sh
./Scripts/update_cask.sh 0.2.0 build/Sprocket-0.2.0-macos.zip
git add Casks/sprocket.rb
git commit -m "Update Homebrew cask to 0.2.0"
git push
```

For public distribution, replace ad-hoc signing in the release workflow with a
Developer ID certificate and notarization so users do not see Gatekeeper
warnings.

## Mock mode

```sh
swift run Sprocket --mock     # runs the app against MockData
swift run sprocket status     # CLI summary, also mock-backed
```

## Auth

Sprocket uses GitHub's [device flow][device-flow]. Open the app, follow the
3-step welcome, and paste the OAuth Client ID from your GitHub OAuth App
(make sure **Enable Device Flow** is checked). Tokens are stored in the
macOS Keychain under `nz.matt.sprocket.github.token`.

[device-flow]: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow

## Layout

- `Sources/SprocketKit/` — models, actors, mock data (no UI)
- `Sources/SprocketApp/` — the menu bar app target (module `Sprocket`)
- `Sources/SprocketCommandLine/` — the `sprocket` CLI (target `SprocketCLI`)
- `Tests/SprocketKitTests/` — Swift Testing suites
- `Scripts/package_app.sh` — wraps `swift build` output into `Sprocket.app`

## CLI (Coming Soon...)
