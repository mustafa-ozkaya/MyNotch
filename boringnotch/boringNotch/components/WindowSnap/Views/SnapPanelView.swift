//
//  SnapPanelView.swift
//  boringNotch
//
//  The notch content while a window is dragged in: one target per layout.
//

import AppKit
import SwiftUI

struct SnapPanelView: View {
    @ObservedObject private var snap = WindowSnapViewModel.shared

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(SnapLayout.allCases) { layout in
                    SnapTarget(layout: layout, isHovered: snap.hoveredLayout == layout)
                }
            }
            .opacity(snap.showsResizeFailure ? 0.15 : 1)

            if snap.showsResizeFailure {
                Label("Couldn't resize this window", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: snap.hoveredLayout)
        .animation(.smooth(duration: 0.2), value: snap.showsResizeFailure)
    }
}

private struct SnapTarget: View {
    let layout: SnapLayout
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 10) {
            ScreenDrawing(layout: layout, isHovered: isHovered)
                .frame(width: 104, height: 64)
                .scaleEffect(isHovered ? 1.08 : 1)
                .shadow(color: .white.opacity(isHovered ? 0.18 : 0), radius: 10)
            Text(layout.label)
                .font(.system(size: 12, weight: isHovered ? .semibold : .medium, design: .rounded))
                .foregroundStyle(.white.opacity(isHovered ? 0.95 : 0.45))
        }
        // The whole column is the drop target, so there are only small gaps between targets.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .background(SnapZoneReader(layout: layout))
    }
}

/// A miniature screen with the layout's area filled in.
private struct ScreenDrawing: View {
    let layout: SnapLayout
    let isHovered: Bool

    var body: some View {
        GeometryReader { geometry in
            let screen = CGRect(origin: .zero, size: geometry.size)
            let area = layout.frame(in: screen.insetBy(dx: 5, dy: 5))
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(isHovered ? 0.08 : 0.04))
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(.white.opacity(isHovered ? 0.5 : 0.18), lineWidth: 1.2)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(isHovered ? 0.85 : 0.22))
                    .frame(width: area.width, height: area.height)
                    .offset(x: area.minX, y: area.minY)
            }
        }
    }
}

/// Registers its on-screen frame with the view model, so drops are hit-tested against
/// where the target actually is.
private struct SnapZoneReader: NSViewRepresentable {
    let layout: SnapLayout

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        WindowSnapViewModel.shared.register(view, for: layout)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        MainActor.assumeIsolated {
            for layout in SnapLayout.allCases {
                WindowSnapViewModel.shared.unregister(nsView, for: layout)
            }
        }
    }
}
