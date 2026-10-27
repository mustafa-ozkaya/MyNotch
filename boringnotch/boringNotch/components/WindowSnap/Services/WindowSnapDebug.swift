//
//  WindowSnapDebug.swift
//  boringNotch
//
//  TEMPORARY (spec step 13 check): exercises the helper's window API end to end before the
//  drag detector and panel exist. Debug builds only; remove once step 15 works.
//

#if DEBUG
import AppKit

@MainActor
enum WindowSnapDebug {
    /// After 3 s, snaps the window under the mouse to the left half of its screen and logs the result.
    static func snapWindowUnderMouseToLeftHalf() async {
        let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
        guard granted else {
            NSLog("🪟 SnapDebug: Accessibility not granted")
            return
        }
        try? await Task.sleep(for: .seconds(3))

        let mouse = NSEvent.mouseLocation
        guard let primary = NSScreen.screens.first,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) else {
            NSLog("🪟 SnapDebug: no screen under the mouse")
            return
        }
        let primaryHeight = primary.frame.height
        let axPoint = CGPoint(x: mouse.x, y: primaryHeight - mouse.y)

        guard let handle = await XPCHelperClient.shared.windowUnderPoint(axPoint) else {
            NSLog("🪟 SnapDebug: no window under \(axPoint)")
            return
        }
        defer { XPCHelperClient.shared.releaseWindow(handle) }

        let target = SnapGeometry.axRect(
            fromCocoa: SnapLayout.leftHalf.frame(in: screen.visibleFrame),
            primaryScreenHeight: primaryHeight
        )
        let final = await XPCHelperClient.shared.setWindowFrame(handle, to: target)
        let matched = final.map { SnapGeometry.frameMatches($0, target: target) } ?? false
        NSLog("🪟 SnapDebug: window \(handle.frame) → target \(target), got \(String(describing: final)), matched=\(matched)")
    }
}
#endif
