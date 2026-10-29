//
//  BoringNotchXPCHelper+MissionControl.swift
//  BoringNotchXPCHelper
//
//  Tells MyNotch whether Mission Control is showing, so the notch stays closed then.
//  There's no public API for this. While Mission Control is open, the Dock's Accessibility
//  tree has a child with the identifier "mc" (the same signal Hammerspoon and others use).
//  Needs Accessibility, so it lives in the non-sandboxed helper.
//

import AppKit
import ApplicationServices
import os

extension BoringNotchXPCHelper {
    private static let missionControlLogger = Logger(subsystem: "com.mustafaozkaya.mynotch", category: "MissionControl")
    private static let missionControlIdentifier = "mc"

    @objc func isMissionControlActive(with reply: @escaping (Bool) -> Void) {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            reply(false)
            return
        }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockElement, 0.2)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            reply(false)
            return
        }
        let identifiers = children.compactMap { child -> String? in
            var identifier: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXIdentifierAttribute as CFString, &identifier) == .success else { return nil }
            return identifier as? String
        }
        let active = identifiers.contains(Self.missionControlIdentifier)
        Self.missionControlLogger.debug("Dock children \(identifiers, privacy: .public), Mission Control active: \(active, privacy: .public)")
        reply(active)
    }
}
