//
//  ClipboardSettingsView.swift
//  boringNotch
//

import Defaults
import SwiftUI

/// Settings pane for the Clipboard tab: on/off and history size.
struct ClipboardSettingsView: View {
    @Default(.clipboardHistoryLimit) private var historyLimit
    @ObservedObject private var clipboard = ClipboardViewModel.shared

    static let limitRange = 10...500

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showClipboardTab) {
                    Text("Show Clipboard tab")
                }
            } header: {
                Text("General")
            } footer: {
                Text("When the tab is off, MyNotch stops reading the clipboard.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Stepper(value: limitBinding, in: Self.limitRange, step: 10) {
                    HStack {
                        Text("Keep up to")
                        Spacer()
                        Text("\(historyLimit) items")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                LabeledContent("Saved now", value: clipboard.entries.count == 1 ? "1 item" : "\(clipboard.entries.count) items")
            } header: {
                Text("History")
            } footer: {
                Text("Lowering the limit removes the oldest items right away. Copies from password managers and the Passwords app are never saved.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Clipboard")
    }

    /// Clamps values written by older builds or by hand into the allowed range.
    private var limitBinding: Binding<Int> {
        Binding {
            min(max(historyLimit, Self.limitRange.lowerBound), Self.limitRange.upperBound)
        } set: { newValue in
            historyLimit = min(max(newValue, Self.limitRange.lowerBound), Self.limitRange.upperBound)
        }
    }
}

#Preview {
    ClipboardSettingsView()
        .formStyle(.grouped)
        .frame(width: 600, height: 400)
}
