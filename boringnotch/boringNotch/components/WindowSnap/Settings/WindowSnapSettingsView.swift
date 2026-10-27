//
//  WindowSnapSettingsView.swift
//  boringNotch
//

import AppKit
import Defaults
import SwiftUI

/// Settings pane for window snapping: on/off, Accessibility status and tips.
struct WindowSnapSettingsView: View {
    @Default(.windowSnappingEnabled) private var enabled
    @Default(.showOnAllDisplays) private var showOnAllDisplays
    @State private var accessibilityGranted: Bool?

    /// How often the status row re-checks Accessibility while this pane is open, so granting it
    /// in System Settings shows up here without reopening the pane.
    private let statusRefreshInterval: Duration = .seconds(2)

    var body: some View {
        Form {
            Section {
                Toggle("Enable window snapping", isOn: $enabled)
                    .onChange(of: enabled) { _, isOn in
                        guard isOn else { return }
                        Task {
                            accessibilityGranted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                        }
                    }
            } header: {
                Text("General")
            } footer: {
                Text("Drag a window by its title bar up into the notch, then drop it on Left Half, Fill or Right Half.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Accessibility") {
                    HStack(spacing: 6) {
                        if let accessibilityGranted {
                            Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(accessibilityGranted ? .green : .orange)
                            Text(accessibilityGranted ? "Granted" : "Not granted")
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                if accessibilityGranted == false {
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("MyNotch needs Accessibility to move and resize other apps' windows. Snapping starts as soon as it's granted.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("If macOS opens Mission Control when you drag to the top of the screen, turn off “Drag windows to top of screen to enter Mission Control” in System Settings › Desktop & Dock. It affects dragging files to the shelf too.")
                if !showOnAllDisplays {
                    Text("Snapping works on the main notch display only. Turn on Show on all displays to snap on other screens.")
                }
            } header: {
                Text("Tips")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Window Snapping")
        .task {
            while !Task.isCancelled {
                accessibilityGranted = await XPCHelperClient.shared.isAccessibilityAuthorized()
                try? await Task.sleep(for: statusRefreshInterval)
            }
        }
    }
}

#Preview {
    WindowSnapSettingsView()
        .formStyle(.grouped)
        .frame(width: 600, height: 500)
}
