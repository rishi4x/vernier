import AppKit
import ScreenCaptureKit

struct DisplayInfo {
    let screen: NSScreen
    let frame: CGRect
    let backingScale: CGFloat
    let pixelSize: CGSize
    let displayID: CGDirectDisplayID
}

class DisplayManager {

    func allDisplays() -> [DisplayInfo] {
        NSScreen.screens.map { screen in
            let scale = screen.backingScaleFactor
            let frame = screen.frame
            let displayID = screen.displayID
            return DisplayInfo(
                screen: screen,
                frame: frame,
                backingScale: scale,
                pixelSize: CGSize(width: frame.width * scale, height: frame.height * scale),
                displayID: displayID
            )
        }
    }

    func displayForPoint(_ point: CGPoint) -> DisplayInfo? {
        allDisplays().first { NSPointInRect(point, $0.frame) }
    }

    func pointsToPixels(_ points: CGFloat, on screen: NSScreen) -> Int {
        Int(round(points * screen.backingScaleFactor))
    }

    func pixelsToPoints(_ pixels: CGFloat, on screen: NSScreen) -> CGFloat {
        pixels / screen.backingScaleFactor
    }

    /// Convert a global screen point to the local pixel coordinate within a capture image for that display.
    /// Note: Screen coordinates have origin at bottom-left, but CGImage/capture has origin at top-left.
    func globalPointToLocalPixel(_ point: CGPoint, on display: DisplayInfo) -> CGPoint {
        let localX = (point.x - display.frame.origin.x) * display.backingScale
        // Flip Y: screen coords are bottom-left origin, image coords are top-left origin
        let localY = (display.frame.height - (point.y - display.frame.origin.y)) * display.backingScale
        return CGPoint(x: localX, y: localY)
    }

    /// Find the SCDisplay matching an NSScreen by display ID.
    func scDisplay(for screen: NSScreen, from displays: [SCDisplay]) -> SCDisplay? {
        let screenID = screen.displayID
        return displays.first { $0.displayID == screenID }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}
