# MyNotch

MyNotch turns the MacBook notch into a small control center: music controls, calendar, a file
shelf and HUDs, plus an app launcher, clipboard history and window snapping.

It's a fork of [boring.notch](https://github.com/TheBoredTeam/boring.notch) by The Boring Team,
with these additions:

- **Launcher:** a notch tab of shortcuts to apps, folders, websites and Shortcuts. Group them into
  modes (e.g. "Developer" opens VS Code on a project, Claude and two Safari tabs) and run a whole
  mode with one click.
- **Clipboard history:** a notch tab with your recent copies (text, images, files), newest first.
  Click one to copy it back. Press ⇧⌘C to open it from anywhere. Copies from password managers and
  the Passwords app are never saved.
- **Window snapping:** drag a window by its title bar up into the notch, then drop it on
  **Left Half**, **Fill** or **Right Half**. A soft preview shows where it will go.
- **Smaller changes:** the notch opens faster on hover, reopens on the tab you closed it on, and
  stays closed while Mission Control is showing.

Requires macOS 14 or later. Built and tested on macOS 27 on a MacBook with a notch.

## Install

1. Download `MyNotch-<version>.dmg` (or the `.zip`) from [Releases](https://github.com/mustafa-ozkaya/MyNotch/releases).
2. Open it and drag **MyNotch** into **Applications**.
3. Allow it to open (see below), then launch it from Applications.

### Allowing MyNotch to open

MyNotch isn't signed with an Apple Developer ID or notarized by Apple, so the first time you open
it, macOS shows **"MyNotch" Not Opened: Apple could not verify "MyNotch" is free of malware…**
Click **Done**, not **Move to Trash** (that deletes the app). Done doesn't open MyNotch yet; pick one:

**System Settings:** go to **System Settings › Privacy & Security** and scroll all the way down,
past **Security**. Next to **"MyNotch" was blocked to protect your Mac**, click **Open Anyway**,
confirm with your password or Touch ID, and click **Open Anyway** again. (The message only shows for
a while after the blocked attempt; if it's gone, open MyNotch once more and click Done.)

**Terminal (always works):**

```bash
xattr -dr com.apple.quarantine /Applications/MyNotch.app
```

Then open MyNotch normally.

Repeat this after installing each new version.

## Permissions

MyNotch asks for permissions only when you turn on a feature that needs them:

| Permission | Used for |
|---|---|
| Accessibility | Window snapping, HUD replacement, and keeping the notch closed during Mission Control |
| Calendars, Reminders | The calendar in the notch |
| Automation (Spotify, Music) | Music controls |
| Camera | The mirror |

**After updating MyNotch, turn Accessibility back on.** Because the app isn't Developer ID signed,
macOS ties the permission to the exact build. If window snapping stops working after an update, go
to **System Settings › Privacy & Security › Accessibility**, remove MyNotch with **−**, then open
MyNotch's **Settings › Window Snapping** and turn snapping on again to re-grant it.

## Tips

- If macOS opens Mission Control when you drag something to the top of the screen, turn off
  **Drag windows to top of screen to enter Mission Control** in **System Settings › Desktop & Dock**.
- Window snapping works on the main notch display. Turn on **Show on all displays** to snap on
  other screens too.
- Set **Settings › General › Hover delay** to 0 for an instant notch.

## Building from source

Requires Xcode 27 or later.

```bash
git clone https://github.com/mustafa-ozkaya/MyNotch.git
cd MyNotch
open boringnotch/boringNotch.xcodeproj
```

In Xcode, set **Signing & Capabilities › Team** to your own team for the **boringNotch**,
**BoringNotchXPCHelper** and **MyNotchTests** targets, then build and run (⌘R). Keep using the same
team for every build, or macOS will forget the Accessibility permission each time you rebuild.

To build the release packages (ad-hoc signed, as published here):

```bash
scripts/build-release.sh   # writes dist/MyNotch-<version>.zip and .dmg
```

## Credits and license

MyNotch is based on [boring.notch](https://github.com/TheBoredTeam/boring.notch) by
[The Boring Team](https://github.com/TheBoredTeam) and its contributors: the notch itself, music
controls, calendar, shelf, HUDs and much more are their work. Icon by
[@maxtron95](https://github.com/maxtron95).

boring.notch builds on [MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter) and
[NotchDrop](https://github.com/Lakr233/NotchDrop). See [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES)
for all third-party licenses and attributions.

MyNotch is licensed under the [GNU General Public License v3.0](LICENSE), like boring.notch.
