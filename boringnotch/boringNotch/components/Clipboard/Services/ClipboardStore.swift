//
//  ClipboardStore.swift
//  boringNotch
//

import Foundation

/// Persistent clipboard history: `<directory>/history.json` plus image files in `<directory>/images/`.
/// Pure logic with no pasteboard access or timers, so it can be unit-tested.
/// Disk writes happen in order on a background queue; call `flush()` to wait for them.
@MainActor
final class ClipboardStore {
    nonisolated static let maxTextBytes = 1_048_576          // 1 MB
    nonisolated static let maxImageBytes = 10 * 1_048_576    // 10 MB

    private(set) var entries: [ClipboardEntry] = []
    private(set) var limit: Int

    let directory: URL
    var historyURL: URL { directory.appendingPathComponent("history.json") }
    var corruptHistoryURL: URL { directory.appendingPathComponent("history.corrupt.json") }
    var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }

    private let ioQueue = DispatchQueue(label: "com.mustafaozkaya.mynotch.clipboard-store", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// `Application Support/<bundle ID>/Clipboard/` (inside the app's sandbox container).
    static var defaultDirectory: URL {
        let fileManager = FileManager.default
        let support = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        return support
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MyNotch", isDirectory: true)
            .appendingPathComponent("Clipboard", isDirectory: true)
    }

    init(directory: URL, limit: Int) {
        self.directory = directory
        self.limit = max(1, limit)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        load()
    }

    func imageURL(for fileName: String) -> URL {
        imagesDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Editing

    /// Adds a copy to the top of the history. A duplicate of an existing entry moves that entry
    /// to the top instead. Returns nil if the content is empty or over the size limits.
    @discardableResult
    func insert(_ candidate: ClipboardCandidate) -> ClipboardEntry? {
        guard Self.isAcceptable(candidate) else { return nil }

        let hash = candidate.contentHash
        if let index = entries.firstIndex(where: { $0.contentHash == hash }) {
            var existing = entries.remove(at: index)
            existing.date = candidate.date
            existing.sourceAppBundleID = candidate.sourceAppBundleID ?? existing.sourceAppBundleID
            entries.insert(existing, at: 0)
            save()
            return existing
        }

        let id = UUID()
        var entry = ClipboardEntry(
            id: id,
            kind: candidate.kind,
            contentHash: hash,
            sourceAppBundleID: candidate.sourceAppBundleID,
            date: candidate.date
        )
        switch candidate.content {
        case .text(let text):
            entry.text = text
        case .files(let paths):
            entry.filePaths = paths
        case .image(let png, let thumbnailPNG):
            let imageFile = "\(id.uuidString).png"
            entry.imageFile = imageFile
            writeFile(png, to: imageURL(for: imageFile))
            if let thumbnailPNG {
                let thumbFile = "\(id.uuidString)-thumb.png"
                entry.thumbFile = thumbFile
                writeFile(thumbnailPNG, to: imageURL(for: thumbFile))
            }
        }

        entries.insert(entry, at: 0)
        trimToLimit()
        save()
        return entry
    }

    /// Moves an existing entry to the top with a new date (used after copying it back).
    func moveToTop(id: UUID, date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.date = date
        entries.insert(entry, at: 0)
        save()
    }

    /// Removes an entry and its image files.
    func delete(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        deleteFiles(of: entries.remove(at: index))
        save()
    }

    /// Changes the maximum number of entries; extra (oldest) entries are removed right away.
    func setLimit(_ newLimit: Int) {
        limit = max(1, newLimit)
        if trimToLimit() {
            save()
        }
    }

    // MARK: - Persistence

    /// Loads `history.json`. A missing file means an empty history; a corrupt one is kept
    /// as `history.corrupt.json` for inspection and the history starts empty.
    func load() {
        let fileManager = FileManager.default
        guard let data = try? Data(contentsOf: historyURL) else {
            entries = []
            return
        }
        do {
            entries = try decoder.decode([ClipboardEntry].self, from: data)
        } catch {
            NSLog("⚠️ Clipboard history is corrupt (\(error.localizedDescription)); starting empty")
            try? fileManager.removeItem(at: corruptHistoryURL)
            try? fileManager.moveItem(at: historyURL, to: corruptHistoryURL)
            entries = []
        }
        if trimToLimit() {
            save()
        }
        removeOrphanedImages()
    }

    /// Writes the history atomically on the background queue.
    func save() {
        let data: Data
        do {
            data = try encoder.encode(entries)
        } catch {
            NSLog("❌ Failed to encode clipboard history: \(error.localizedDescription)")
            return
        }
        writeFile(data, to: historyURL)
    }

    /// Blocks until every pending write and delete has finished.
    func flush() {
        ioQueue.sync {}
    }

    // MARK: - Helpers

    nonisolated static func isAcceptable(_ candidate: ClipboardCandidate) -> Bool {
        switch candidate.content {
        case .text(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard text.utf8.count <= maxTextBytes else {
                NSLog("ℹ️ Clipboard: skipped text over 1 MB")
                return false
            }
            return true
        case .image(let png, _):
            guard !png.isEmpty else { return false }
            guard png.count <= maxImageBytes else {
                NSLog("ℹ️ Clipboard: skipped image over 10 MB")
                return false
            }
            return true
        case .files(let paths):
            return !paths.isEmpty
        }
    }

    /// Drops the oldest entries beyond the limit. Returns true if anything was removed.
    @discardableResult
    private func trimToLimit() -> Bool {
        guard entries.count > limit else { return false }
        let removed = Array(entries[limit...])
        entries.removeLast(entries.count - limit)
        removed.forEach(deleteFiles(of:))
        return true
    }

    private func deleteFiles(of entry: ClipboardEntry) {
        let urls = [entry.imageFile, entry.thumbFile].compactMap { $0 }.map(imageURL(for:))
        guard !urls.isEmpty else { return }
        ioQueue.async {
            urls.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    private func writeFile(_ data: Data, to url: URL) {
        ioQueue.async {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("❌ Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Deletes image files no entry refers to (e.g. left over after a crash or a corrupt history).
    private func removeOrphanedImages() {
        let referenced = Set(entries.flatMap { [$0.imageFile, $0.thumbFile].compactMap { $0 } })
        let directory = imagesDirectory
        ioQueue.async {
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
            for file in files where !referenced.contains(file) {
                try? fileManager.removeItem(at: directory.appendingPathComponent(file))
            }
        }
    }
}
