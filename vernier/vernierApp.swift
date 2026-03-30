import SwiftUI
import Carbon

@main
struct VernierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotkeyManager = HotkeyManager()
    private var overlayWindows: [OverlayWindow] = []
    private let state = MeasurementState()
    private let displayManager = DisplayManager()
    private let captureService = ScreenCaptureService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()

        hotkeyManager.register(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(cmdKey | shiftKey)
        ) { [weak self] in
            self?.toggleMeasurement()
        }

        Task { _ = await captureService.requestPermission() }
    }

    @objc func toggleMeasurement() {
        if state.isActive {
            deactivateMeasurement()
        } else {
            // Capture is async, so launch activation in a Task
            Task { await activateMeasurement() }
        }
    }

    private func activateMeasurement() async {
        state.isActive = true
        state.clearEdges()
        state.measurementMode = .hover
        state.anchorPoint = nil

        // Step 1: Capture ALL screens BEFORE showing any overlay
        var captures: [(NSScreen, CGImage)] = []
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let scale = screen.backingScaleFactor
            if let image = await captureService.captureFullScreen(displayID: displayID, scale: scale) {
                captures.append((screen, image))
            }
        }

        // Step 2: Build frozen frames and create overlay windows
        overlayWindows = captures.compactMap { (screen, cgImage) in
            guard let frozenFrame = FrozenFrame(cgImage: cgImage) else { return nil }

            let overlayView = OverlayView(state: state, screen: screen, displayManager: displayManager)
            overlayView.frozenFrame = frozenFrame

            let window = OverlayWindow(for: screen, overlayView: overlayView)
            window.orderFrontRegardless()
            return window
        }

        overlayWindows.first?.makeKey()
        NSCursor.crosshair.push()
    }

    @objc func deactivateMeasurement() {
        state.isActive = false
        state.anchorPoint = nil
        state.measurementMode = .hover
        state.clearEdges()

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NSCursor.pop()
    }
}
