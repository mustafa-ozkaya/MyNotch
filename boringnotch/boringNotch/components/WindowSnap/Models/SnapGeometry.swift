//
//  SnapGeometry.swift
//  boringNotch
//

import CoreGraphics

/// Coordinate conversion and hit-testing for window snapping. Pure functions, unit-tested.
enum SnapGeometry {
    /// Minimum distance the window's origin must move before a drag counts as a window move.
    static let minimumDragDistance: CGFloat = 4
    /// Size changes below this are treated as rounding noise, not a resize.
    static let sizeTolerance: CGFloat = 1

    /// Converts a Cocoa rect (bottom-left origin, y up) to an Accessibility rect
    /// (top-left origin of the primary screen, y down).
    static func axRect(fromCocoa rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Inverse of `axRect(fromCocoa:primaryScreenHeight:)`.
    static func cocoaRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The snap target under the cursor, if any. `zones` are in screen coordinates.
    static func zone(at point: CGPoint, zones: [SnapLayout: CGRect]) -> SnapLayout? {
        SnapLayout.allCases.first { zones[$0]?.contains(point) == true }
    }

    /// True if the window was moved (not resized): its origin moved far enough and its size stayed the same.
    static func isWindowDrag(startFrame: CGRect, currentFrame: CGRect) -> Bool {
        let sizeUnchanged = abs(startFrame.width - currentFrame.width) <= sizeTolerance
            && abs(startFrame.height - currentFrame.height) <= sizeTolerance
        let distance = hypot(currentFrame.minX - startFrame.minX, currentFrame.minY - startFrame.minY)
        return sizeUnchanged && distance >= minimumDragDistance
    }

    /// True if the final frame is within `tolerance` points of the target on every edge.
    static func frameMatches(_ actual: CGRect, target: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }
}
