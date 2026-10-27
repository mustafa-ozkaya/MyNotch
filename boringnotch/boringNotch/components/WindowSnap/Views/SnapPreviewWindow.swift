//
//  SnapPreviewWindow.swift
//  boringNotch
//
//  Translucent rectangle showing where the dragged window will go.
//

import AppKit

@MainActor
final class SnapPreviewWindow {
    private lazy var panel: NSPanel = makePanel()
    private var isShown = false

    /// Shows the preview at `frame` (screen coordinates), animating if it's already visible.
    func show(_ frame: CGRect) {
        if isShown {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            isShown = true
            panel.setFrame(frame, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Shown again while fading out: keep it on screen.
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),  // resized on show
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        // Just below the notch window (`.mainMenu + 3`), so the open notch stays on top.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = SnapPreviewView()
        return panel
    }
}

/// Frosted glass with a faint light border, like macOS's own tiling preview.
private final class SnapPreviewView: NSView {
    private static let inset: CGFloat = 6
    private static let cornerRadius: CGFloat = 16

    private let glass = NSVisualEffectView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = Self.cornerRadius
        glass.layer?.cornerCurve = .continuous
        glass.layer?.masksToBounds = true
        glass.layer?.borderWidth = 1
        glass.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        glass.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        glass.autoresizingMask = [.width, .height]
        glass.frame = bounds.insetBy(dx: Self.inset, dy: Self.inset)
        addSubview(glass)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
