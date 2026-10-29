//
//  WindowSnapViewModel.swift
//  boringNotch
//
//  Drives the snap panel: opens the notch when a dragged window enters it, tracks which
//  target the cursor is over, shows the preview, and resizes the window on drop.
//

import AppKit
import SwiftUI

@MainActor
final class WindowSnapViewModel: ObservableObject {
    static let shared = WindowSnapViewModel()

    @Published private(set) var isActive = false
    @Published private(set) var hoveredLayout: SnapLayout?
    /// True briefly when a window couldn't be resized, so the panel says so before closing.
    @Published private(set) var showsResizeFailure = false

    /// Looks up the notch view model for a screen ID; set by the app delegate.
    var notchViewModel: ((_ screenID: String) -> BoringViewModel?)?

    /// True for a moment after a snap, so the notch doesn't reopen on hover under the cursor
    /// the user just released.
    private(set) var suppressesHoverOpen = false

    private var targetScreenID: String?
    private var targetNotch: BoringViewModel?
    private var previousView: NotchViews = .home
    private var exitTask: Task<Void, Never>?
    private var resizeTask: Task<Void, Never>?
    private var zoneViews: [SnapLayout: WeakView] = [:]
    private let preview = SnapPreviewWindow()
    private let coordinator = BoringViewCoordinator.shared

    /// Moving along the notch region's edge reports exit/enter in quick succession; wait this
    /// long after an exit before closing, so the panel doesn't flicker.
    private let exitDelay: Duration = .milliseconds(250)
    /// Lets macOS finish its own handling of the drop before the window is moved.
    private let resizeDelay: Duration = .milliseconds(100)
    private let failureMessageDuration: Duration = .milliseconds(1500)
    private let hoverSuppression: Duration = .seconds(1)

    private init() {}

    // MARK: - Detector events

    func dragEntered(screenID: String) {
        exitTask?.cancel()
        exitTask = nil
        guard resizeTask == nil else { return }
        if isActive, targetScreenID == screenID { return }
        if isActive { deactivate() }  // moved straight from one screen's notch to another's

        guard let notch = notchViewModel?(screenID) else { return }
        if coordinator.currentView != .windowSnap {
            previousView = coordinator.currentView
        }
        targetScreenID = screenID
        targetNotch = notch
        isActive = true
        coordinator.currentView = .windowSnap
        // Snappier than the notch's usual open spring (0.42 s): the user is mid-drag, waiting on it.
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            notch.open()
        }
    }

    func dragMoved(to point: CGPoint) {
        guard isActive, resizeTask == nil else { return }
        let layout = SnapGeometry.zone(at: point, zones: zoneFrames())
        guard layout != hoveredLayout else { return }
        hoveredLayout = layout
        if let layout, let screen = targetScreen {
            preview.show(layout.frame(in: screen.visibleFrame))
        } else {
            preview.hide()
        }
    }

    func dragExited() {
        guard isActive, resizeTask == nil else { return }
        exitTask?.cancel()
        exitTask = Task { [weak self, exitDelay] in
            try? await Task.sleep(for: exitDelay)
            guard !Task.isCancelled else { return }
            self?.deactivate()
        }
    }

    /// The detector hands over `window`; it's released here once the resize is done.
    func dropped(at point: CGPoint, window: SnapWindowHandle) {
        exitTask?.cancel()
        exitTask = nil
        guard resizeTask == nil else {
            XPCHelperClient.shared.releaseWindow(window)
            return
        }
        guard isActive,
              let layout = SnapGeometry.zone(at: point, zones: zoneFrames()),
              let screen = targetScreen,
              let primary = NSScreen.screens.first else {
            // Released in a gap between targets (or the panel never opened): nothing changes.
            XPCHelperClient.shared.releaseWindow(window)
            deactivate()
            return
        }

        hoveredLayout = layout
        let target = SnapGeometry.axRect(
            fromCocoa: layout.frame(in: screen.visibleFrame),
            primaryScreenHeight: primary.frame.height
        )
        resizeTask = Task { [weak self, resizeDelay, failureMessageDuration] in
            try? await Task.sleep(for: resizeDelay)
            let final = await XPCHelperClient.shared.setWindowFrame(window, to: target)
            XPCHelperClient.shared.releaseWindow(window)
            guard let self else { return }

            let matched = final.map { SnapGeometry.frameMatches($0, target: target) } ?? false
            if !matched {
                // Fixed-size or minimum-size windows: the app clamps the frame. No retry.
                self.preview.hide()
                self.showsResizeFailure = true
                try? await Task.sleep(for: failureMessageDuration)
            }
            self.resizeTask = nil
            self.deactivate()
        }
    }

    func dragCancelled() {
        exitTask?.cancel()
        exitTask = nil
        guard resizeTask == nil else { return }
        deactivate()
    }

    // MARK: - Zones

    /// Called by each target in the panel so hit-testing uses its real on-screen frame.
    func register(_ view: NSView, for layout: SnapLayout) {
        zoneViews[layout] = WeakView(view: view)
    }

    func unregister(_ view: NSView, for layout: SnapLayout) {
        if zoneViews[layout]?.view === view {
            zoneViews[layout] = nil
        }
    }

    private func zoneFrames() -> [SnapLayout: CGRect] {
        zoneViews.compactMapValues { weak in
            guard let view = weak.view, let window = view.window else { return nil }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
    }

    // MARK: - Helpers

    private var targetScreen: NSScreen? {
        targetScreenID.flatMap { NSScreen.screen(withUUID: $0) }
    }

    /// Closes the panel and restores the view that was showing before the drag.
    private func deactivate() {
        preview.hide()
        let wasActive = isActive
        isActive = false
        hoveredLayout = nil
        showsResizeFailure = false
        targetScreenID = nil
        guard wasActive, let notch = targetNotch else { return }
        targetNotch = nil

        // Restore first, so close() applies its usual rules (e.g. back to Home) to that view.
        if coordinator.currentView == .windowSnap {
            coordinator.currentView = previousView
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
            notch.close()
        }

        suppressesHoverOpen = true
        Task { [weak self, hoverSuppression] in
            try? await Task.sleep(for: hoverSuppression)
            self?.suppressesHoverOpen = false
        }
    }

    private struct WeakView {
        weak var view: NSView?
    }
}
