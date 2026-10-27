//
//  BoringNotchXPCHelperProtocol.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation

/// The protocol that this service will vend as its API. This protocol will also need to be visible to the process hosting the service.
@objc protocol BoringNotchXPCHelperProtocol {
    func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void)
    func requestAccessibilityAuthorization()
    func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void)
    // Keyboard backlight / CoreBrightness access (performed by the helper)
    func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Screen brightness access (performed by the helper)
    func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void)
    func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    // Window snapping (MyNotch). Points and frames are in Accessibility coordinates
    // (top-left origin of the primary screen); frames are [x, y, width, height].
    /// Finds the window under a point. Replies with a token for later calls plus its frame, or nils.
    func windowUnderPoint(_ x: Double, _ y: Double, with reply: @escaping (NSNumber?, [NSNumber]?) -> Void)
    /// Current frame of a window found earlier, or nil if it's gone.
    func windowFrame(_ token: NSNumber, with reply: @escaping ([NSNumber]?) -> Void)
    /// Moves and resizes the window. Replies with the frame it actually ended up with, or nil on failure.
    func setWindowFrame(_ token: NSNumber, _ frame: [NSNumber], with reply: @escaping ([NSNumber]?) -> Void)
    /// Forgets a window token.
    func releaseWindow(_ token: NSNumber)
}

