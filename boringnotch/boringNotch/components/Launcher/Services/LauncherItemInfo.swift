//
//  LauncherItemInfo.swift
//  boringNotch
//

import AppKit

/// Display helpers for launcher items: names, descriptions and icons.
/// Read-only: resolving a folder here never refreshes or saves its bookmark.
@MainActor
enum LauncherItemInfo {
    static let shortcutsBundleID = "com.apple.shortcuts"

    /// The custom label, or a name derived from the action.
    static func displayName(for item: LauncherItem) -> String {
        if let label = item.label, !label.isEmpty {
            return label
        }
        return derivedName(for: item.action)
    }

    static func derivedName(for action: LauncherAction) -> String {
        switch action {
        case .app(let bundleID):
            return appName(bundleID: bundleID) ?? bundleID
        case .folder(let bookmark, _):
            return folderURL(bookmark)?.lastPathComponent ?? "Folder"
        case .url(let url):
            return url.host() ?? url.absoluteString
        case .shortcut(let name):
            return name
        }
    }

    /// One-line description shown under the name in Settings.
    static func subtitle(for action: LauncherAction) -> String {
        switch action {
        case .app:
            return "App"
        case .folder(_, let appBundleID):
            return "Folder in \(appName(bundleID: appBundleID) ?? appBundleID)"
        case .url(let url):
            return url.absoluteString
        case .shortcut:
            return "Apple Shortcut"
        }
    }

    /// Icon for the item. URLs have no file icon and return nil; callers show a globe symbol.
    static func icon(for action: LauncherAction) -> NSImage? {
        switch action {
        case .app(let bundleID):
            return appIcon(bundleID: bundleID)
        case .folder(let bookmark, _):
            guard let url = folderURL(bookmark) else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .url:
            return nil
        case .shortcut:
            return appIcon(bundleID: shortcutsBundleID)
        }
    }

    static func appName(bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    static func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private static func folderURL(_ bookmark: Data) -> URL? {
        Bookmark(data: bookmark).resolve().url
    }
}
