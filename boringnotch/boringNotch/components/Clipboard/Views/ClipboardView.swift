//
//  ClipboardView.swift
//  boringNotch
//

import SwiftUI

/// Clipboard tab: copy history. Placeholder until the Clipboard tab UI step.
struct ClipboardView: View {
    var body: some View {
        EmptyStateView(message: "Clipboard history is coming soon")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ClipboardView()
        .frame(width: 600, height: 150)
        .background(.black)
}
