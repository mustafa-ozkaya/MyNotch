//
//  WindowSnapController.swift
//  boringNotch
//
//  Runs the window drag detector while "Enable window snapping" is on and Accessibility is
//  granted, and stops it otherwise. Forwards (and logs) its events to `WindowSnapViewModel`.
//

import AppKit
import Defaults
import os

@MainActor
final class WindowSnapController {
    static let shared = WindowSnapController()

    private let detector = WindowDragDetector()
    private let logger = Logger(subsystem: "com.mustafaozkaya.mynotch", category: "WindowSnap")
    private var settingsTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    /// How often to re-check Accessibility while snapping is enabled, so granting or revoking it
    /// in System Settings starts or stops the detector without a relaunch. The app's shared
    /// monitor (`startMonitoringAccessibilityAuthorization`) only runs while the HUD settings
    /// page is open, so it can't be relied on here.
    private let authorizationCheckInterval: Duration = .seconds(3)

    private init() {
        let snap = WindowSnapViewModel.shared
        detector.onEnterNotch = { [logger] screenID in
            logger.notice("window drag entered notch on screen \(screenID, privacy: .public)")
            snap.dragEntered(screenID: screenID)
        }
        detector.onMove = { point in
            snap.dragMoved(to: point)
        }
        detector.onExitNotch = { [logger] in
            logger.notice("window drag exited notch")
            snap.dragExited()
        }
        detector.onDrop = { [logger] point, screenID, window in
            logger.notice("window dropped in notch on screen \(screenID, privacy: .public) at \(point.debugDescription, privacy: .public), window frame \(window.frame.debugDescription, privacy: .public)")
            snap.dropped(at: point, window: window)
        }
        detector.onCancel = { [logger] in
            logger.notice("window drag ended outside the notch")
            snap.dragCancelled()
        }
    }

    /// Starts following the "Enable window snapping" setting. Call once at launch.
    func activate() {
        guard settingsTask == nil else { return }
        settingsTask = Task { [weak self] in
            for await enabled in Defaults.updates(.windowSnappingEnabled) {
                self?.setEnabled(enabled)
            }
        }
    }

    /// Notch regions to watch, rebuilt by the app delegate whenever screens or notch windows change.
    func setNotchRegions(_ regions: [SnapNotchRegion]) {
        detector.notchRegions = regions
    }

    private func setEnabled(_ enabled: Bool) {
        authorizationTask?.cancel()
        authorizationTask = nil
        guard enabled else {
            setRunning(false)
            return
        }
        authorizationTask = Task { [weak self] in
            while !Task.isCancelled {
                let authorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
                guard !Task.isCancelled, let self else { return }
                self.setRunning(authorized)
                try? await Task.sleep(for: self.authorizationCheckInterval)
            }
        }
    }

    private func setRunning(_ running: Bool) {
        guard running != detector.isMonitoring else { return }
        if running {
            detector.startMonitoring()
        } else {
            detector.stopMonitoring()
        }
        logger.notice("window drag detection \(running ? "started" : "stopped", privacy: .public)")
    }
}
