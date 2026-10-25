//
//  LauncherPickers.swift
//  boringNotch
//

import AppKit
import UniformTypeIdentifiers

/// Open panels used by the Launcher Settings pane.
@MainActor
enum LauncherPickers {
    /// Asks for an app and returns its bundle ID.
    static func pickApp(message: String = "Choose an app to add to the Launcher.") -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose App"
        panel.message = message
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            NSLog("❌ Launcher: \(url.path) has no bundle identifier")
            return nil
        }
        return bundleID
    }

    /// Asks for a folder and returns a security-scoped bookmark for it.
    static func pickFolderBookmark() -> Data? {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.message = "Choose a folder to open from the Launcher."
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try? Bookmark(url: url).data
    }

    /// Folder first, then the app to open it with.
    static func pickFolderAction() -> LauncherAction? {
        guard let bookmark = pickFolderBookmark() else { return nil }
        guard let appBundleID = pickApp(message: "Choose the app to open this folder with.") else { return nil }
        return .folder(bookmark: bookmark, appBundleID: appBundleID)
    }

    /// Parses a URL typed in Settings. Requires `scheme://` (or `mailto:`).
    /// Plain `URL(string:)` would accept "localhost:3000" or "example.com" as having a scheme.
    nonisolated static func parseURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return nil }
        let hasAuthority = trimmed.lowercased().hasPrefix(scheme + "://") && trimmed.count > scheme.count + 3
        guard hasAuthority || scheme == "mailto" else { return nil }
        return url
    }
}
