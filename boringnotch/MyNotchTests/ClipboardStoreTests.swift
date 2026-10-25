//
//  ClipboardStoreTests.swift
//  MyNotchTests
//

import Foundation
import Testing
@testable import boringNotch

/// Each test gets its own temporary directory, removed afterwards.
@MainActor
final class ClipboardStoreTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore(limit: Int = 50) -> ClipboardStore {
        ClipboardStore(directory: directory, limit: limit)
    }

    private func text(_ value: String, date: Date = Date()) -> ClipboardCandidate {
        ClipboardCandidate(content: .text(value), sourceAppBundleID: "com.apple.TextEdit", date: date)
    }

    private func image(bytes: Int = 16, seed: UInt8 = 1) -> ClipboardCandidate {
        ClipboardCandidate(content: .image(png: Data(repeating: seed, count: bytes), thumbnailPNG: Data([seed, 2, 3])))
    }

    private func fileExists(_ name: String?, in store: ClipboardStore) -> Bool {
        guard let name else { return false }
        return FileManager.default.fileExists(atPath: store.imageURL(for: name).path)
    }

    // MARK: - Insert

    @Test func insertPrependsNewestFirst() {
        let store = makeStore()
        store.insert(text("first"))
        store.insert(text("second"))
        #expect(store.entries.map(\.text) == ["second", "first"])
    }

    @Test func duplicateMovesToTopWithoutGrowing() throws {
        let store = makeStore()
        let original = try #require(store.insert(text("same", date: Date(timeIntervalSince1970: 1))))
        store.insert(text("other"))

        let later = Date(timeIntervalSince1970: 1000)
        let moved = try #require(store.insert(text("same", date: later)))

        #expect(store.entries.count == 2)
        #expect(store.entries.first?.id == original.id)
        #expect(moved.id == original.id)
        #expect(moved.date == later)
    }

    @Test func textAndFilesWithSameStringAreDifferentEntries() {
        let store = makeStore()
        store.insert(text("/tmp/a"))
        store.insert(ClipboardCandidate(content: .files(["/tmp/a"])))
        #expect(store.entries.count == 2)
    }

    @Test func emptyAndOversizedContentIsRejected() {
        let store = makeStore()
        #expect(store.insert(text("   \n")) == nil)
        #expect(store.insert(text(String(repeating: "a", count: ClipboardStore.maxTextBytes + 1))) == nil)
        #expect(store.insert(image(bytes: ClipboardStore.maxImageBytes + 1)) == nil)
        #expect(store.insert(ClipboardCandidate(content: .files([]))) == nil)
        #expect(store.entries.isEmpty)
    }

    @Test func contentAtTheSizeLimitIsAccepted() {
        let store = makeStore()
        #expect(store.insert(text(String(repeating: "a", count: ClipboardStore.maxTextBytes))) != nil)
    }

    @Test func imageInsertWritesImageAndThumbnail() throws {
        let store = makeStore()
        let entry = try #require(store.insert(image()))
        store.flush()
        #expect(entry.kind == .image)
        #expect(fileExists(entry.imageFile, in: store))
        #expect(fileExists(entry.thumbFile, in: store))
    }

    // MARK: - Limits and delete

    @Test func capEvictsOldestAndDeletesItsImages() throws {
        let store = makeStore(limit: 2)
        let oldest = try #require(store.insert(image(seed: 1)))
        store.insert(text("b"))
        store.insert(text("c"))
        store.flush()

        #expect(store.entries.map(\.text) == ["c", "b"])
        #expect(!fileExists(oldest.imageFile, in: store))
        #expect(!fileExists(oldest.thumbFile, in: store))
    }

    @Test func setLimitTrimsImmediately() {
        let store = makeStore()
        for index in 1...15 { store.insert(text("item \(index)")) }

        store.setLimit(10)

        #expect(store.entries.count == 10)
        #expect(store.entries.first?.text == "item 15")
        #expect(store.entries.last?.text == "item 6")
    }

    @Test func deleteRemovesEntryAndFiles() throws {
        let store = makeStore()
        let entry = try #require(store.insert(image()))
        store.insert(text("keep"))

        store.delete(id: entry.id)
        store.flush()

        #expect(store.entries.map(\.text) == ["keep"])
        #expect(!fileExists(entry.imageFile, in: store))
        #expect(!fileExists(entry.thumbFile, in: store))
    }

    // MARK: - Persistence

    @Test func saveAndReloadRoundTrips() {
        let store = makeStore()
        store.insert(text("hello"))
        store.insert(image())
        store.insert(ClipboardCandidate(content: .files(["/Users/me/a.txt", "/Users/me/b.txt"]), sourceAppBundleID: "com.apple.finder"))
        store.flush()

        let reloaded = makeStore()
        #expect(reloaded.entries == store.entries)
    }

    @Test func reloadKeepsTheDeletionAndLimit() {
        let store = makeStore()
        for index in 1...5 { store.insert(text("item \(index)")) }
        store.delete(id: store.entries[0].id)
        store.flush()

        let reloaded = makeStore(limit: 3)
        #expect(reloaded.entries.map(\.text) == ["item 4", "item 3", "item 2"])
    }

    @Test func corruptHistoryStartsEmptyAndKeepsTheFile() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("history.json"))

        let store = makeStore()

        #expect(store.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.corruptHistoryURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.historyURL.path))
    }

    @Test func orphanedImagesAreRemovedOnLoad() throws {
        let store = makeStore()
        let kept = try #require(store.insert(image(seed: 7)))
        let orphan = store.imageURL(for: "orphan.png")
        try Data([1]).write(to: orphan)
        store.flush()

        let reloaded = makeStore()
        reloaded.flush()

        #expect(!FileManager.default.fileExists(atPath: orphan.path))
        #expect(fileExists(kept.imageFile, in: reloaded))
    }
}
