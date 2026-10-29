# Maintenance

What to check when a new macOS (or Xcode) comes out, and how to ship a fix.

## When to do it

- **June**, when Apple releases the first beta of the next macOS at WWDC: test early so a fix is
  ready by the public release in September.
- **Each macOS point release** (x.1, x.2, …) and each new Xcode: a quick build and smoke test.
- **When a new MacBook comes out**: check the notch size and position.

## What tends to break

| Area | Code | Why |
|---|---|---|
| Music "Now Playing" | `mediaremote-adapter/`, `MusicManager` | Private MediaRemote framework; Apple already broke it once in macOS 15.4. |
| Lock screen notch | `BoringNotchSkyLightWindow.swift` | Private SkyLight window API. |
| Mission Control block | `BoringNotchXPCHelper+MissionControl.swift` | Undocumented signal: an `mc` child in the Dock's Accessibility tree. |
| Window snapping | `BoringNotchXPCHelper+Windows.swift`, `components/WindowSnap/` | Accessibility behavior, title-bar and toolbar roles, how apps clamp window sizes. |
| Notch geometry | `snapTriggerRect` in `boringNotchApp.swift`, `sizing/matters.swift` | `safeAreaInsets` / `auxiliaryTopLeftArea` values on new Macs. |
| Clipboard | `components/Clipboard/Services/` | Pasteboard privacy rules (macOS has been adding prompts). |
| Building | whole project | Each Xcode tightens Swift concurrency rules; the existing Swift 6 warnings may become errors. |

## Checklist

1. Build and run the tests: `xcodebuild test -scheme boringNotch` in `boringnotch/` (or ⌘U in Xcode).
2. Run the manual checks in [SPEC.md](SPEC.md#verification): **L1–L5** (Launcher), **C1–C9**
   (Clipboard), **H1–H2** (shortcut), **W1–W10** (window snapping).
3. Check the inherited features: music controls and visualizer, calendar, shelf (drag a file in),
   HUDs (volume, brightness), lock screen notch.
4. Open Mission Control and hover the notch: it must stay closed. If it opens, check the
   `MissionControl` log (`log stream --level debug --predicate 'subsystem == "com.mustafaozkaya.mynotch"'`)
   for what the Dock reports now.
5. Look at [boring.notch's releases and issues](https://github.com/TheBoredTeam/boring.notch) for
   the same macOS version. Their fixes to shared code (music, HUDs, lock screen) can be copied by hand.

## Shipping a fix

1. Bump `MARKETING_VERSION` (e.g. 1.0.1) and `CURRENT_PROJECT_VERSION` for the app and helper
   targets in the Xcode project.
2. Build the packages: `scripts/build-release.sh` (writes `dist/MyNotch-<version>.zip` and `.dmg`).
3. **Launch the built app before publishing.** `codesign --verify` passing doesn't mean it starts:
   v1.0.0's first build died at launch on library validation.
4. Commit, push, and publish:
   `gh release create v<version> dist/MyNotch-<version>.dmg dist/MyNotch-<version>.zip`
5. In the release notes, remind users to clear the quarantine flag and re-grant Accessibility after
   updating (ad-hoc builds lose the permission on every update).
