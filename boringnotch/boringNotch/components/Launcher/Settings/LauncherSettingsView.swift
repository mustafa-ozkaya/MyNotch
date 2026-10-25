//
//  LauncherSettingsView.swift
//  boringNotch
//

import Defaults
import SwiftUI

/// Settings pane for the Launcher tab: modes, standalone items and the tab toggle.
struct LauncherSettingsView: View {
    @Default(.launcherConfig) private var config
    /// Validation results for every item, refreshed whenever the config changes.
    @State private var errors: [UUID: LauncherError] = [:]
    @State private var textEntry: LauncherTextEntryRequest?

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showLauncherTab) {
                    Text("Show Launcher tab")
                }
            } header: {
                Text("General")
            }

            Section {
                if config.modes.isEmpty {
                    Text("No modes yet. A mode opens several items with one click.")
                        .foregroundStyle(.secondary)
                }
                ForEach(config.modes) { mode in
                    modeEditor(mode)
                }
                Button {
                    config.modes.append(LauncherMode(name: "New Mode"))
                } label: {
                    Label("Add Mode", systemImage: "plus")
                }
            } header: {
                Text("Modes")
            }

            Section {
                if config.items.isEmpty {
                    Text("No items yet.")
                        .foregroundStyle(.secondary)
                }
                itemRows(in: .standalone)
                addItemMenu(to: .standalone)
            } header: {
                Text("Items")
            }
        }
        .navigationTitle("Launcher")
        .task(id: config) {
            // Runs outside view updates: validating may refresh and save a stale folder bookmark.
            var results: [UUID: LauncherError] = [:]
            for item in config.allItems {
                results[item.id] = LauncherService.shared.validate(item)
            }
            errors = results
        }
        .sheet(item: $textEntry) { request in
            LauncherTextEntrySheet(kind: request.kind) { action in
                config.append(LauncherItem(action: action), to: request.target)
            }
        }
    }

    // MARK: - Modes

    private func modeEditor(_ mode: LauncherMode) -> some View {
        let isFirst = config.modes.first?.id == mode.id
        let isLast = config.modes.last?.id == mode.id
        let brokenCount = mode.items.filter { errors[$0.id] != nil }.count

        return DisclosureGroup {
            TextField("Symbol", text: modeBinding(mode.id, \.symbol), prompt: Text("bolt.fill"))
                .help("SF Symbol name shown on the mode button")
            if mode.items.isEmpty {
                Text("No items in this mode.")
                    .foregroundStyle(.secondary)
            }
            itemRows(in: .mode(mode.id))
            addItemMenu(to: .mode(mode.id))
        } label: {
            HStack {
                Image(systemName: mode.symbol.isEmpty ? "bolt.fill" : mode.symbol)
                    .frame(width: 20)
                TextField("Name", text: modeBinding(mode.id, \.name), prompt: Text("Mode name"))
                    .labelsHidden()
                Text(mode.items.count == 1 ? "1 item" : "\(mode.items.count) items")
                    .foregroundStyle(.secondary)
                if brokenCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help(brokenCount == 1 ? "1 item can't be opened" : "\(brokenCount) items can't be opened")
                }
                reorderButtons(isFirst: isFirst, isLast: isLast) { offset in
                    config.moveMode(id: mode.id, by: offset)
                }
                Button(role: .destructive) {
                    config.modes.removeAll { $0.id == mode.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete mode")
            }
        }
    }

    private func modeBinding(_ modeID: UUID, _ keyPath: WritableKeyPath<LauncherMode, String>) -> Binding<String> {
        Binding {
            config.modes.first(where: { $0.id == modeID })?[keyPath: keyPath] ?? ""
        } set: { newValue in
            guard let index = config.modes.firstIndex(where: { $0.id == modeID }) else { return }
            config.modes[index][keyPath: keyPath] = newValue
        }
    }

    // MARK: - Items

    @ViewBuilder
    private func itemRows(in target: LauncherListTarget) -> some View {
        let items = config[items: target]
        ForEach(items) { item in
            LauncherItemSettingsRow(
                item: item,
                error: errors[item.id],
                isFirst: items.first?.id == item.id,
                isLast: items.last?.id == item.id,
                label: labelBinding(item.id, in: target),
                onMove: { offset in config.moveItem(id: item.id, by: offset, in: target) },
                onRepick: { repick(item, in: target) },
                onDelete: { config.removeItem(id: item.id, from: target) }
            )
        }
    }

    private func labelBinding(_ itemID: UUID, in target: LauncherListTarget) -> Binding<String> {
        Binding {
            config[items: target].first(where: { $0.id == itemID })?.label ?? ""
        } set: { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            config.updateItem(id: itemID, in: target) { $0.label = trimmed.isEmpty ? nil : newValue }
        }
    }

    private func addItemMenu(to target: LauncherListTarget) -> some View {
        Menu {
            Button("App…") {
                if let bundleID = LauncherPickers.pickApp() {
                    config.append(LauncherItem(action: .app(bundleID: bundleID)), to: target)
                }
            }
            Button("Folder in App…") {
                if let action = LauncherPickers.pickFolderAction() {
                    config.append(LauncherItem(action: action), to: target)
                }
            }
            Button("URL…") {
                textEntry = LauncherTextEntryRequest(kind: .url, target: target)
            }
            Button("Apple Shortcut…") {
                textEntry = LauncherTextEntryRequest(kind: .shortcut, target: target)
            }
        } label: {
            Label("Add Item", systemImage: "plus")
        }
        .fixedSize()
    }

    /// Lets the user fix a broken item: pick the missing app again, or the moved folder.
    private func repick(_ item: LauncherItem, in target: LauncherListTarget) {
        let newAction: LauncherAction?
        switch item.action {
        case .app:
            newAction = LauncherPickers.pickApp().map { .app(bundleID: $0) }
        case .folder(let bookmark, let appBundleID):
            if case .appNotInstalled = errors[item.id] {
                newAction = LauncherPickers.pickApp(message: "Choose the app to open this folder with.")
                    .map { .folder(bookmark: bookmark, appBundleID: $0) }
            } else {
                newAction = LauncherPickers.pickFolderBookmark()
                    .map { .folder(bookmark: $0, appBundleID: appBundleID) }
            }
        case .url, .shortcut:
            newAction = nil
        }
        guard let newAction else { return }
        config.updateItem(id: item.id, in: target) { $0.action = newAction }
    }
}

// MARK: - Row

private struct LauncherItemSettingsRow: View {
    let item: LauncherItem
    let error: LauncherError?
    let isFirst: Bool
    let isLast: Bool
    @Binding var label: String
    let onMove: (Int) -> Void
    let onRepick: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            LauncherItemIcon(action: item.action)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Label", text: $label, prompt: Text(LauncherItemInfo.derivedName(for: item.action)))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                Text(LauncherItemInfo.subtitle(for: item.action))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(error.message)
                Button("Re-pick…", action: onRepick)
            }

            reorderButtons(isFirst: isFirst, isLast: isLast, onMove: onMove)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove item")
        }
    }
}

/// Icon for a launcher item: the app/folder/Shortcuts icon, or a fallback symbol (globe for URLs).
struct LauncherItemIcon: View {
    let action: LauncherAction
    /// The resolved icon; nil shows the fallback symbol.
    let image: NSImage?

    init(action: LauncherAction, image: NSImage?) {
        self.action = action
        self.image = image
    }

    /// Looks the icon up directly. Fine for Settings; the notch passes a cached image instead.
    init(action: LauncherAction) {
        self.init(action: action, image: LauncherItemInfo.icon(for: action))
    }

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: fallbackSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }

    private var fallbackSymbol: String {
        switch action {
        case .app: return "app.dashed"
        case .folder: return "folder"
        case .url: return "globe"
        case .shortcut: return "square.2.layers.3d"
        }
    }
}

@MainActor
private func reorderButtons(isFirst: Bool, isLast: Bool, onMove: @escaping (Int) -> Void) -> some View {
    HStack(spacing: 2) {
        Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
            .disabled(isFirst)
            .help("Move up")
        Button { onMove(1) } label: { Image(systemName: "chevron.down") }
            .disabled(isLast)
            .help("Move down")
    }
    .buttonStyle(.borderless)
}

// MARK: - URL / Shortcut entry

private struct LauncherTextEntryRequest: Identifiable {
    enum Kind { case url, shortcut }
    let id = UUID()
    let kind: Kind
    let target: LauncherListTarget
}

private struct LauncherTextEntrySheet: View {
    let kind: LauncherTextEntryRequest.Kind
    let onAdd: (LauncherAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var showsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == .url ? "Add URL" : "Add Apple Shortcut")
                .font(.headline)
            TextField(
                kind == .url ? "URL" : "Shortcut name",
                text: $text,
                prompt: Text(kind == .url ? "https://…" : "Exact name in the Shortcuts app")
            )
            .labelsHidden()
            .frame(width: 320)
            .onSubmit(add)
            .onChange(of: text) { showsError = false }

            if showsError {
                Text(kind == .url ? "Enter a full URL, e.g. https://…" : "Enter the Shortcut's name.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func add() {
        let action: LauncherAction?
        switch kind {
        case .url:
            action = LauncherPickers.parseURL(text).map { .url($0) }
        case .shortcut:
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            action = name.isEmpty ? nil : .shortcut(name: name)
        }
        guard let action else {
            showsError = true
            return
        }
        onAdd(action)
        dismiss()
    }
}

#Preview {
    LauncherSettingsView()
        .formStyle(.grouped)
        .frame(width: 600, height: 600)
}
