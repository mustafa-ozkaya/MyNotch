# MyNotch: Launcher + Clipboard History + Window Snapping

## Goal
Turn a personal fork of boring.notch ("MyNotch") into a productivity notch. Add two new tabs. **Launcher** opens apps, project folders in a chosen app, URLs and Apple Shortcuts, either one at a time or as one-click **modes** (e.g. "Developer" opens VS Code with a project, Claude, and dev URLs in Safari). **Clipboard** keeps a persistent history of recent copies; click an item to copy it back. Then add **Window Snapping**: while dragging any app's window, moving the cursor into the notch opens a panel with layout targets (Fill, Left half, Right half); releasing over a target snaps the window there. Success means all three features work end-to-end in the sandboxed app, the unit tests pass, and the manual checklist below passes.

## Scope
- In:
  - Fork identity: rename to MyNotch, new bundle IDs, Sparkle update checks disabled.
  - Launcher tab: item types app, folder-with-app, URL, Apple Shortcut; modes (named lists of items); configured in a new "Launcher" Settings pane (add / remove / reorder / edit label).
  - Clipboard tab: 0.5 s polling monitor; text, image and file-reference entries; persisted history (default cap 50, configurable); click to copy (dedupe → move to top) then close the notch; per-item delete; skip concealed/transient items; size caps.
  - ⇧⌘C (existing `clipboardHistoryPanel` name) opens the notch on the Clipboard tab; rebindable in Settings.
  - Settings toggles "Show Launcher tab" / "Show Clipboard tab" (both default on; Clipboard off ⇒ monitoring stopped).
  - New Swift Testing unit-test target.
  - Window Snapping (built after Launcher and Clipboard): window-drag detection, snap panel in the notch with Fill / Left half / Right half, live preview overlay, frame applied via the XPC helper using Accessibility; works on every screen that has a MyNotch notch window; "Enable window snapping" toggle (default off) with Accessibility status in Settings.
- Out of scope (v1):
  - Auto-paste into the frontmost app (no synthetic ⌘V / Accessibility use).
  - Pinning, search, clear-all, app ignore list, pause toggle, time-based expiry.
  - Opening real Safari Tab Groups (no public API). Modes open URLs as tabs instead.
  - Forcing a new Safari window (would need an Apple Events entitlement).
  - Modes that quit apps, toggle on/off, or track an "active mode".
  - Drag-to-add launcher items onto the notch.
  - A Launcher-tab hotkey; per-mode hotkeys.
  - Rich-text or raw multi-type clipboard restore (text is stored and restored as plain text).
  - Contributing upstream.
  - Window Snapping: thirds, quarters, top/bottom halves, center (the `SnapLayout` enum is built so they can be added later); macOS native full screen (own Space); keyboard shortcuts for snapping; snapping by dragging to screen edges/corners (only the notch triggers it); restoring a window's previous size on drag-out; moving windows between Spaces; reading or changing the macOS tiling settings.

## Decisions
| Decision | Choice | Why / rejected alternatives |
|---|---|---|
| Base | Personal fork of boring.notch | Reuse the notch window, tabs, Settings, hotkeys. Upstream PR rejected: scope is personal. |
| Identity | Name "MyNotch", bundle `com.mustafaozkaya.mynotch`, XPC helper `com.mustafaozkaya.mynotch.XPCHelper` | Avoids clashing with an installed boring.notch (defaults, TCC, XPC name). Placeholder name; can change later. |
| Updates | Disable Sparkle automatic checks and hide/disable "Check for updates" | Upstream feed would replace the fork with official builds. |
| Placement | Two new tabs: Home \| Shelf \| Launcher \| Clipboard | Full width each; matches existing tab pattern. Combined tab / Home strip rejected as cramped. |
| Launcher item types | app, folder+app, URL, Apple Shortcut | Covers "open project in VS Code", "open Claude", dev URLs, and anything scriptable via Shortcuts. |
| Folder access | Security-scoped bookmark created from an `NSOpenPanel` pick in Settings | Required by the sandbox to hand a folder to another app; persists across relaunch. |
| Shortcut execution | `shortcuts://run-shortcut?name=<percent-encoded>` | Sandbox-safe. `/usr/bin/shortcuts` CLI rejected: unreliable from a sandboxed process. |
| Modes | Named ordered list of items, open-only, shown as large buttons above single items | No state to track or undo. Toggle/quit modes rejected for complexity and Apple Events needs. |
| Safari "dev group" | Mode contains URL items, opened via `NSWorkspace` → tabs in Safari's front window (new window only if none is open) | Tab Groups have no API; UI scripting is brittle and needs Accessibility. |
| Launcher failure | Warning badge plus tooltip reason on the button; remaining mode items still run; Settings flags broken items | Silent skip rejected: you'd never learn a folder moved. |
| Clipboard behavior | Copy back only; you press ⌘V | Auto-paste needs Accessibility and focus juggling. |
| Clipboard types | Plain text (rich text stored as plain text), images (PNG thumbnail plus full data), file URLs (paths) | "Everything raw" rejected: heavy, complex. |
| Retention | Most recent first, cap 50 (Settings, range 10–500), persisted in Application Support | In-memory rejected: history lost on restart. |
| Privacy | Skip items whose types include `org.nspasteboard.ConcealedType` or `org.nspasteboard.TransientType` (also `...AutoGeneratedType`); per-item delete | Password managers set these markers. Per-item delete is the escape hatch for leaked secrets. |
| Click item | Write to pasteboard, move to top (no duplicate), show "Copied" ~0.8 s, close notch | Keeping the notch open rejected. |
| Monitoring | Timer every 0.5 s comparing `NSPasteboard.general.changeCount` | macOS has no pasteboard-change notification. |
| Size limits | Skip text > 1 MB, images > 10 MB; previews truncated (text 2 lines / ~200 chars) | Bounds disk use and load time. |
| Hotkey | ⇧⌘C opens notch on Clipboard tab | Existing unused `KeyboardShortcuts.Name.clipboardHistoryPanel`. |
| Tests | New Swift Testing target for pure logic; build; manual checklist | Repo has no tests today. |
| Snap trigger | Cursor enters the notch region while a *window* (not content) is being dragged | Screen-edge triggers rejected: they collide with macOS tiling and Mission Control. |
| Snap layouts (v1) | Fill, Left half, Right half | Enough for v1; more layouts are a later enum addition. |
| "Fill" meaning | Window frame = the target screen's `visibleFrame` (menu bar and Dock stay visible) | Native full screen rejected: slow Space animation, and the window leaves the desktop. |
| Window control | Accessibility (`AXUIElement` position/size) inside the existing non-sandboxed `BoringNotchXPCHelper`; the sandboxed app asks it over XPC | AX can't control other apps from the sandbox. The helper already handles AX trust (`ensureAccessibilityAuthorization`). This is the only feature that uses Accessibility; the Clipboard "no Accessibility" decision is unchanged. |
| Window-drag detection | Global `leftMouseDown` → helper hit-tests the window under the cursor (title-bar band only); on `leftMouseDragged` the helper confirms the window's position actually changed | Pure mouse tracking rejected: any desktop drag or text selection would trigger the panel. |
| Hit-testing during drag | Computed from `NSEvent.mouseLocation` against zone rects (pure function), not SwiftUI hover | While another app's window is being dragged, MyNotch's views get no hover events. |
| Preview | Separate transparent, click-through overlay panel showing a rounded rect at the target frame | Gives clear feedback of where the window will land. |
| Multi-display | Panel appears in the notch of whichever screen the cursor is on; target frame is that screen's `visibleFrame`. Requires a notch window on that screen (other screens need "Show on all displays") | Creating extra notch windows just for snapping rejected for v1 complexity. |
| Enable toggle | "Enable window snapping", default off; turning on asks for Accessibility | Avoids an Accessibility prompt for users who never use the feature. |
| macOS tiling conflict | One-time tip in the Settings pane: turn off System Settings › Desktop & Dock › "Drag windows to top of screen to enter Mission Control" / edge tiling if they interfere; our frame is applied ~100 ms after mouse-up so it wins over late system adjustments | MyNotch can't change system settings. |

## Design

### Fork setup (files)
- `boringNotch.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER` → `com.mustafaozkaya.mynotch` (app) and `com.mustafaozkaya.mynotch.XPCHelper` (helper); `PRODUCT_NAME` / display name → `MyNotch`; `PRODUCT_MODULE_NAME = boringNotch` pinned so the Swift module name doesn't follow future renames. Keep target and scheme names unchanged to limit churn.
- `boringNotch/boringNotch/XPCHelperClient/XPCHelperClient.swift:8`: `serviceName` → new helper bundle ID. Update the sample comment in `BoringNotchXPCHelper/BoringNotchXPCHelperProtocol.swift`.
- `boringNotch/boringNotch/Info.plist`: remove `SUFeedURL`, set `SUEnableAutomaticChecks` = `NO`.
- `components/Settings/SoftwareUpdater.swift` and the About pane: hide or disable the "Check for updates" UI.
- `boringNotch.entitlements`: the mach-lookup names use `$(PRODUCT_BUNDLE_IDENTIFIER)` and update automatically. Verify nothing else hardcodes `theboringteam.boringnotch` (grep).

### Tabs
- `enums/generic.swift`: `NotchViews` gains `case launcher`, `case clipboard`.
- `components/Tabs/TabSelectionView.swift`: `tabs` becomes computed and filtered by `Defaults[.showLauncherTab]` / `Defaults[.showClipboardTab]`. Icons: `square.grid.2x2.fill` (Launcher), `doc.on.clipboard.fill` (Clipboard).
- `ContentView.swift:347`: route `.launcher` → `LauncherView()`, `.clipboard` → `ClipboardView()`.
- If a tab is turned off while it's selected, `BoringViewCoordinator.currentView` falls back to `.home`.
- `BoringHeader.swift`: the tab bar shows when Launcher or Clipboard is on; otherwise the original shelf rule applies (shelf enabled and non-empty, or "always show tabs"). Shelf tab hidden when the shelf is disabled.
- Project: `components/Launcher/` and `components/Clipboard/` (and later `components/WindowSnap/`) are folder-synchronized groups in the app target, so new files there need no `project.pbxproj` edits. For that reason the new Settings panes live in them (`components/Launcher/Settings/LauncherSettingsView.swift`, `components/Clipboard/Settings/ClipboardSettingsView.swift`, `components/WindowSnap/Settings/WindowSnapSettingsView.swift`) instead of `components/Settings/`.

### Defaults keys (add to `models/Constants.swift` alongside existing keys)
- `showLauncherTab: Bool = true`, `showClipboardTab: Bool = true`
- `clipboardHistoryLimit: Int = 50`
- `launcherConfig: LauncherConfig = .empty` (Codable, `Defaults.Serializable`)

### Launcher. New folder `components/Launcher/`
- `Models/LauncherItem.swift`
  ```swift
  struct LauncherItem: Codable, Identifiable, Hashable {
      let id: UUID
      var label: String?            // custom label; falls back to derived name
      var action: LauncherAction
  }
  enum LauncherAction: Codable, Hashable {
      case app(bundleID: String)
      case folder(bookmark: Data, appBundleID: String)   // security-scoped, app-scope bookmark
      case url(URL)
      case shortcut(name: String)
  }
  struct LauncherMode: Codable, Identifiable, Hashable {
      let id: UUID
      var name: String
      var symbol: String            // SF Symbol, default "bolt.fill"
      var items: [LauncherItem]
  }
  struct LauncherConfig: Codable, Hashable {
      var modes: [LauncherMode]
      var items: [LauncherItem]     // standalone items
      static let empty = LauncherConfig(modes: [], items: [])
  }
  ```
- `Services/LauncherService.swift` (`@MainActor`, singleton like other services):
  - `func run(_ item: LauncherItem) async -> LauncherResult` (`.success` / `.failure(LauncherError)`).
  - `func run(_ mode: LauncherMode) async -> [UUID: LauncherError]`: runs items sequentially; one failure doesn't stop the rest.
  - app: `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` → `openApplication(at:configuration:)` with `activates = true` (launches or focuses).
  - folder: resolve bookmark (`.withSecurityScope`), `startAccessingSecurityScopedResource`, `NSWorkspace.shared.open([folder], withApplicationAt: appURL, configuration:)`, stop accessing afterwards. If `bookmarkDataIsStale`, try to refresh the bookmark and save it back to config; if resolving fails, return `.folderUnavailable`.
  - url: `NSWorkspace.shared.open(url)`. Several URL items in a mode just open one after another; Safari adds them as tabs.
  - shortcut: open `shortcuts://run-shortcut?name=<encoded>`, encoded with `.urlQueryAllowed` minus `& = + # ?` (plain `.urlQueryAllowed` leaves those unescaped and would cut names like "A&B").
  - Folder bookmarks follow renames and moves, including into the Trash; a folder that no longer exists or sits in `.Trash` counts as `.folderUnavailable`.
  - `LauncherError`: `.appNotInstalled(bundleID)`, `.folderUnavailable`, `.openFailed(String)`. Each has a user-facing `message` for tooltips.
  - `func validate(_ item:) -> LauncherError?`: checks the app is installed and the bookmark resolves, without opening anything. Used for badges in Settings and the tab. A missing Shortcut can't be detected beforehand, so it isn't validated.
- `ViewModels/LauncherViewModel.swift`: `@MainActor final class ... : ObservableObject` holding config (from Defaults), `errors: [UUID: LauncherError]` (last-run plus validation), `run` methods.
- `Views/LauncherView.swift`: modes row (large capsule buttons: symbol + name) above a grid of item buttons (app icon via `NSWorkspace.icon(forFile:)`, folder icon with small app badge, globe for URL, Shortcuts icon). Failed items get an `exclamationmark.triangle.fill` badge with `.help(error.message)`. Clicking a single item or mode closes the notch after it runs (same `vm.close()` the shelf uses) if everything opened; if anything failed the notch stays open so the badge is visible. Names and icons are cached in `LauncherViewModel` (rebuilt when the config changes and when the tab appears). The empty state's "Open Launcher Settings" uses `SettingsWindowController.showWindow(selecting:)`, backed by a shared `SettingsNavigation` selection.
- Settings: new `NavigationLink(value: "Launcher")` in `components/Settings/SettingsView.swift`, with the pane in `components/Settings/LauncherSettingsView.swift`:
  - Sections "Modes" and "Items". Each supports add (menu: App… / Folder in App… / URL… / Apple Shortcut…), remove, reorder (up/down buttons; `.onMove` drag isn't reliable inside a macOS `Form`), and editing the label. Each mode is a disclosure row with its name, SF Symbol, and its own item list.
  - App picker: `NSOpenPanel` limited to `.application` in `/Applications`; store `Bundle(url:)?.bundleIdentifier`.
  - Folder picker: `NSOpenPanel` (`canChooseDirectories`), then the app picker; create the bookmark with `.withSecurityScope`.
  - URL: text field validated as a `URL` with a scheme. Shortcut: text field (exact name).
  - Broken items show the warning badge plus a "Re-pick…" button.
  - Toggle "Show Launcher tab".

### Clipboard. New folder `components/Clipboard/`
- `Models/ClipboardEntry.swift`
  ```swift
  struct ClipboardEntry: Codable, Identifiable, Hashable {
      let id: UUID
      var kind: Kind            // .text, .image, .files
      var text: String?         // .text
      var imageFile: String?    // filename in Clipboard/images/ (PNG)
      var thumbFile: String?    // filename of thumbnail PNG (max 160 px)
      var filePaths: [String]?  // .files
      var contentHash: String   // SHA-256 of normalized content (text / PNG bytes / joined paths)
      var sourceAppBundleID: String?
      var date: Date
  }
  ```
- `Services/ClipboardStore.swift`: pure logic with no AppKit timer, so it's unit-testable.
  - `init(directory: URL, limit: Int)`. Storage is `<directory>/history.json` plus `<directory>/images/`. App directory: `Application Support/<bundleID>/Clipboard/` (follow the `ShelfPersistenceService.swift:23` pattern).
  - `func insert(_ candidate: ClipboardCandidate) -> ClipboardEntry?`: applies size caps (returns nil if exceeded), dedupes by `contentHash` (an existing entry moves to the top with a new date), prepends, enforces `limit` (evicted entries' image files are deleted), saves.
  - `func delete(id:)` (also removes image files), `func setLimit(_:)` (trims immediately), `func load()`, `func save()` (atomic write, done off the main thread).
  - Corrupt or missing `history.json` → start empty and rename the bad file to `history.corrupt.json`.
  - As built: `ClipboardCandidate { content: .text / .image(png:thumbnailPNG:) / .files([String]), sourceAppBundleID, date }`; the monitor makes the PNG and thumbnail, so the store needs no AppKit. Hash = SHA-256 of kind + content. Empty/whitespace text is rejected too. All disk writes and deletes run in order on one background queue; `flush()` waits for them (tests, app quit). Image files no entry refers to are deleted on load.
- `Services/ClipboardMonitor.swift` (`@MainActor`):
  - A `Task` loop with `try await Task.sleep(for: .milliseconds(500))` (no Combine). Reads `NSPasteboard.general.changeCount` and only reads contents when it changed.
  - Ignores a change if: the types include concealed/transient/auto-generated markers; or `changeCount == lastSelfWriteChangeCount` (our own copy-back, so no re-insert loop).
  - Picks one kind in priority order: file URLs (`readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`) → string (`.string`; RTF/HTML fall back to their plain string) → image (`.png` / `.tiff` / `NSImage`, converted to PNG off the main thread with ImageIO, plus a 160 px thumbnail). **Changed from the original file → image → text:** Word/Excel/Pages/Keynote put a picture of the selection next to copied text, so image-first would save text copies as images. If the text is empty (e.g. a browser's "Copy Image" adds an `<img>` HTML tag), the image is used instead. Builds a `ClipboardCandidate` and calls `store.insert`. Pure rules live in `ClipboardContentRules` (`shouldIgnore(types:)`, `readOrder(types:)`, `pngAndThumbnail`).
  - `accessBehavior` exists from macOS 15.4; on older systems access is treated as allowed. Monitoring skips whatever was on the clipboard when it starts. Copy-back uses `store.moveToTop(id:)` rather than re-inserting.
  - `sourceAppBundleID` = `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` at detection time (shown as a small app icon).
  - `start()` / `stop()`. Started at launch if `showClipboardTab`; observes the toggle (`Defaults.updates(.showClipboardTab)` async sequence) to start or stop.
  - Pasteboard privacy: before reading, check `NSPasteboard.general.accessBehavior`. If `.alwaysDeny`, don't read; publish `accessDenied = true`.
- `Services/ClipboardActions.swift`: `copyBack(_ entry:)` writes text / PNG image / file URLs to `NSPasteboard.general` (`clearContents` then `writeObjects`), records `lastSelfWriteChangeCount`, and calls `store.insert` so the entry moves to the top.
- `ViewModels/ClipboardViewModel.swift`: publishes `entries`, `accessDenied`, and `copiedEntryID` (for the transient "Copied" state).
- `Views/ClipboardView.swift`: vertical `ScrollView` + `LazyVStack` of rows: kind icon / thumbnail, a 2-line truncated preview (files: first file name plus "+N more"), relative time, source app icon. Hover shows a trash button; the context menu has "Copy" and "Delete". Clicking copies, shows a checkmark and "Copied" for ~0.8 s, then closes the notch.
- Settings: Clipboard section in the new Launcher pane or its own `NavigationLink(value: "Clipboard")` pane (`ClipboardSettingsView.swift`): "Show Clipboard tab" toggle, history-limit stepper (10–500), and the `KeyboardShortcuts.Recorder("Open Clipboard:", name: .clipboardHistoryPanel)`.

### Hotkey
- `boringNotchApp.swift` (next to `toggleNotchOpen` at ~line 368): `KeyboardShortcuts.onKeyDown(for: .clipboardHistoryPanel)` sets `coordinator.currentView = .clipboard` and opens the notch on the active screen, reusing the same open path as `toggleNotchOpen`. Does nothing if `showClipboardTab` is false.

### Window Snapping. New folder `components/WindowSnap/`
- `Models/SnapLayout.swift`
  ```swift
  enum SnapLayout: String, CaseIterable, Codable, Identifiable {
      case fill, leftHalf, rightHalf
      var id: String { rawValue }
      var label: String      // "Fill", "Left Half", "Right Half"
      var symbol: String     // e.g. "rectangle.fill", "rectangle.lefthalf.filled", "rectangle.righthalf.filled"
      /// Target frame in Cocoa coordinates (bottom-left origin) for a screen's visibleFrame.
      func frame(in visibleFrame: CGRect) -> CGRect
  }
  ```
  - Halves use integral widths (`floor`); the right half takes the remainder so the two halves exactly cover `visibleFrame`.
- `Models/SnapGeometry.swift` (pure, unit-tested):
  - `func axRect(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect`: AX uses a top-left origin relative to the primary screen; `y = primaryScreenHeight - rect.maxY`.
  - `func zone(at point: CGPoint, zones: [SnapLayout: CGRect]) -> SnapLayout?`: which target the cursor is over (screen coordinates).
  - `func isWindowDrag(startFrame: CGRect, currentFrame: CGRect) -> Bool`: window origin moved ≥ 4 pt and size unchanged (a size change means a resize drag, not a move).
- XPC helper additions (`BoringNotchXPCHelperProtocol` in both the helper and `XPCHelperClient/` copies, implementation in `BoringNotchXPCHelper.swift`):
  - `func windowUnderPoint(_ x: Double, _ y: Double, with reply: @escaping (NSNumber?, NSValue?) -> Void)`: `AXUIElementCopyElementAtPosition` on the system-wide element → walk up to the `kAXWindowRole` element. Reply `nil` unless the point lies in the window's title-bar band (top 40 pt of its frame, or inside its `AXToolbar`) and the window isn't MyNotch's own and isn't in native full screen (`AXFullScreen`). The helper keeps the `AXUIElement` in a dictionary under an integer token and replies with the token plus its current frame (AX coordinates).
  - `func windowFrame(_ token: NSNumber, with reply: @escaping (NSValue?) -> Void)`.
  - `func setWindowFrame(_ token: NSNumber, _ frame: NSValue, with reply: @escaping (Bool) -> Void)`: set `kAXPositionAttribute`, then `kAXSizeAttribute`, then position again (some apps clamp size against the old position). Reply `true` if the final frame is within 2 pt of the target.
  - `func releaseWindow(_ token: NSNumber)`: drop the stored element.
  - `XPCHelperClient` gets matching `async` wrappers, the same pattern as the brightness calls.
- `Services/WindowDragDetector.swift` (`@MainActor`, separate from the shelf's `DragDetector`; that one only fires for pasteboard content, so the two don't overlap):
  - Global monitors for `leftMouseDown` / `leftMouseDragged` / `leftMouseUp` (no Combine).
  - mouseDown → ask the helper `windowUnderPoint`; if a token comes back, remember token + start frame. Otherwise ignore the gesture.
  - First drag events → query `windowFrame` (throttled to ~every 50 ms until confirmed); once `isWindowDrag` is true, the gesture is a window drag.
  - While confirmed: for each screen with a notch window, check if `NSEvent.mouseLocation` is inside that screen's notch region (same rect as `setupDragDetectorForScreen` in `boringNotchApp.swift`). Enter → `onEnterNotch(screen)`; leave → `onExitNotch`; every move → `onMove(point)`.
  - mouseUp → `onDrop(point)` if inside the notch, else `onCancel`; always `releaseWindow`.
- `ViewModels/WindowSnapViewModel.swift` (`@MainActor final class: ObservableObject`): `isActive`, `hoveredLayout: SnapLayout?`, `targetScreen`, `zones: [SnapLayout: CGRect]` (screen coordinates, written by the panel view via a `GeometryReader` converted with the notch window's `convertToScreen`). On drop with a `hoveredLayout`, it computes `layout.frame(in: screen.visibleFrame)` → `axRect` and, after ~100 ms, calls `setWindowFrame`. On failure it shows a short "Couldn't resize this window" message in the panel before closing.
- `Views/SnapPanelView.swift`: a row of three large targets, each a mini screen drawing of the layout plus a label; the hovered target is highlighted. Shown in the open notch in place of the tab content.
- `Views/SnapPreviewWindow.swift`: borderless `NSPanel`, `ignoresMouseEvents = true`, transparent, level just below the notch window, `collectionBehavior` `[.canJoinAllSpaces, .fullScreenAuxiliary]`. Shows a rounded, translucent accent-colored rect at `hoveredLayout`'s frame on the target screen; hidden when nothing is hovered.
- Notch routing:
  - `enums/generic.swift`: `NotchViews` gains `case windowSnap`. It's **not** added to `TabSelectionView.tabs`.
  - `ContentView.swift:347`: `.windowSnap` → `SnapPanelView()`; the tab bar is hidden while it's shown.
  - On enter: remember the previous `currentView`, set `.windowSnap`, open the notch on that screen (same `viewModels[uuid]` / `vm` lookup as `handleDragEntersNotchRegion`). On exit or drop: close the notch and restore the previous `currentView`.
- Wiring in `boringNotchApp.swift`: create one `WindowDragDetector` alongside `setupDragDetectors()` and rebuild its notch regions on the same screen-change notifications. Start it only when `Defaults[.windowSnappingEnabled]` is true and Accessibility is granted (`accessibilityAuthorizationChanged` notification + `Defaults.updates(.windowSnappingEnabled)`); stop otherwise.
- Defaults key (in `models/Constants.swift`): `windowSnappingEnabled: Bool = false`.
- Settings: new `NavigationLink(value: "Window Snapping")` in `SettingsView.swift`, pane `components/Settings/WindowSnapSettingsView.swift`:
  - Toggle "Enable window snapping". Turning it on calls `ensureAccessibilityAuthorization(promptIfNeeded: true)`.
  - Status row: "Accessibility: Granted / Not granted" with an "Open Accessibility Settings" button (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).
  - Tip text: "If macOS also tiles or opens Mission Control when you drag to the top, turn that off in System Settings › Desktop & Dock."
  - Hint when "Show on all displays" is off: "Snapping works on the main notch display only. Turn on Show on all displays to snap on other screens."

### Tests target
- New macOS Unit Testing Bundle target `MyNotchTests` (Swift Testing, `import Testing`, `@testable import boringNotch`), host app = main target. Add it to the main scheme's test action.

## Edge cases
- Notch tab turned off while it's selected → `currentView` resets to `.home`.
- First clipboard read triggers the macOS pasteboard access alert → if the user denies it (`accessBehavior == .alwaysDeny`), the Clipboard tab shows an empty state: "MyNotch can't read the clipboard. Allow it in System Settings › Privacy & Security › Paste from Other Apps." with an "Open Settings" button. Copy-back still works.
- Empty history → "Nothing copied yet. Copy something and it'll show up here."
- Empty launcher config → "No shortcuts yet" plus an "Open Launcher Settings" button.
- Concealed/transient copies (1Password, Keychain) → never recorded.
- Apple's Passwords app sets **no** nspasteboard.org marker (found in manual test C2; it only clears the clipboard later). Copies made while the frontmost app's bundle ID starts with `com.apple.Passwords` or `com.apple.keychainaccess` are never recorded (`ClipboardContentRules.ignoredSourceAppPrefixes`).
- Copying the same content again → existing entry moves to the top, no duplicate.
- Our own copy-back → not re-inserted by the monitor (`lastSelfWriteChangeCount`).
- Text > 1 MB or image > 10 MB → skipped silently (logged).
- Lowering the history limit → oldest entries trimmed immediately, including their image files.
- `history.json` corrupt → start empty, keep the corrupt file for inspection.
- Copied files later deleted or moved → copy-back still writes the paths; row shows the paths unchanged (no existence check in v1).
- Launcher app uninstalled → `.appNotInstalled`: warning badge on the tab button and in Settings.
- Launcher folder moved or deleted → stale bookmark: refresh if possible, otherwise `.folderUnavailable`, badge, and "Re-pick…" in Settings.
- Shortcut name doesn't exist → Shortcuts.app shows its own error; can't be detected by MyNotch (documented limitation).
- One item in a mode fails → the rest still run; only the failed item is badged (in Settings and in the tab, the mode button shows a badge with a combined tooltip).
- Mode with zero items → button disabled.
- URL item with no scheme → rejected in Settings ("Enter a full URL, e.g. https://…").
- Rapid clicks on a mode → ignore re-entry while a run is in progress.
- Window Snapping, Accessibility not granted (or revoked later) → detector stopped; Settings shows "Not granted" plus the button; the toggle stays on and snapping resumes as soon as access is granted.
- Dragging files, text, or a desktop selection → not a window drag (no title-bar hit), no snap panel; the shelf behaves as before.
- Resizing a window by its edge → size changes, so `isWindowDrag` is false and no panel appears.
- Dragging the window back out of the notch before releasing → panel closes, preview hides, and the window stays wherever it's dropped.
- Releasing in the notch but not over a target (gap between targets) → cancel, nothing changes.
- Window with a minimum/maximum size or fixed size (e.g. System Settings, some dialogs) → the app clamps; if the final frame is off by more than 2 pt, show "Couldn't resize this window" briefly. No retry.
- Window in native full screen → `windowUnderPoint` returns nil; no panel.
- MyNotch's own windows (Settings, notch) → excluded by PID.
- Cursor enters a screen without a notch window (Show on all displays off) → no panel on that screen.
- Notch region on a Mac without a physical notch → same top-center region as the shelf drag detection.
- Helper crashes or the XPC connection drops mid-drag → treat as cancel; `XPCHelperClient` reconnects on the next call.
- macOS tiling also reacts to the drop → our delayed `setWindowFrame` usually wins; documented tip in Settings.
- Display arrangement changes → notch regions rebuilt on the existing screen-change notifications.

## Implementation steps
1. **Fork identity.** Change bundle IDs, product name and XPC `serviceName`; disable Sparkle (Info.plist plus UI). Grep for leftover `theboringteam.boringnotch`. *Check:* `BuildProject` succeeds; app launches as "MyNotch"; brightness HUD still works (XPC helper reachable); no update check in Console logs.
2. **Test target.** Add `MyNotchTests` with one placeholder `@Test`. *Check:* `RunAllTests` passes.
3. **Tab plumbing.** Add the `NotchViews` cases, Defaults toggles, filtered `tabs`, `ContentView` routing with placeholder views, and the fallback to `.home`. *Check:* build; four tabs visible; toggles hide them.
4. **Launcher models and service.** `LauncherItem/Action/Mode/Config`, `LauncherService`, `validate`. *Check:* tests for Codable round-trip of every `LauncherAction` case, Shortcut URL percent-encoding (name with spaces/unicode), and `validate` returning `.appNotInstalled` for a fake bundle ID.
5. **Launcher Settings pane.** Pickers, bookmark creation, reorder, labels, broken-item badges. *Check:* build; add VS Code + folder, Claude, a URL and a Shortcut; relaunch the app; config persists and the folder bookmark still resolves.
6. **Launcher tab UI.** Modes row, item grid, badges, close-on-run. *Check:* manual checklist items L1–L5.
7. **Clipboard store.** `ClipboardEntry`, `ClipboardCandidate`, `ClipboardStore`. *Check:* tests (see Verification) pass.
8. **Clipboard monitor and actions.** Polling loop, marker filtering, kind detection, self-write suppression, access-behavior check, start/stop with the toggle. *Check:* tests for the marker filter and kind priority (by injecting pasteboard type lists); manual C1–C4.
9. **Clipboard tab UI and Settings.** Rows, hover delete, context menu, "Copied" feedback, close notch, empty and denied states, limit stepper, toggle. *Check:* manual C5–C9.
10. **Hotkey.** Wire `clipboardHistoryPanel` and add its Recorder in Settings. *Check:* manual H1–H2.
11. **Cleanup.** Update the `TipStore` "Clipboard Manager" tip copy if it no longer fits; add new strings to `Localizable.xcstrings` (English only). *Check:* build with no new warnings; all tests pass.
12. **Snap models.** `SnapLayout`, `SnapGeometry`. *Check:* unit tests (see Verification) pass.
13. **Helper window API.** New XPC protocol methods (both copies), helper implementation, `XPCHelperClient` async wrappers. *Check:* build; temporary debug call snaps the frontmost window to the left half (removed after).
14. **Window drag detection.** `WindowDragDetector`, wiring in `boringNotchApp.swift`, the `windowSnappingEnabled` key, start/stop on toggle and Accessibility changes. *Check:* manual W1, W6, W7 (logged enter/exit/drop events).
15. **Snap panel and preview.** `NotchViews.windowSnap`, `SnapPanelView`, `SnapPreviewWindow`, `WindowSnapViewModel`, open/close and view restore. *Check:* manual W2–W5, W8.
16. **Settings pane.** `WindowSnapSettingsView` with toggle, Accessibility status, tips. *Check:* manual W9–W10.
17. **Cleanup.** New strings in `Localizable.xcstrings`. *Check:* build with no new warnings; all tests pass.

## Verification
- **Unit tests (`MyNotchTests`, Swift Testing), run with `RunAllTests`:**
  - `ClipboardStore`: insert prepends; duplicate hash moves to top without growing the count; cap evicts the oldest and deletes its image files; `setLimit` trims; text > 1 MB and image > 10 MB rejected; `delete` removes the entry and its files; save→new store→load round-trip equals the original; corrupt JSON → empty store plus `history.corrupt.json` exists. Each test uses a temp directory.
  - Monitor filtering (pure function `shouldIgnore(types:)`): concealed, transient and auto-generated markers ignored; plain `.string` accepted. Kind priority function: file URL > image > string.
  - Launcher: Codable round-trip for `LauncherConfig` with all action types; `shortcutURL(name:)` encodes `"Dev Mode ü"` correctly; `validate(.app(bundleID: "invalid.example.none"))` → `.appNotInstalled`.
  - Window Snapping: `SnapLayout.frame(in:)` for each layout on a sample `visibleFrame` (with Dock offset and odd width, e.g. 1511 pt): halves have no gap or overlap and together equal the frame, Fill equals the frame; `axRect(fromCocoa:)` for the primary screen and for a secondary screen above/below it; `zone(at:)` inside each zone, in a gap, outside all; `isWindowDrag` true for a moved window, false for a resize and for movement < 4 pt.
- **Build:** `BuildProject` on the main scheme with zero errors.
- **Manual end-to-end checklist** (run the app via `RunProject`, take screenshots of the open notch):
  - L1 Clicking "Developer" mode (VS Code + `~/code/<project>`, Claude.app, 2 Safari URLs) opens VS Code on that folder, launches/focuses Claude, and adds 2 tabs in Safari.
  - L2 Single app item opens or focuses the app; notch closes.
  - L3 Rename the project folder → the item still opens it (bookmarks follow renames). Delete it or move it to the Trash → item shows the warning badge with tooltip "Folder not found"; the rest of the mode still opens.
  - L4 Shortcut item runs the named Shortcut.
  - L5 Relaunch the app → launcher config and folder access still work.
  - C1 First run: macOS pasteboard alert appears; after "Always Allow", copied text appears in the Clipboard tab within ~1 s.
  - C2 Copy a password from 1Password/Passwords → not recorded.
  - C3 Copy an image (screenshot to clipboard) → thumbnail row; copy a file in Finder → file row.
  - C4 Copy the same text twice → one row, moved to top.
  - C5 Click a row → "Copied" feedback, notch closes, ⌘V in TextEdit pastes it; the row is now at the top and not duplicated.
  - C6 Hover → delete removes the row; it stays gone after relaunch.
  - C7 Set the limit to 10 with 15 entries → 10 remain.
  - C8 Turn off "Show Clipboard tab" → tab hidden and new copies not recorded; turning it back on resumes recording.
  - C9 Deny pasteboard access in System Settings → denied empty state with an "Open Settings" button.
  - H1 ⇧⌘C opens the notch on the Clipboard tab. H2 Rebind in Settings → the new combo works and the old one doesn't.
  - W1 With snapping enabled and Accessibility granted, drag a Safari window by its title bar into the notch → the notch opens with Fill / Left Half / Right Half.
  - W2 Hover each target → the preview rect appears at the right place; menu bar and Dock area are never covered.
  - W3 Release over Left Half → Safari fills exactly the left half of the visible area; repeat for Right Half and Fill.
  - W4 Drag into the notch and back out, then release → panel closes, window stays where dropped, no resize.
  - W5 Repeat W3 with VS Code, Finder and Claude (different app frameworks).
  - W6 Drag a file from Finder to the notch → shelf opens as before, no snap panel.
  - W7 Select text by dragging inside a window, and resize a window by its edge → no snap panel.
  - W8 With an external display and "Show on all displays" on, snap a window on the external screen → it fills that screen's visible area.
  - W9 Fresh install: toggle "Enable window snapping" → Accessibility prompt; before granting, status shows "Not granted" and nothing happens on drag; after granting, W1 works without restarting.
  - W10 Toggle off → dragging into the notch no longer shows the panel.

## Open questions
- Final app name and bundle ID. "MyNotch" / `com.mustafaozkaya.mynotch` is a placeholder (owner: Mustafa; decide before step 1 ideally, since renaming later resets defaults and permissions).
- ~~Whether reading `changeCount` alone triggers the pasteboard privacy alert.~~ Resolved in step 8 (2026-10-25, macOS 27): no alert appeared at all, neither at launch nor when MyNotch read copied content. Manual check C1's "alert appears" part doesn't apply on this system; C9 (deny in System Settings) still applies if MyNotch shows up in that pane.
- Whether Accessibility trust granted to MyNotch covers AX calls made from the bundled XPC helper (TCC usually attributes them to the responsible app). Confirm in step 13; if not, the helper may need to appear as its own entry in Accessibility settings (owner: implementer).
- Whether macOS's own top-edge drag behavior (tiling / Mission Control) fires reliably when releasing at the notch, and whether the 100 ms delay is enough. Confirm in step 15 (owner: implementer).
- ~~Upstream merge strategy.~~ Resolved 2026-10-25: MyNotch is a standalone repo with no upstream link or history (boring.notch's `.git` is backed up outside the repo at `../MyNotch-boringnotch-upstream-git-backup`). Upstream fixes, if ever wanted, are copied by hand. GPL-3.0 `LICENSE` kept.
