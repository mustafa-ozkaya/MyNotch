//
//  ClipboardEntry.swift
//  boringNotch
//

import CryptoKit
import Foundation

/// One saved copy in the clipboard history.
struct ClipboardEntry: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case text, image, files
    }

    let id: UUID
    var kind: Kind
    /// Plain text, for `.text`.
    var text: String?
    /// PNG file name in `images/`, for `.image`.
    var imageFile: String?
    /// Thumbnail PNG file name in `images/` (max 160 px), for `.image`.
    var thumbFile: String?
    /// File paths, for `.files`.
    var filePaths: [String]?
    /// SHA-256 of the content, used to detect duplicates.
    var contentHash: String
    var sourceAppBundleID: String?
    var date: Date
}

/// Something read from the pasteboard, before it's stored.
struct ClipboardCandidate {
    enum Content {
        case text(String)
        /// Full image as PNG, plus an optional small PNG thumbnail.
        case image(png: Data, thumbnailPNG: Data?)
        case files([String])
    }

    var content: Content
    var sourceAppBundleID: String?
    var date: Date = Date()

    var kind: ClipboardEntry.Kind {
        switch content {
        case .text: return .text
        case .image: return .image
        case .files: return .files
        }
    }

    /// SHA-256 over the kind plus the content, so equal text and an equal file path never collide.
    var contentHash: String {
        var hasher = SHA256()
        hasher.update(data: Data("\(kind.rawValue):".utf8))
        switch content {
        case .text(let text):
            hasher.update(data: Data(text.utf8))
        case .image(let png, _):
            hasher.update(data: png)
        case .files(let paths):
            hasher.update(data: Data(paths.joined(separator: "\n").utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
