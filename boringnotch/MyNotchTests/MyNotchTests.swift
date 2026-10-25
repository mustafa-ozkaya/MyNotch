//
//  MyNotchTests.swift
//  MyNotchTests
//

import Testing
@testable import boringNotch

struct MyNotchTests {
    /// Placeholder proving the test target builds, links against the app and runs.
    @Test func appModuleIsReachable() {
        #expect(NotchViews.home != NotchViews.shelf)
    }
}
