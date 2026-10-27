//
//  WindowDragDetector.swift
//  boringNotch
//
//  Notices when another app's window is dragged by its title bar into a notch region.
//  Separate from the shelf's `DragDetector`, which only reacts to pasteboard drags
//  (files, text), so the two never fire for the same gesture.
//

import AppKit

@MainActor
final class WindowDragDetector {
    // MARK: - Callbacks

    /// The dragged window entered the notch region of the screen with this ID.
    var onEnterNotch: ((_ screenID: String) -> Void)?
    /// The dragged window left the notch region it was in.
    var onExitNotch: (() -> Void)?
    /// Every mouse move while a window drag is confirmed (screen coordinates).
    var onMove: ((_ point: CGPoint) -> Void)?
    /// Released inside a notch region. The receiver owns `window` and must release it
    /// (`XPCHelperClient.releaseWindow`) once it's done resizing.
    var onDrop: ((_ point: CGPoint, _ screenID: String, _ window: SnapWindowHandle) -> Void)?
    /// A confirmed window drag ended outside every notch region.
    var onCancel: (() -> Void)?

    /// Where a dropped window opens the snap panel, one per screen with a notch window.
    var notchRegions: [SnapNotchRegion] = [] {
        didSet { updateRegion() }
    }

    private(set) var isMonitoring = false

    // MARK: - State

    private enum Phase {
        case idle
        /// Waiting for the helper to say which window, if any, is under the mouse-down point.
        case lookingUp
        /// A title bar was clicked; waiting for the window to actually move.
        case candidate(SnapWindowHandle)
        /// The window is being dragged.
        case confirmed(SnapWindowHandle)
        /// Not a window drag (content area, resize, helper error). Wait for mouse-up.
        case ignored
    }

    private var phase: Phase = .idle
    /// Increases with every mouse-down, so replies from an earlier gesture are dropped.
    private var gesture = 0
    private var currentRegion: SnapNotchRegion?
    private var frameCheckInFlight = false
    private var lastFrameCheck: ContinuousClock.Instant?
    /// How often to ask the helper for the window's frame until the move is confirmed.
    private let frameCheckInterval: Duration = .milliseconds(50)

    private var monitors: [Any] = []
    private let helper = XPCHelperClient.shared

    // MARK: - Start / stop

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        // Global monitors only see events sent to other apps, so MyNotch's own windows never start a drag.
        let handlers: [(NSEvent.EventTypeMask, @MainActor () -> Void)] = [
            (.leftMouseDown, { [weak self] in self?.mouseDown() }),
            (.leftMouseDragged, { [weak self] in self?.mouseDragged() }),
            (.leftMouseUp, { [weak self] in self?.mouseUp() }),
        ]
        monitors = handlers.compactMap { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask) { _ in
                MainActor.assumeIsolated { handler() }
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        if case .confirmed = phase {
            onCancel?()
        }
        reset()
    }

    // MARK: - Events

    private func mouseDown() {
        reset()
        gesture += 1
        let thisGesture = gesture
        phase = .lookingUp

        guard let axPoint = Self.axPoint(NSEvent.mouseLocation) else {
            phase = .ignored
            return
        }
        Task { [weak self] in
            let handle = await XPCHelperClient.shared.windowUnderPoint(axPoint)
            guard let self, self.gesture == thisGesture, case .lookingUp = self.phase else {
                // The gesture ended (or a new one started) before the helper replied.
                if let handle { XPCHelperClient.shared.releaseWindow(handle) }
                return
            }
            self.phase = handle.map(Phase.candidate) ?? .ignored
        }
    }

    private func mouseDragged() {
        switch phase {
        case .candidate(let handle):
            checkWhetherWindowMoved(handle)
        case .confirmed:
            let point = NSEvent.mouseLocation
            onMove?(point)
            updateRegion(at: point)
        case .idle, .lookingUp, .ignored:
            break
        }
    }

    private func mouseUp() {
        let point = NSEvent.mouseLocation
        switch phase {
        case .confirmed(let handle):
            updateRegion(at: point)
            if let region = currentRegion {
                phase = .idle  // ownership of `handle` passes to onDrop
                currentRegion = nil
                onDrop?(point, region.screenID, handle)
            } else {
                onCancel?()
            }
        case .idle, .lookingUp, .candidate, .ignored:
            break
        }
        reset()
    }

    // MARK: - Helpers

    /// Asks the helper for the window's frame (throttled) and confirms the drag once it has moved.
    private func checkWhetherWindowMoved(_ handle: SnapWindowHandle) {
        let now = ContinuousClock.now
        if frameCheckInFlight { return }
        if let last = lastFrameCheck, now - last < frameCheckInterval { return }
        frameCheckInFlight = true
        lastFrameCheck = now
        let thisGesture = gesture

        Task { [weak self] in
            let frame = await XPCHelperClient.shared.windowFrame(handle)
            guard let self, self.gesture == thisGesture,
                  case .candidate(let current) = self.phase, current == handle else { return }
            self.frameCheckInFlight = false

            guard let frame else {
                self.ignore(handle)  // window closed, or the helper went away
                return
            }
            if SnapGeometry.isResize(startFrame: handle.frame, currentFrame: frame) {
                self.ignore(handle)  // dragging the top edge resizes the window
            } else if SnapGeometry.isWindowDrag(startFrame: handle.frame, currentFrame: frame) {
                self.phase = .confirmed(handle)
                let point = NSEvent.mouseLocation
                self.onMove?(point)
                self.updateRegion(at: point)
            }
        }
    }

    private func ignore(_ handle: SnapWindowHandle) {
        helper.releaseWindow(handle)
        phase = .ignored
    }

    /// Reports entering or leaving a notch region during a confirmed drag.
    private func updateRegion(at point: CGPoint = NSEvent.mouseLocation) {
        guard case .confirmed = phase else { return }
        let region = SnapGeometry.notchRegion(at: point, current: currentRegion, in: notchRegions)
        guard region != currentRegion else { return }
        if currentRegion != nil {
            onExitNotch?()
        }
        currentRegion = region
        if let region {
            onEnterNotch?(region.screenID)
        }
    }

    /// Back to idle, releasing any window the helper is still holding for this gesture.
    private func reset() {
        switch phase {
        case .candidate(let handle), .confirmed(let handle):
            helper.releaseWindow(handle)
        case .idle, .lookingUp, .ignored:
            break
        }
        phase = .idle
        currentRegion = nil
        frameCheckInFlight = false
        lastFrameCheck = nil
    }

    /// Cocoa screen point → Accessibility point (top-left origin of the primary screen).
    private static func axPoint(_ point: CGPoint) -> CGPoint? {
        guard let primary = NSScreen.screens.first else { return nil }
        return CGPoint(x: point.x, y: primary.frame.height - point.y)
    }
}
