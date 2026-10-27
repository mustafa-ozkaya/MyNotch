//
//  BoringNotchXPCHelper+Windows.swift
//  BoringNotchXPCHelper
//
//  Window snapping for MyNotch. The sandboxed app can't control other apps' windows,
//  so the (non-sandboxed) helper does it through the Accessibility API.
//

import ApplicationServices
import Foundation

/// Windows found by `windowUnderPoint`, kept so later calls can refer to them by token.
private enum WindowRegistry {
    private static let lock = NSLock()
    private static var windows: [Int: AXUIElement] = [:]
    private static var nextToken = 1
    /// Only a handful are needed at a time (one per drag); old ones are dropped beyond this.
    private static let maxWindows = 16

    static func store(_ window: AXUIElement) -> Int {
        lock.lock(); defer { lock.unlock() }
        if windows.count >= maxWindows, let oldest = windows.keys.min() {
            windows[oldest] = nil
        }
        let token = nextToken
        nextToken += 1
        windows[token] = window
        return token
    }

    static func window(for token: Int) -> AXUIElement? {
        lock.lock(); defer { lock.unlock() }
        return windows[token]
    }

    static func remove(_ token: Int) {
        lock.lock(); defer { lock.unlock() }
        windows[token] = nil
    }
}

extension BoringNotchXPCHelper {
    /// Upper bound for each Accessibility call, so an unresponsive app can't stall a drag.
    private static let messagingTimeout: Float = 0.5

    @objc func windowUnderPoint(_ x: Double, _ y: Double, with reply: @escaping (NSNumber?, [NSNumber]?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(nil, nil)
            return
        }
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeout)

        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &hit) == .success,
              let hit,
              let window = Self.containingWindow(of: hit) else {
            reply(nil, nil)
            return
        }

        // Never snap MyNotch's own windows (the notch, Settings).
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        if let callerPID = NSXPCConnection.current()?.processIdentifier, pid == callerPID {
            reply(nil, nil)
            return
        }
        // Windows in native full screen live in their own Space and can't be moved.
        if Self.boolAttribute(window, "AXFullScreen") == true {
            reply(nil, nil)
            return
        }
        guard let frame = Self.frame(of: window) else {
            reply(nil, nil)
            return
        }
        AXUIElementSetMessagingTimeout(window, Self.messagingTimeout)
        reply(NSNumber(value: WindowRegistry.store(window)), Self.numbers(frame))
    }

    @objc func windowFrame(_ token: NSNumber, with reply: @escaping ([NSNumber]?) -> Void) {
        guard let window = WindowRegistry.window(for: token.intValue), let frame = Self.frame(of: window) else {
            reply(nil)
            return
        }
        reply(Self.numbers(frame))
    }

    @objc func setWindowFrame(_ token: NSNumber, _ frame: [NSNumber], with reply: @escaping ([NSNumber]?) -> Void) {
        guard frame.count == 4, let window = WindowRegistry.window(for: token.intValue) else {
            reply(nil)
            return
        }
        let target = CGRect(x: frame[0].doubleValue, y: frame[1].doubleValue,
                            width: frame[2].doubleValue, height: frame[3].doubleValue)

        // Position, then size, then position again: some apps clamp the new size against the
        // old position (e.g. it would go off-screen), so the second move puts it in place.
        Self.setPosition(target.origin, of: window)
        Self.setSize(target.size, of: window)
        Self.setPosition(target.origin, of: window)

        reply(Self.frame(of: window).map(Self.numbers))
    }

    @objc func releaseWindow(_ token: NSNumber) {
        WindowRegistry.remove(token.intValue)
    }

    // MARK: - Accessibility helpers

    /// The window an element belongs to (the element itself if it is a window).
    private static func containingWindow(of element: AXUIElement) -> AXUIElement? {
        if stringAttribute(element, kAXRoleAttribute) == (kAXWindowRole as String) {
            return element
        }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            return (value as! AXUIElement)
        }
        // Some elements don't report their window; walk up the parents instead.
        var current = element
        for _ in 0..<32 {
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            current = parent as! AXUIElement
            if stringAttribute(current, kAXRoleAttribute) == (kAXWindowRole as String) {
                return current
            }
        }
        return nil
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func setPosition(_ point: CGPoint, of window: AXUIElement) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func setSize(_ size: CGSize, of window: AXUIElement) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return (value as? NSNumber)?.boolValue
    }

    private static func numbers(_ rect: CGRect) -> [NSNumber] {
        [rect.minX, rect.minY, rect.width, rect.height].map { NSNumber(value: Double($0)) }
    }
}
