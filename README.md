# Sprocket

A macOS 26 (Tahoe) menu bar app for GitHub Actions. The 8-tooth gear in the
menu bar shows aggregate state across every repo you watch (failure → running →
rate-limited → success), and the popover gives a Variation A layout: header
with avatar and repo count, segmented filter (All / Running / Failing /
Recent), org switcher, run rows with status dot · repo · workflow · title ·
branch/event chips · author avatar, and a rate-limit footer that's always
visible.

## Requirements

- macOS 26 (Tahoe) or newer
- Apple Silicon
- Swift 6.0 toolchain (Xcode 16+)

## Build

```sh
swift build                   # debug
swift build -c release        # release
swift test                    # SprocketKit tests (Swift Testing)
```

Build a runnable `Sprocket.app` bundle:

```sh
./Scripts/package_app.sh                       # release
SPROCKET_SIGNING=adhoc ./Scripts/package_app.sh # ad-hoc codesign
open build/Sprocket.app
```

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
- `design/` — design bundle reference (HTML / JSX)

## CLI

```
sprocket status        Print the same summary the popover shows
sprocket list          Print recent runs across watched repos
sprocket watch         Long-run polling, prints state transitions
sprocket auth status   Show signed-in user
sprocket auth login    Run device flow
sprocket auth logout   Clear credentials
```
