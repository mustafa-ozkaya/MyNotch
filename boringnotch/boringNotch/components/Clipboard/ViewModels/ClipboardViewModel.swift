//
//  ClipboardViewModel.swift
//  boringNotch
//

import AppKit
import Defaults

/// Owns the clipboard store and monitor, and publishes the history for the Clipboard tab.
@MainActor
final class ClipboardViewModel: ObservableObject {
    static let shared = ClipboardViewModel()

    @Published private(set) var entries: [ClipboardEntry] = []
    /// True when the user denied pasteboard access in System Settings.
    @Published private(set) var accessDenied = false
    /// Entry that was just copied back, for the brief "Copied" state.
    @Published var copiedEntryID: UUID?

    let store: ClipboardStore
    private let monitor: ClipboardMonitor
    private var settingsTask: Task<Void, Never>?

    private init() {
        store = ClipboardStore(directory: ClipboardStore.defaultDirectory, limit: Defaults[.clipboardHistoryLimit])
        monitor = ClipboardMonitor(store: store)
        entries = store.entries

        monitor.onStoreChange = { [weak self] in self?.reload() }
        monitor.onAccessDeniedChange = { [weak self] denied in self?.accessDenied = denied }
    }

    /// Starts monitoring if the Clipboard tab is on, and follows the Settings toggles from then on.
    func activate() {
        guard settingsTask == nil else { return }
        settingsTask = Task { @MainActor [weak self] in
            for await (enabled, limit) in Defaults.updates(.showClipboardTab, .clipboardHistoryLimit) {
                guard let self else { return }
                if enabled {
                    self.monitor.start()
                } else {
                    self.monitor.stop()
                }
                if limit != self.store.limit {
                    self.store.setLimit(limit)
                    self.reload()
                }
            }
        }
    }

    /// Stops monitoring and waits for pending disk writes (app quit).
    func shutDown() {
        settingsTask?.cancel()
        settingsTask = nil
        monitor.stop()
        store.flush()
    }

    /// Copies an entry back to the pasteboard and moves it to the top.
    /// Returns false if its content is gone (e.g. a missing image file).
    @discardableResult
    func copy(_ entry: ClipboardEntry) -> Bool {
        guard ClipboardActions.copyBack(entry, store: store) else { return false }
        monitor.noteSelfWrite()
        store.moveToTop(id: entry.id)
        reload()
        copiedEntryID = entry.id
        return true
    }

    func delete(_ entry: ClipboardEntry) {
        store.delete(id: entry.id)
        reload()
    }

    func imageURL(for fileName: String) -> URL {
        store.imageURL(for: fileName)
    }

    private func reload() {
        entries = store.entries
    }
}
