//
//  LauncherTests.swift
//  MyNotchTests
//

import Foundation
import Testing
@testable import boringNotch

struct LauncherModelTests {
    @Test func configRoundTripsEveryActionType() throws {
        let items = [
            LauncherItem(label: "Code", action: .app(bundleID: "com.microsoft.VSCode")),
            LauncherItem(action: .folder(bookmark: Data([1, 2, 3]), appBundleID: "com.microsoft.VSCode")),
            LauncherItem(label: "Docs", action: .url(try #require(URL(string: "https://developer.apple.com")))),
            LauncherItem(action: .shortcut(name: "Dev Mode ü")),
        ]
        let config = LauncherConfig(
            modes: [LauncherMode(name: "Developer", items: items)],
            items: items
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LauncherConfig.self, from: data)

        #expect(decoded == config)
    }

    @Test func replaceBookmarkUpdatesStandaloneAndModeItems() {
        let folder = LauncherItem(action: .folder(bookmark: Data([1]), appBundleID: "com.apple.finder"))
        var config = LauncherConfig(modes: [LauncherMode(name: "Dev", items: [folder])], items: [folder])

        let updated = config.replaceBookmark(itemID: folder.id, with: Data([9]))
        #expect(updated)

        let expected = LauncherAction.folder(bookmark: Data([9]), appBundleID: "com.apple.finder")
        #expect(config.items[0].action == expected)
        #expect(config.modes[0].items[0].action == expected)
    }

    @Test func replaceBookmarkIgnoresUnknownAndNonFolderItems() {
        let app = LauncherItem(action: .app(bundleID: "com.apple.finder"))
        var config = LauncherConfig(modes: [], items: [app])

        let updatedUnknown = config.replaceBookmark(itemID: UUID(), with: Data([9]))
        let updatedApp = config.replaceBookmark(itemID: app.id, with: Data([9]))
        #expect(!updatedUnknown)
        #expect(!updatedApp)
        #expect(config.items[0] == app)
    }
}

struct ShortcutURLTests {
    @Test func encodesSpacesAndUnicode() {
        let url = LauncherService.shortcutURL(name: "Dev Mode ü")
        #expect(url?.absoluteString == "shortcuts://run-shortcut?name=Dev%20Mode%20%C3%BC")
    }

    @Test func encodesQueryDelimiters() {
        let url = LauncherService.shortcutURL(name: "A&B=C+D#E?")
        #expect(url?.absoluteString == "shortcuts://run-shortcut?name=A%26B%3DC%2BD%23E%3F")
    }

    @Test func rejectsEmptyName() {
        #expect(LauncherService.shortcutURL(name: "   ") == nil)
    }
}

@MainActor
struct LauncherValidationTests {
    let service = LauncherService.shared

    @Test func missingAppIsReported() {
        let item = LauncherItem(action: .app(bundleID: "invalid.example.none"))
        #expect(service.validate(item) == .appNotInstalled(bundleID: "invalid.example.none"))
    }

    @Test func installedAppPasses() {
        #expect(service.validate(LauncherItem(action: .app(bundleID: "com.apple.finder"))) == nil)
    }

    @Test func urlAndShortcutAlwaysPass() throws {
        let url = LauncherItem(action: .url(try #require(URL(string: "https://example.com"))))
        #expect(service.validate(url) == nil)
        #expect(service.validate(LauncherItem(action: .shortcut(name: "Does Not Exist"))) == nil)
    }

    @Test func folderBookmarkResolvesUntilFolderIsDeleted() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LauncherTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bookmark = try Bookmark(url: folder).data
        let item = LauncherItem(action: .folder(bookmark: bookmark, appBundleID: "com.apple.finder"))

        #expect(service.validate(item) == nil)

        try FileManager.default.removeItem(at: folder)
        #expect(service.validate(item) == .folderUnavailable)
    }

    @Test func garbageBookmarkIsUnavailable() {
        let item = LauncherItem(action: .folder(bookmark: Data([0xDE, 0xAD]), appBundleID: "com.apple.finder"))
        #expect(service.validate(item) == .folderUnavailable)
    }

    @Test func folderWithMissingAppReportsTheApp() {
        let item = LauncherItem(action: .folder(bookmark: Data([1]), appBundleID: "invalid.example.none"))
        #expect(service.validate(item) == .appNotInstalled(bundleID: "invalid.example.none"))
    }
}
