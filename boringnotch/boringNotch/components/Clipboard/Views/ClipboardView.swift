//
//  ClipboardView.swift
//  boringNotch
//

import SwiftUI

/// Clipboard tab: recent copies, newest first. Click a row to copy it back.
struct ClipboardView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var clipboard = ClipboardViewModel.shared

    var body: some View {
        Group {
            if clipboard.accessDenied {
                accessDeniedState
            } else if clipboard.entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(.horizontal, 4)
    }

    private var list: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 2) {
                ForEach(clipboard.entries) { entry in
                    ClipboardRow(
                        entry: entry,
                        thumbnail: clipboard.thumbnail(for: entry),
                        sourceAppIcon: clipboard.sourceAppIcon(for: entry),
                        isCopied: clipboard.copiedEntryID == entry.id,
                        onCopy: { copy(entry) },
                        onDelete: { clipboard.delete(entry) }
                    )
                }
            }
        }
        .scrollIndicators(.never)
    }

    /// Copies the entry back, shows "Copied" briefly, then closes the notch.
    private func copy(_ entry: ClipboardEntry) {
        guard clipboard.copiedEntryID == nil else { return }
        guard clipboard.copy(entry) else {
            NSSound.beep()
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            vm.close()
            clipboard.copiedEntryID = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("Nothing copied yet. Copy something and it'll show up here.")
                .foregroundStyle(.gray)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accessDeniedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("MyNotch can't read the clipboard. Allow it in System Settings › Privacy & Security › Paste from Other Apps.")
                .foregroundStyle(.gray)
                .font(.system(.callout, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.effectiveAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let thumbnail: NSImage?
    let sourceAppIcon: NSImage?
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCopied ? "Copied" : ClipboardPreview.title(for: entry))
                    .font(.system(size: 12))
                    .foregroundStyle(isCopied ? .white : Color(white: 0.85))
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(entry.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovering && !isCopied {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                .help("Delete")
            } else if let sourceAppIcon {
                Image(nsImage: sourceAppIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isCopied ? 0.18 : (isHovering ? 0.1 : 0)))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if isCopied {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        } else if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: ClipboardPreview.symbol(for: entry.kind))
                .font(.system(size: 15))
                .foregroundStyle(.gray)
        }
    }
}

/// Text shown for each entry in the list.
enum ClipboardPreview {
    static let maxCharacters = 200

    static func title(for entry: ClipboardEntry) -> String {
        switch entry.kind {
        case .text:
            let text = (entry.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.count > maxCharacters ? String(text.prefix(maxCharacters)) + "…" : text
        case .image:
            return "Image"
        case .files:
            let paths = entry.filePaths ?? []
            guard let first = paths.first else { return "Files" }
            let name = URL(fileURLWithPath: first).lastPathComponent
            return paths.count > 1 ? "\(name) +\(paths.count - 1) more" : name
        }
    }

    static func symbol(for kind: ClipboardEntry.Kind) -> String {
        switch kind {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .files: return "doc"
        }
    }
}

#Preview {
    ClipboardView()
        .environmentObject(BoringViewModel())
        .frame(width: 600, height: 150)
        .background(.black)
}
