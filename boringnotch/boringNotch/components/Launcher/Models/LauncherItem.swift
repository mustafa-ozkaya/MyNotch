//
//  LauncherItem.swift
//  boringNotch
//

import Defaults
import Foundation

/// One thing the Launcher can open.
struct LauncherItem: Codable, Identifiable, Hashable {
    let id: UUID
    /// Custom label; when nil the UI derives a name from the action.
    var label: String?
    var action: LauncherAction

    init(id: UUID = UUID(), label: String? = nil, action: LauncherAction) {
        self.id = id
        self.label = label
        self.action = action
    }
}

enum LauncherAction: Codable, Hashable {
    /// Launch or focus an app.
    case app(bundleID: String)
    /// Open a folder in a specific app. `bookmark` is an app-scoped, security-scoped bookmark.
    case folder(bookmark: Data, appBundleID: String)
    /// Open a URL with its default handler (Safari adds it as a tab).
    case url(URL)
    /// Run an Apple Shortcut by its exact name.
    case shortcut(name: String)
}

/// A named list of items opened together with one click.
struct LauncherMode: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    /// SF Symbol name shown on the mode button.
    var symbol: String
    var items: [LauncherItem]

    init(id: UUID = UUID(), name: String, symbol: String = "bolt.fill", items: [LauncherItem] = []) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.items = items
    }
}

struct LauncherConfig: Codable, Hashable, Defaults.Serializable {
    var modes: [LauncherMode]
    /// Standalone items shown below the modes.
    var items: [LauncherItem]

    static let empty = LauncherConfig(modes: [], items: [])

    var isEmpty: Bool { modes.isEmpty && items.isEmpty }

    /// Every item, standalone and inside modes.
    var allItems: [LauncherItem] { items + modes.flatMap(\.items) }

    /// Replaces the bookmark of a folder item wherever it appears (standalone or in a mode).
    /// Used when a stale bookmark was refreshed. Returns true if an item was updated.
    @discardableResult
    mutating func replaceBookmark(itemID: UUID, with bookmark: Data) -> Bool {
        func update(_ item: inout LauncherItem) -> Bool {
            guard item.id == itemID, case .folder(_, let appBundleID) = item.action else { return false }
            item.action = .folder(bookmark: bookmark, appBundleID: appBundleID)
            return true
        }
        var updated = false
        for index in items.indices {
            if update(&items[index]) { updated = true }
        }
        for modeIndex in modes.indices {
            for itemIndex in modes[modeIndex].items.indices {
                if update(&modes[modeIndex].items[itemIndex]) { updated = true }
            }
        }
        return updated
    }
}
