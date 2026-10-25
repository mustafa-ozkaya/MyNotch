//
//  ClipboardMonitor.swift
//  boringNotch
//

import AppKit

/// Polls the general pasteboard and records new copies in the store.
/// macOS has no pasteboard-change notification, so it compares `changeCount` every 0.5 s
/// and only reads contents when the count changed.
@MainActor
final class ClipboardMonitor {
    /// Upper bound for raw image data before converting it, to skip pathological copies early.
    static let maxRawImageBytes = 100 * 1_048_576

    private let store: ClipboardStore
    private let pasteboard: NSPasteboard
    private var pollTask: Task<Void, Never>?
    private var lastChangeCount: Int
    /// Change count right after MyNotch wrote to the pasteboard itself (copy-back).
    private var lastSelfWriteChangeCount: Int?

    /// The app the copy is attributed to. Replaceable in tests.
    var frontmostAppBundleID: () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }

    /// Called after the store changed because of a new copy.
    var onStoreChange: (() -> Void)?
    /// Called when pasteboard access becomes denied or allowed again.
    var onAccessDeniedChange: ((Bool) -> Void)?

    private(set) var accessDenied = false {
        didSet {
            if accessDenied != oldValue { onAccessDeniedChange?(accessDenied) }
        }
    }

    var isRunning: Bool { pollTask != nil }

    init(store: ClipboardStore, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard pollTask == nil else { return }
        // Don't record whatever was on the clipboard before monitoring started.
        lastChangeCount = pasteboard.changeCount
        updateAccessDenied()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    break
                }
                self?.checkForChanges()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Call right after writing to the pasteboard, so the monitor doesn't record that write.
    func noteSelfWrite() {
        lastSelfWriteChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Polling

    /// One polling step: records the pasteboard contents if they changed since the last check.
    /// Called by the timer loop; internal so tests can run a step without waiting.
    func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard changeCount != lastSelfWriteChangeCount else { return }

        updateAccessDenied()
        guard !accessDenied else { return }

        let types = pasteboard.types ?? []
        let sourceApp = frontmostAppBundleID()
        guard !ClipboardContentRules.shouldIgnore(types: types, sourceApp: sourceApp) else { return }

        for kind in ClipboardContentRules.readOrder(types: types) {
            if read(kind, sourceApp: sourceApp) { return }
        }
    }

    /// Reads one kind from the pasteboard. Returns true if that kind was found and handled.
    private func read(_ kind: ClipboardEntry.Kind, sourceApp: String?) -> Bool {
        switch kind {
        case .files:
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            guard !urls.isEmpty else { return false }
            insert(.files(urls.map(\.path)), sourceApp: sourceApp)
            return true

        case .text:
            guard let text = readPlainText(),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            insert(.text(text), sourceApp: sourceApp)
            return true

        case .image:
            let png = pasteboard.data(forType: .png)
            guard let data = png
                    ?? pasteboard.data(forType: .tiff)
                    ?? NSImage(pasteboard: pasteboard)?.tiffRepresentation else { return false }
            convertAndInsertImage(data, isPNG: png != nil, sourceApp: sourceApp)
            return true
        }
    }

    /// Plain text, or the plain-text version of rich text / HTML.
    private func readPlainText() -> String? {
        if let string = pasteboard.string(forType: .string) {
            return string
        }
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            return attributed.string
        }
        if let html = pasteboard.data(forType: .html),
           let attributed = try? NSAttributedString(
               data: html,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            return attributed.string
        }
        return nil
    }

    /// PNG encoding and thumbnailing can take a moment for large images, so they run off the main thread.
    private func convertAndInsertImage(_ data: Data, isPNG: Bool, sourceApp: String?) {
        // Raw TIFF can be much bigger than its PNG; the store applies the real 10 MB PNG limit.
        guard data.count <= Self.maxRawImageBytes else {
            NSLog("ℹ️ Clipboard: skipped very large image (\(data.count) bytes)")
            return
        }
        Task { @MainActor [weak self] in
            let converted = await Task.detached(priority: .utility) {
                ClipboardContentRules.pngAndThumbnail(from: data, isAlreadyPNG: isPNG)
            }.value
            guard let self, let converted else { return }
            self.insert(.image(png: converted.png, thumbnailPNG: converted.thumbnail), sourceApp: sourceApp)
        }
    }

    private func insert(_ content: ClipboardCandidate.Content, sourceApp: String?) {
        guard store.insert(ClipboardCandidate(content: content, sourceAppBundleID: sourceApp)) != nil else { return }
        onStoreChange?()
    }

    private func updateAccessDenied() {
        if #available(macOS 15.4, *) {
            accessDenied = pasteboard.accessBehavior == .alwaysDeny
        } else {
            accessDenied = false
        }
    }
}
