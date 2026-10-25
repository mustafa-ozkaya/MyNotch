//
//  LauncherEditingTests.swift
//  MyNotchTests
//

import Foundation
import Testing
@testable import boringNotch

struct LauncherEditingTests {
    private func makeItems(_ names: [String]) -> [LauncherItem] {
        names.map { LauncherItem(label: $0, action: .shortcut(name: $0)) }
    }

    @Test func appendAndRemoveTargetTheRightList() {
        let mode = LauncherMode(name: "Dev")
        var config = LauncherConfig(modes: [mode], items: [])
        let standalone = LauncherItem(action: .app(bundleID: "com.apple.finder"))
        let inMode = LauncherItem(action: .shortcut(name: "Build"))

        config.append(standalone, to: .standalone)
        config.append(inMode, to: .mode(mode.id))
        #expect(config.items == [standalone])
        #expect(config.modes[0].items == [inMode])

        config.removeItem(id: inMode.id, from: .mode(mode.id))
        #expect(config.modes[0].items.isEmpty)
        #expect(config.items == [standalone])
    }

    @Test func unknownModeIsIgnored() {
        var config = LauncherConfig.empty
        config.append(LauncherItem(action: .shortcut(name: "X")), to: .mode(UUID()))
        #expect(config == .empty)
    }

    @Test func moveItemUpAndDownIsClamped() {
        let items = makeItems(["A", "B", "C"])
        var config = LauncherConfig(modes: [], items: items)

        config.moveItem(id: items[2].id, by: -1, in: .standalone)
        #expect(config.items.map(\.label) == ["A", "C", "B"])

        config.moveItem(id: items[0].id, by: -1, in: .standalone)
        #expect(config.items.map(\.label) == ["A", "C", "B"])

        config.moveItem(id: items[0].id, by: 5, in: .standalone)
        #expect(config.items.map(\.label) == ["C", "B", "A"])
    }

    @Test func moveModeReorders() {
        let a = LauncherMode(name: "A"), b = LauncherMode(name: "B")
        var config = LauncherConfig(modes: [a, b], items: [])
        config.moveMode(id: b.id, by: -1)
        #expect(config.modes.map(\.name) == ["B", "A"])
    }

    @Test func updateItemChangesOnlyThatItem() {
        let mode = LauncherMode(name: "Dev", items: makeItems(["A", "B"]))
        var config = LauncherConfig(modes: [mode], items: [])
        config.updateItem(id: mode.items[1].id, in: .mode(mode.id)) { $0.label = "Renamed" }
        #expect(config.modes[0].items.map(\.label) == ["A", "Renamed"])
    }
}

struct LauncherURLParsingTests {
    @Test(arguments: ["https://example.com", "http://localhost:3000/path", "  https://github.com  ", "mailto:me@example.com", "vscode://file/tmp"])
    func acceptsFullURLs(text: String) {
        #expect(LauncherPickers.parseURL(text) != nil)
    }

    @Test(arguments: ["example.com", "localhost:3000", "https://", "", "not a url"])
    func rejectsURLsWithoutScheme(text: String) {
        #expect(LauncherPickers.parseURL(text) == nil)
    }
}
