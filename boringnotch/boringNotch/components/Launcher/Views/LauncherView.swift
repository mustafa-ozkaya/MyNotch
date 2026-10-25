//
//  LauncherView.swift
//  boringNotch
//

import SwiftUI

/// Launcher tab: modes as large buttons above a row of single items.
struct LauncherView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var launcher = LauncherViewModel.shared

    var body: some View {
        Group {
            if launcher.config.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if !launcher.config.modes.isEmpty {
                        modesRow
                    }
                    if !launcher.config.items.isEmpty {
                        itemsRow
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            // Pick up folders deleted or apps uninstalled since the last refresh.
            launcher.refresh()
        }
    }

    private var modesRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(launcher.config.modes) { mode in
                    LauncherModeButton(
                        mode: mode,
                        isRunning: launcher.runningID == mode.id,
                        errorSummary: launcher.errorSummary(for: mode)
                    ) {
                        Task {
                            if await launcher.run(mode) { vm.close() }
                        }
                    }
                    .disabled(mode.items.isEmpty || launcher.isRunning)
                }
            }
        }
        .scrollIndicators(.never)
    }

    private var itemsRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(launcher.config.items) { item in
                    LauncherItemButton(
                        presentation: launcher.presentation(for: item),
                        action: item.action,
                        isRunning: launcher.runningID == item.id,
                        error: launcher.errors[item.id]
                    ) {
                        Task {
                            if await launcher.run(item) { vm.close() }
                        }
                    }
                    .disabled(launcher.isRunning)
                }
            }
        }
        .scrollIndicators(.never)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2")
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white, .gray)
                .imageScale(.large)
            Text("No shortcuts yet")
                .foregroundStyle(.gray)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
            Button("Open Launcher Settings") {
                SettingsWindowController.shared.showWindow(selecting: "Launcher")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.effectiveAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Buttons

private struct LauncherModeButton: View {
    let mode: LauncherMode
    let isRunning: Bool
    let errorSummary: String?
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: mode.symbol.isEmpty ? "bolt.fill" : mode.symbol)
                }
                Text(mode.name)
                    .lineLimit(1)
            }
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(Color.white.opacity(isHovering && isEnabled ? 0.2 : 0.1)))
            .opacity(isEnabled || isRunning ? 1 : 0.5)
            .overlay(alignment: .topTrailing) {
                if errorSummary != nil {
                    warningBadge
                        .offset(x: 4, y: -4)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(errorSummary ?? (mode.items.isEmpty ? "This mode has no items" : "Open \(mode.name)"))
    }
}

private struct LauncherItemButton: View {
    let presentation: LauncherItemPresentation
    let action: LauncherAction
    let isRunning: Bool
    let error: LauncherError?
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    LauncherItemIcon(action: action, image: presentation.icon)
                        .opacity(isRunning ? 0.4 : 1)
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(alignment: .bottomTrailing) {
                    if let badgeIcon = presentation.badgeIcon {
                        Image(nsImage: badgeIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .offset(x: 3, y: 3)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if error != nil {
                        warningBadge
                            .offset(x: 4, y: -4)
                    }
                }

                Text(presentation.name)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 68)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isHovering ? 0.1 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(error?.message ?? presentation.name)
    }
}

private var warningBadge: some View {
    Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 11))
        .symbolRenderingMode(.palette)
        .foregroundStyle(.black, .yellow)
}

#Preview {
    LauncherView()
        .environmentObject(BoringViewModel())
        .frame(width: 600, height: 150)
        .background(.black)
}
