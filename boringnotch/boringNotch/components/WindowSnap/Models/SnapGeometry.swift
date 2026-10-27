//
//  SnapGeometry.swift
//  boringNotch
//

import CoreGraphics

/// Where a dragged window opens the snap panel on one screen. Screen coordinates (Cocoa, bottom-left origin).
struct SnapNotchRegion: Equatable {
    /// `NSScreen.displayUUID` of the screen the region belongs to.
    let screenID: String
    /// Small area that opens the panel: the physical notch (where the cursor disappears),
    /// or a notch-sized strip at the top of screens without one.
    let triggerRect: CGRect
    /// Area of the open panel. Once open, the panel stays open while the cursor is in here.
    let rect: CGRect
}

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
        let distance = hypot(currentFrame.minX - startFrame.minX, currentFrame.minY - startFrame.minY)
        return !isResize(startFrame: startFrame, currentFrame: currentFrame) && distance >= minimumDragDistance
    }

    /// True if the window's size changed, i.e. the gesture is resizing it rather than moving it.
    static func isResize(startFrame: CGRect, currentFrame: CGRect) -> Bool {
        abs(startFrame.width - currentFrame.width) > sizeTolerance
            || abs(startFrame.height - currentFrame.height) > sizeTolerance
    }

    /// The notch region the cursor is in after moving to `point`. Entering needs the small trigger
    /// area; once in, the region lasts until the cursor leaves its (larger) panel area.
    static func notchRegion(at point: CGPoint, current: SnapNotchRegion?, in regions: [SnapNotchRegion]) -> SnapNotchRegion? {
        if let current, containsIncludingTopEdge(current.rect, point) {
            return current
        }
        return regions.first { containsIncludingTopEdge($0.triggerRect, point) }
    }

    /// `CGRect.contains` leaves out the top edge, but a cursor pushed against the top of the
    /// screen sits exactly on it (y == screen maxY), which made a still cursor count as outside.
    private static func containsIncludingTopEdge(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }

    /// True if the final frame is within `tolerance` points of the target on every edge.
    static func frameMatches(_ actual: CGRect, target: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }
}
