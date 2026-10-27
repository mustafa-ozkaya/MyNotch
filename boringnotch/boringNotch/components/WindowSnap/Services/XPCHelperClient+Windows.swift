//
//  XPCHelperClient+Windows.swift
//  boringNotch
//

import CoreGraphics
import Foundation

/// A window found by the helper, referred to by token in later calls.
struct SnapWindowHandle: Hashable {
    let token: Int
    /// Frame when it was found, in Accessibility coordinates (top-left origin).
    let frame: CGRect
}

/// Async wrappers for the helper's window-snapping calls. All frames are in Accessibility coordinates.
/// Main-actor isolated: the callers (drag detector, snap view model) are, and the XPC connection
/// object isn't Sendable, so staying on one actor avoids passing it across threads.
@MainActor
extension XPCHelperClient {
    func windowUnderPoint(_ point: CGPoint) async -> SnapWindowHandle? {
        do {
            let service = ensureRemoteService()
            let result: (NSNumber?, [NSNumber]?) = try await service.withContinuation { service, continuation in
                service.windowUnderPoint(Double(point.x), Double(point.y)) { token, frame in
                    continuation.resume(returning: (token, frame))
                }
            }
            guard let token = result.0, let frame = Self.rect(from: result.1) else { return nil }
            return SnapWindowHandle(token: token.intValue, frame: frame)
        } catch {
            return nil
        }
    }

    func windowFrame(_ handle: SnapWindowHandle) async -> CGRect? {
        do {
            let service = ensureRemoteService()
            let frame: [NSNumber]? = try await service.withContinuation { service, continuation in
                service.windowFrame(NSNumber(value: handle.token)) { frame in
                    continuation.resume(returning: frame)
                }
            }
            return Self.rect(from: frame)
        } catch {
            return nil
        }
    }

    /// Moves and resizes the window. Returns the frame it actually ended up with.
    func setWindowFrame(_ handle: SnapWindowHandle, to frame: CGRect) async -> CGRect? {
        do {
            let service = ensureRemoteService()
            let numbers = [frame.minX, frame.minY, frame.width, frame.height].map { NSNumber(value: Double($0)) }
            let result: [NSNumber]? = try await service.withContinuation { service, continuation in
                service.setWindowFrame(NSNumber(value: handle.token), numbers) { finalFrame in
                    continuation.resume(returning: finalFrame)
                }
            }
            return Self.rect(from: result)
        } catch {
            return nil
        }
    }

    func releaseWindow(_ handle: SnapWindowHandle) {
        let service = ensureRemoteService()
        Task {
            try? await service.withService { service in
                service.releaseWindow(NSNumber(value: handle.token))
            }
        }
    }

    private nonisolated static func rect(from numbers: [NSNumber]?) -> CGRect? {
        guard let numbers, numbers.count == 4 else { return nil }
        return CGRect(x: numbers[0].doubleValue, y: numbers[1].doubleValue,
                      width: numbers[2].doubleValue, height: numbers[3].doubleValue)
    }
}
