import AppKit

class OverlayWindow: NSPanel {

    init(for screen: NSScreen, overlayView: OverlayView) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.setFrame(screen.frame, display: false)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.contentView = overlayView
        self.initialFirstResponder = overlayView
    }

    // Keep the currently active app focused while this overlay is open.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
