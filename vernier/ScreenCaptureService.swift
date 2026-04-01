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

    /// Capture the entire display as a single CGImage, excluding any provided windows.
    func captureFullScreen(
        displayID: CGDirectDisplayID,
        scale: CGFloat,
        excludingWindowIDs: Set<CGWindowID> = []
    ) async -> CGImage? {
        do {
            // `showsCursor = false` should exclude the pointer, but on some setups
            // ScreenCaptureKit can still include cursor artifacts. Hide it explicitly
            // during the grab so both capture passes stay clean for edge detection.
            let hideResult = CGDisplayHideCursor(displayID)
            defer {
                if hideResult == .success {
                    CGDisplayShowCursor(displayID)
                }
            }

            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }

            let excludedWindows = content.windows.filter { excludingWindowIDs.contains($0.windowID) }
            let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
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
