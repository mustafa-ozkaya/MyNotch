//
//  ClipboardActions.swift
//  boringNotch
//

import AppKit

/// Writes history entries back to the general pasteboard.
@MainActor
enum ClipboardActions {
    /// Puts the entry on the pasteboard (text as plain text, images as PNG, files as file URLs).
    /// Returns false if the entry's content is missing, e.g. its image file was deleted.
    @discardableResult
    static func copyBack(_ entry: ClipboardEntry, store: ClipboardStore, pasteboard: NSPasteboard = .general) -> Bool {
        switch entry.kind {
        case .text:
            guard let text = entry.text else { return false }
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)

        case .image:
            guard let imageFile = entry.imageFile,
                  let png = try? Data(contentsOf: store.imageURL(for: imageFile)) else { return false }
            pasteboard.clearContents()
            return pasteboard.setData(png, forType: .png)

        case .files:
            guard let paths = entry.filePaths, !paths.isEmpty else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects(paths.map { URL(fileURLWithPath: $0) as NSURL })
        }
    }
}
