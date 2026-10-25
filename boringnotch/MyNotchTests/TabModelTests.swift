//
//  TabModelTests.swift
//  MyNotchTests
//

import Testing
@testable import boringNotch

struct TabModelTests {
    @Test func allTabsInOrderWhenEverythingIsOn() {
        let views = TabModel.visibleTabs(showShelf: true, showLauncher: true, showClipboard: true).map(\.view)
        #expect(views == [.home, .shelf, .launcher, .clipboard])
    }

    @Test func homeIsAlwaysPresent() {
        let views = TabModel.visibleTabs(showShelf: false, showLauncher: false, showClipboard: false).map(\.view)
        #expect(views == [.home])
    }

    @Test(arguments: [
        (true, false, false, [NotchViews.home, .shelf]),
        (false, true, false, [.home, .launcher]),
        (false, false, true, [.home, .clipboard]),
        (false, true, true, [.home, .launcher, .clipboard]),
    ])
    func togglesHideTheirTab(shelf: Bool, launcher: Bool, clipboard: Bool, expected: [NotchViews]) {
        let views = TabModel.visibleTabs(showShelf: shelf, showLauncher: launcher, showClipboard: clipboard).map(\.view)
        #expect(views == expected)
    }
}
