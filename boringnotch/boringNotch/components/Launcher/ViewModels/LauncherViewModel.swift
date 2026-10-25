//
//  LauncherViewModel.swift
//  boringNotch
//

import AppKit
import Defaults

/// Precomputed name and icons for one item, so the notch doesn't resolve
/// bookmarks or look up app icons on every redraw.
struct LauncherItemPresentation {
    let name: String
    let icon: NSImage?
    /// Small app icon drawn on top of folder icons (the app the folder opens in).
    let badgeIcon: NSImage?
}

@MainActor
final class LauncherViewModel: ObservableObject {
    static let shared = LauncherViewModel()

    @Published private(set) var config: LauncherConfig = Defaults[.launcherConfig]
    /// Validation problems plus failures from the last run, keyed by item ID.
    @Published private(set) var errors: [UUID: LauncherError] = [:]
    /// The mode or item currently running; other clicks are ignored meanwhile.
    @Published private(set) var runningID: UUID?
    @Published private(set) var presentations: [UUID: LauncherItemPresentation] = [:]

    private var configTask: Task<Void, Never>?

    var isRunning: Bool { runningID != nil }

    private init() {
        refresh()
        configTask = Task { @MainActor [weak self] in
            for await newConfig in Defaults.updates(.launcherConfig, initial: false) {
                self?.config = newConfig
                self?.refresh()
            }
        }
    }

    /// Re-validates every item and rebuilds names and icons.
    func refresh() {
        var newErrors: [UUID: LauncherError] = [:]
        var newPresentations: [UUID: LauncherItemPresentation] = [:]
        for item in config.allItems {
            newErrors[item.id] = LauncherService.shared.validate(item)
            newPresentations[item.id] = Self.makePresentation(for: item)
        }
        errors = newErrors
        presentations = newPresentations
    }

    func presentation(for item: LauncherItem) -> LauncherItemPresentation {
        presentations[item.id] ?? Self.makePresentation(for: item)
    }

    /// Combined tooltip for a mode whose items have problems, or nil if all are fine.
    func errorSummary(for mode: LauncherMode) -> String? {
        let lines = mode.items.compactMap { item -> String? in
            guard let error = errors[item.id] else { return nil }
            return "\(presentation(for: item).name): \(error.message)"
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: - Running

    /// Runs one item. Returns true if it opened.
    func run(_ item: LauncherItem) async -> Bool {
        guard !isRunning else { return false }
        runningID = item.id
        defer { runningID = nil }

        switch await LauncherService.shared.run(item) {
        case .success:
            errors[item.id] = nil
            return true
        case .failure(let error):
            errors[item.id] = error
            return false
        }
    }

    /// Runs every item of a mode. Returns true if all of them opened.
    func run(_ mode: LauncherMode) async -> Bool {
        guard !isRunning, !mode.items.isEmpty else { return false }
        runningID = mode.id
        defer { runningID = nil }

        let failures = await LauncherService.shared.run(mode)
        for item in mode.items {
            errors[item.id] = failures[item.id]
        }
        return failures.isEmpty
    }

    // MARK: - Helpers

    private static func makePresentation(for item: LauncherItem) -> LauncherItemPresentation {
        let badgeIcon: NSImage?
        if case .folder(_, let appBundleID) = item.action {
            badgeIcon = LauncherItemInfo.appIcon(bundleID: appBundleID)
        } else {
            badgeIcon = nil
        }
        return LauncherItemPresentation(
            name: LauncherItemInfo.displayName(for: item),
            icon: LauncherItemInfo.icon(for: item.action),
            badgeIcon: badgeIcon
        )
    }
}
