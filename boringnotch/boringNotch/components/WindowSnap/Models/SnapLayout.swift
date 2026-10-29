//
//  SnapLayout.swift
//  boringNotch
//

import CoreGraphics
import Foundation

/// A place a dragged window can snap to. New layouts (thirds, quarters…) are added here.
enum SnapLayout: String, CaseIterable, Codable, Identifiable {
    case leftHalf, fill, rightHalf

    var id: String { rawValue }

    /// Localizable, so the names are picked up by the string catalog.
    var label: LocalizedStringResource {
        switch self {
        case .leftHalf: return "Left Half"
        case .fill: return "Fill"
        case .rightHalf: return "Right Half"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .fill: return "rectangle.fill"
        case .rightHalf: return "rectangle.righthalf.filled"
        }
    }

    /// Target frame for a screen, in Cocoa coordinates (bottom-left origin).
    /// `visibleFrame` excludes the menu bar and Dock, so both stay visible.
    /// Halves use whole points; the right half takes the remainder so the two cover the frame exactly.
    func frame(in visibleFrame: CGRect) -> CGRect {
        let leftWidth = (visibleFrame.width / 2).rounded(.down)
        switch self {
        case .fill:
            return visibleFrame
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: leftWidth, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(
                x: visibleFrame.minX + leftWidth,
                y: visibleFrame.minY,
                width: visibleFrame.width - leftWidth,
                height: visibleFrame.height
            )
        }
    }
}
