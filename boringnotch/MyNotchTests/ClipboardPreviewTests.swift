//
//  ClipboardPreviewTests.swift
//  MyNotchTests
//

import Foundation
import Testing
@testable import boringNotch

struct ClipboardPreviewTests {
    private func entry(_ kind: ClipboardEntry.Kind, text: String? = nil, paths: [String]? = nil) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), kind: kind, text: text, filePaths: paths, contentHash: "x", date: Date())
    }

    @Test func shortTextIsTrimmed() {
        #expect(ClipboardPreview.title(for: entry(.text, text: "  hello \n")) == "hello")
    }

    @Test func longTextIsCutAt200Characters() {
        let title = ClipboardPreview.title(for: entry(.text, text: String(repeating: "a", count: 500)))
        #expect(title.count == ClipboardPreview.maxCharacters + 1)
        #expect(title.hasSuffix("…"))
    }

    @Test func singleFileShowsItsName() {
        #expect(ClipboardPreview.title(for: entry(.files, paths: ["/Users/me/Report.pdf"])) == "Report.pdf")
    }

    @Test func severalFilesShowFirstNamePlusCount() {
        let title = ClipboardPreview.title(for: entry(.files, paths: ["/a/One.txt", "/a/Two.txt", "/a/Three.txt"]))
        #expect(title == "One.txt +2 more")
    }

    @Test func imageHasAGenericTitle() {
        #expect(ClipboardPreview.title(for: entry(.image)) == "Image")
    }
}
