//
//  SnapGeometryTests.swift
//  MyNotchTests
//

import CoreGraphics
import Testing
@testable import boringNotch

struct SnapLayoutTests {
    /// A MacBook-like screen: 1512 x 982 with a 37 pt menu bar and a 70 pt Dock at the bottom.
    let visibleFrame = CGRect(x: 0, y: 70, width: 1512, height: 875)

    @Test func fillIsTheWholeVisibleFrame() {
        #expect(SnapLayout.fill.frame(in: visibleFrame).equalTo(visibleFrame))
    }

    @Test(arguments: [1512.0, 1511.0, 2560.0, 1679.0])
    func halvesCoverTheFrameWithoutGapOrOverlap(width: CGFloat) {
        let frame = CGRect(x: 100, y: 70, width: width, height: 875)
        let left = SnapLayout.leftHalf.frame(in: frame)
        let right = SnapLayout.rightHalf.frame(in: frame)

        #expect(left.minX == frame.minX)
        #expect(left.maxX == right.minX)
        #expect(right.maxX == frame.maxX)
        #expect(left.width + right.width == frame.width)
        #expect(left.width == left.width.rounded())
        #expect(left.minY == frame.minY && left.height == frame.height)
        #expect(right.minY == frame.minY && right.height == frame.height)
    }

    @Test func halvesNeverCoverTheMenuBarOrDock() {
        for layout in SnapLayout.allCases {
            let frame = layout.frame(in: visibleFrame)
            #expect(frame.minY >= visibleFrame.minY)
            #expect(frame.maxY <= visibleFrame.maxY)
        }
    }
}

struct SnapGeometryTests {
    let primaryHeight: CGFloat = 982

    @Test func primaryScreenRectConvertsToTopLeftOrigin() {
        // Left half of the visible area above: Cocoa y=70 (bottom) up to 945 (below the menu bar).
        let cocoa = CGRect(x: 0, y: 70, width: 756, height: 875)
        let ax = SnapGeometry.axRect(fromCocoa: cocoa, primaryScreenHeight: primaryHeight)
        #expect(ax.equalTo(CGRect(x: 0, y: 37, width: 756, height: 875)))
    }

    @Test func screenAbovePrimaryHasNegativeAXY() {
        // External display placed above the MacBook: Cocoa y from 982 to 2422.
        let cocoa = CGRect(x: -200, y: 982, width: 2560, height: 1440)
        let ax = SnapGeometry.axRect(fromCocoa: cocoa, primaryScreenHeight: primaryHeight)
        #expect(ax.equalTo(CGRect(x: -200, y: -1440, width: 2560, height: 1440)))
    }

    @Test func screenBelowPrimaryHasAXYBeyondPrimaryHeight() {
        let cocoa = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        let ax = SnapGeometry.axRect(fromCocoa: cocoa, primaryScreenHeight: primaryHeight)
        #expect(ax.equalTo(CGRect(x: 0, y: 982, width: 1920, height: 1080)))
    }

    @Test func conversionRoundTrips() {
        let cocoa = CGRect(x: 37, y: 120.5, width: 800, height: 600)
        let ax = SnapGeometry.axRect(fromCocoa: cocoa, primaryScreenHeight: primaryHeight)
        #expect(SnapGeometry.cocoaRect(fromAX: ax, primaryScreenHeight: primaryHeight).equalTo(cocoa))
    }

    let zones: [SnapLayout: CGRect] = [
        .leftHalf: CGRect(x: 600, y: 900, width: 100, height: 60),
        .fill: CGRect(x: 710, y: 900, width: 100, height: 60),
        .rightHalf: CGRect(x: 820, y: 900, width: 100, height: 60),
    ]

    @Test func zoneUnderTheCursorIsFound() {
        #expect(SnapGeometry.zone(at: CGPoint(x: 650, y: 930), zones: zones) == .leftHalf)
        #expect(SnapGeometry.zone(at: CGPoint(x: 760, y: 930), zones: zones) == .fill)
        #expect(SnapGeometry.zone(at: CGPoint(x: 870, y: 930), zones: zones) == .rightHalf)
    }

    @Test func gapsAndOutsideHaveNoZone() {
        #expect(SnapGeometry.zone(at: CGPoint(x: 705, y: 930), zones: zones) == nil)
        #expect(SnapGeometry.zone(at: CGPoint(x: 760, y: 100), zones: zones) == nil)
        #expect(SnapGeometry.zone(at: CGPoint(x: 760, y: 930), zones: [:]) == nil)
    }

    let start = CGRect(x: 100, y: 100, width: 800, height: 600)

    @Test func movedWindowIsADrag() {
        #expect(SnapGeometry.isWindowDrag(startFrame: start, currentFrame: start.offsetBy(dx: 30, dy: -12)))
    }

    @Test func tinyMovementIsNotADrag() {
        #expect(!SnapGeometry.isWindowDrag(startFrame: start, currentFrame: start.offsetBy(dx: 2, dy: 2)))
    }

    @Test func resizeIsNotADrag() {
        // Dragging the left edge moves the origin and changes the width.
        let resized = CGRect(x: 60, y: 100, width: 840, height: 600)
        #expect(!SnapGeometry.isWindowDrag(startFrame: start, currentFrame: resized))
    }

    @Test func resizeIsDetectedAndMoveIsNot() {
        #expect(SnapGeometry.isResize(startFrame: start, currentFrame: CGRect(x: 100, y: 60, width: 800, height: 640)))
        #expect(!SnapGeometry.isResize(startFrame: start, currentFrame: start.offsetBy(dx: 200, dy: 50)))
        // Sub-point rounding from some apps isn't a resize.
        #expect(!SnapGeometry.isResize(startFrame: start, currentFrame: CGRect(x: 140, y: 100, width: 800.5, height: 599.5)))
    }

    let regions = [
        SnapNotchRegion(screenID: "main", rect: CGRect(x: 456, y: 782, width: 600, height: 200)),
        // External display to the right of the main one.
        SnapNotchRegion(screenID: "external", rect: CGRect(x: 2492, y: 1240, width: 600, height: 200)),
    ]

    @Test func notchRegionUnderThePointIsFound() {
        #expect(SnapGeometry.notchRegion(at: CGPoint(x: 756, y: 950), in: regions)?.screenID == "main")
        #expect(SnapGeometry.notchRegion(at: CGPoint(x: 2800, y: 1400), in: regions)?.screenID == "external")
    }

    @Test func pointsOutsideEveryNotchRegionHaveNone() {
        #expect(SnapGeometry.notchRegion(at: CGPoint(x: 756, y: 500), in: regions) == nil)
        #expect(SnapGeometry.notchRegion(at: CGPoint(x: 100, y: 950), in: regions) == nil)
        #expect(SnapGeometry.notchRegion(at: CGPoint(x: 756, y: 950), in: []) == nil)
    }

    @Test func frameMatchToleratesSmallDifferences() {
        let target = CGRect(x: 0, y: 37, width: 756, height: 875)
        #expect(SnapGeometry.frameMatches(CGRect(x: 1, y: 38, width: 755, height: 874), target: target))
        // An app with a minimum width that couldn't shrink to the target.
        #expect(!SnapGeometry.frameMatches(CGRect(x: 0, y: 37, width: 900, height: 875), target: target))
    }
}
