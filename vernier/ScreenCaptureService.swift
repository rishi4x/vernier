import ScreenCaptureKit
import AppKit

nonisolated class ScreenCaptureService: @unchecked Sendable {

    func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            print("Screen capture permission denied: \(error)")
            return false
        }
    }

    /// Capture the entire display as a single CGImage. Call BEFORE showing any overlay.
    func captureFullScreen(displayID: CGDirectDisplayID, scale: CGFloat) async -> CGImage? {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            print("Screen capture failed: \(error)")
            return nil
        }
    }
}
