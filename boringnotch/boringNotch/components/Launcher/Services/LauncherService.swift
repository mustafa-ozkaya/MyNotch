//
//  LauncherService.swift
//  boringNotch
//

import AppKit
import Defaults

enum LauncherError: Error, Hashable {
    case appNotInstalled(bundleID: String)
    case folderUnavailable
    case openFailed(String)

    /// User-facing text for tooltips and Settings.
    var message: String {
        switch self {
        case .appNotInstalled(let bundleID):
            return "App not installed (\(bundleID))"
        case .folderUnavailable:
            return "Folder not found"
        case .openFailed(let reason):
            return "Couldn't open: \(reason)"
        }
    }
}

enum LauncherResult: Hashable {
    case success
    case failure(LauncherError)
}

@MainActor
final class LauncherService {
    static let shared = LauncherService()

    private let workspace = NSWorkspace.shared

    private init() {}

    // MARK: - Running

    func run(_ item: LauncherItem) async -> LauncherResult {
        do {
            switch item.action {
            case .app(let bundleID):
                guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) else {
                    return .failure(.appNotInstalled(bundleID: bundleID))
                }
                _ = try await workspace.openApplication(at: appURL, configuration: activatingConfiguration())

            case .folder(let bookmarkData, let appBundleID):
                guard let appURL = workspace.urlForApplication(withBundleIdentifier: appBundleID) else {
                    return .failure(.appNotInstalled(bundleID: appBundleID))
                }
                guard let folderURL = resolveFolder(bookmarkData, itemID: item.id) else {
                    return .failure(.folderUnavailable)
                }
                // Keep the security scope open while handing the folder to the other app.
                try await folderURL.accessSecurityScopedResource { url in
                    _ = try await workspace.open([url], withApplicationAt: appURL, configuration: activatingConfiguration())
                }

            case .url(let url):
                _ = try await workspace.open(url, configuration: activatingConfiguration())

            case .shortcut(let name):
                guard let url = Self.shortcutURL(name: name) else {
                    return .failure(.openFailed("Invalid Shortcut name"))
                }
                _ = try await workspace.open(url, configuration: activatingConfiguration())
            }
            return .success
        } catch {
            NSLog("❌ Launcher failed to open item \(item.id): \(error.localizedDescription)")
            return .failure(.openFailed(error.localizedDescription))
        }
    }

    /// Runs the mode's items in order. One failure doesn't stop the rest.
    /// Returns the errors of the items that failed, keyed by item ID.
    func run(_ mode: LauncherMode) async -> [UUID: LauncherError] {
        var errors: [UUID: LauncherError] = [:]
        for item in mode.items {
            if case .failure(let error) = await run(item) {
                errors[item.id] = error
            }
        }
        return errors
    }

    // MARK: - Validation

    /// Checks that the item can be opened, without opening anything.
    /// Shortcuts can't be checked beforehand, so they always pass.
    func validate(_ item: LauncherItem) -> LauncherError? {
        switch item.action {
        case .app(let bundleID):
            return isInstalled(bundleID) ? nil : .appNotInstalled(bundleID: bundleID)
        case .folder(let bookmarkData, let appBundleID):
            guard isInstalled(appBundleID) else { return .appNotInstalled(bundleID: appBundleID) }
            return resolveFolder(bookmarkData, itemID: item.id) == nil ? .folderUnavailable : nil
        case .url, .shortcut:
            return nil
        }
    }

    // MARK: - Helpers

    /// `shortcuts://run-shortcut?name=<name>`, with the name encoded so that
    /// spaces, non-ASCII and query delimiters (`&`, `=`, `+`, `#`) survive.
    nonisolated static func shortcutURL(name: String) -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#?")
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=\(encoded)")
    }

    private func isInstalled(_ bundleID: String) -> Bool {
        workspace.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    private func activatingConfiguration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return configuration
    }

    /// Resolves a folder bookmark and checks the folder still exists and isn't in the Trash.
    /// A stale bookmark is refreshed and saved back to the launcher config.
    private func resolveFolder(_ bookmarkData: Data, itemID: UUID) -> URL? {
        let (resolvedURL, refreshedData) = Bookmark(data: bookmarkData).resolve()
        guard let url = resolvedURL else { return nil }

        if let refreshedData {
            var config = Defaults[.launcherConfig]
            if config.replaceBookmark(itemID: itemID, with: refreshedData) {
                Defaults[.launcherConfig] = config
            }
        }

        // Bookmarks follow moves, including into the Trash; treat a trashed folder as gone.
        let isUsable = url.accessSecurityScopedResource { url in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && !url.pathComponents.contains(".Trash")
        }
        return isUsable ? url : nil
    }
}
