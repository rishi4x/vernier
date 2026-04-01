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
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
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

            let overlayView = OverlayView(
                state: state,
                screen: screen,
                displayManager: displayManager,
                onEscape: { [weak self] in self?.deactivateMeasurement() }
            )
            overlayView.frozenFrame = frozenFrame

            let window = OverlayWindow(for: screen, overlayView: overlayView)
            window.orderFrontRegardless()
            return window
        }

        NSCursor.crosshair.push()
        NSApp.activate(ignoringOtherApps: true)
        overlayWindows.first?.makeKeyAndOrderFront(nil)

        // Capture ESC when Vernier is active
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.deactivateMeasurement()
            return nil
        }

        // Capture ESC when another app still has focus
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async {
                self?.deactivateMeasurement()
            }
        }
    }

    @objc func deactivateMeasurement() {
        state.isActive = false
        state.anchorPoint = nil
        state.isDragging = false
        state.measurementMode = .hover
        state.clearEdges()

        if let monitor = escLocalMonitor {
            NSEvent.removeMonitor(monitor)
            escLocalMonitor = nil
        }

        if let monitor = escGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            escGlobalMonitor = nil
        }

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NSCursor.pop()
    }
}
