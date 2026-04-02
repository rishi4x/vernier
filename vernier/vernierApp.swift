import SwiftUI
import Carbon
import KeyboardShortcuts

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
    private var escHotkeyID: UInt32?
    private var delayedRefreshTask: Task<Void, Never>?
    private var measurementSessionID = UUID()
    private let state = MeasurementState()
    private let displayManager = DisplayManager()
    private let captureService = ScreenCaptureService()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()

        KeyboardShortcuts.onKeyUp(for: .toggleMeasurement) { [weak self] in
            self?.toggleMeasurement()
        }

        Task { _ = await captureService.requestPermission() }
    }

    @objc func openSettings() {
        if let settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vernier Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        delayedRefreshTask?.cancel()
        let sessionID = UUID()
        measurementSessionID = sessionID

        state.isActive = true
        state.clearEdges()
        state.measurementMode = .hover
        state.anchorPoint = nil

        // Step 1: Capture ALL screens BEFORE showing any overlay
        var captures: [(NSScreen, CGImage)] = []
        let excludedWindowIDs = overlayWindowIDs()
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            let scale = screen.backingScaleFactor
            if let image = await captureService.captureFullScreen(
                displayID: displayID,
                scale: scale,
                excludingWindowIDs: excludedWindowIDs
            ) {
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
            window.makeKeyAndOrderFront(nil)
            return window
        }

        NSCursor.crosshair.push()

        // Non-activating overlay keeps the current app focused, so use a true
        // global hotkey for Esc while measurement mode is active.
        if escHotkeyID == nil {
            escHotkeyID = hotkeyManager.register(
                keyCode: UInt32(kVK_Escape),
                modifiers: 0
            ) { [weak self] in
                self?.deactivateMeasurement()
            }
        }

        scheduleDelayedCaptureRefresh(for: sessionID)
    }

    @objc func deactivateMeasurement() {
        delayedRefreshTask?.cancel()
        delayedRefreshTask = nil

        state.isActive = false
        state.anchorPoint = nil
        state.isDragging = false
        state.measurementMode = .hover
        state.clearEdges()

        if let escHotkeyID {
            hotkeyManager.unregister(hotkeyID: escHotkeyID)
            self.escHotkeyID = nil
        }

        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NSCursor.pop()
    }

    private func scheduleDelayedCaptureRefresh(for sessionID: UUID) {
        delayedRefreshTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            guard self.state.isActive, self.measurementSessionID == sessionID else { return }

            let excludedWindowIDs = await MainActor.run { self.overlayWindowIDs() }
            var capturesByDisplayID: [CGDirectDisplayID: CGImage] = [:]
            for screen in NSScreen.screens {
                let displayID = screen.displayID
                let scale = screen.backingScaleFactor
                if let image = await self.captureService.captureFullScreen(
                    displayID: displayID,
                    scale: scale,
                    excludingWindowIDs: excludedWindowIDs
                ) {
                    capturesByDisplayID[displayID] = image
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.state.isActive, self.measurementSessionID == sessionID else { return }

                for window in self.overlayWindows {
                    guard
                        let overlayView = window.contentView as? OverlayView,
                        let image = capturesByDisplayID[overlayView.screen.displayID],
                        let refreshedFrame = FrozenFrame(cgImage: image)
                    else { continue }

                    overlayView.frozenFrame = refreshedFrame
                    overlayView.needsDisplay = true
                }
            }
        }
    }

    private func overlayWindowIDs() -> Set<CGWindowID> {
        Set(
            overlayWindows.compactMap { window in
                let number = window.windowNumber
                guard number > 0 else { return nil }
                return CGWindowID(number)
            }
        )
    }
}
