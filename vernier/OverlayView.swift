import AppKit

class OverlayView: NSView {
    let state: MeasurementState
    let screen: NSScreen
    private let displayManager: DisplayManager
    private let onEscape: () -> Void

    /// Pre-built pixel buffer from frozen screenshot for instant edge lookups.
    var frozenFrame: FrozenFrame?

    private let rulerColor = NSColor.systemRed
    private let labelFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)

    init(
        state: MeasurementState,
        screen: NSScreen,
        displayManager: DisplayManager,
        onEscape: @escaping () -> Void = {}
    ) {
        self.state = state
        self.screen = screen
        self.displayManager = displayManager
        self.onEscape = onEscape
        super.init(frame: screen.frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(area)
    }

    // MARK: - Mouse Events

    override func mouseMoved(with event: NSEvent) {
        // Don't update while a finished measurement box is displayed
        if state.measurementMode == .measuring, !state.isDragging { return }

        let screenPoint = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        state.cursorPosition = screenPoint
        state.activeScreen = screen

        // Synchronous edge detection on the frozen bitmap — no async, no lag
        if let frame = frozenFrame {
            let screenFrame = screen.frame

            let scaleX = CGFloat(frame.width) / screenFrame.width
            let scaleY = CGFloat(frame.height) / screenFrame.height
            state.trueScaleX = scaleX
            state.trueScaleY = scaleY

            let localX = screenPoint.x - screenFrame.origin.x
            let localY = screenPoint.y - screenFrame.origin.y

            let pixelX = Int(localX * scaleX)
            let pixelY = Int((screenFrame.height - localY) * scaleY)

            let edges = frame.findEdges(fromX: pixelX, fromY: pixelY)

            state.nearestLeftEdge = edges.left.map { screenFrame.origin.x + $0 / scaleX }
            state.nearestRightEdge = edges.right.map { screenFrame.origin.x + $0 / scaleX }
            state.nearestTopEdge = edges.top.map { screenFrame.origin.y + screenFrame.height - $0 / scaleY }
            state.nearestBottomEdge = edges.bottom.map { screenFrame.origin.y + screenFrame.height - $0 / scaleY }
        }

        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let screenPoint = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        state.anchorPoint = screenPoint
        state.cursorPosition = screenPoint
        state.activeScreen = screen
        state.measurementMode = .measuring
        state.isDragging = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let screenPoint = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        state.cursorPosition = screenPoint
        state.activeScreen = screen
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let screenPoint = window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        state.cursorPosition = screenPoint
        state.activeScreen = screen
        state.measurementMode = .hover
        state.anchorPoint = nil
        state.isDragging = false
        needsDisplay = true
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard state.isActive else { return }

        let scale = screen.backingScaleFactor
        let screenFrame = screen.frame

        let cursorLocal = CGPoint(
            x: state.cursorPosition.x - screenFrame.origin.x,
            y: state.cursorPosition.y - screenFrame.origin.y
        )

        if state.measurementMode == .measuring, let anchor = state.anchorPoint {
            drawManualMeasurement(cursor: cursorLocal, anchor: anchor, screenFrame: screenFrame, scale: scale)
        } else if state.activeScreen?.displayID == screen.displayID {
            drawSnapMeasurement(cursor: cursorLocal, screenFrame: screenFrame, scale: scale)
        }
    }

    // MARK: - Snap Measurement Drawing

    private func drawSnapMeasurement(cursor: CGPoint, screenFrame: CGRect, scale: CGFloat) {
        let rulerStroke = rulerColor.withAlphaComponent(0.9)

        // Horizontal ruler
        if state.nearestLeftEdge != nil || state.nearestRightEdge != nil {
            let left = state.nearestLeftEdge ?? screenFrame.minX
            let right = state.nearestRightEdge ?? screenFrame.maxX
            let localLeft = left - screenFrame.origin.x
            let localRight = right - screenFrame.origin.x

            // Ruler line
            rulerStroke.setStroke()
            let hPath = NSBezierPath()
            hPath.move(to: CGPoint(x: localLeft, y: cursor.y))
            hPath.line(to: CGPoint(x: localRight, y: cursor.y))
            hPath.lineWidth = 1.5
            hPath.stroke()

            // Tick marks at edges
            drawTickMark(at: CGPoint(x: localLeft, y: cursor.y), vertical: true)
            drawTickMark(at: CGPoint(x: localRight, y: cursor.y), vertical: true)

            // Pixel label
            let pixels = Int(round((right - left) * state.trueScaleX)) + 1
            if pixels > 0 {
                drawPillLabel("\(pixels)px", at: CGPoint(x: (localLeft + localRight) / 2, y: cursor.y + 16))
            }
        }

        // Vertical ruler
        if state.nearestTopEdge != nil || state.nearestBottomEdge != nil {
            let top = state.nearestTopEdge ?? screenFrame.maxY
            let bottom = state.nearestBottomEdge ?? screenFrame.minY
            let localTop = top - screenFrame.origin.y
            let localBottom = bottom - screenFrame.origin.y

            rulerStroke.setStroke()
            let vPath = NSBezierPath()
            vPath.move(to: CGPoint(x: cursor.x, y: localBottom))
            vPath.line(to: CGPoint(x: cursor.x, y: localTop))
            vPath.lineWidth = 1.5
            vPath.stroke()

            drawTickMark(at: CGPoint(x: cursor.x, y: localTop), vertical: false)
            drawTickMark(at: CGPoint(x: cursor.x, y: localBottom), vertical: false)

            let pixels = Int(round((top - bottom) * state.trueScaleY)) + 1
            if pixels > 0 {
                drawPillLabel("\(pixels)px", at: CGPoint(x: cursor.x + 16, y: (localTop + localBottom) / 2))
            }
        }
    }

    // MARK: - Manual Measurement Drawing

    private func drawManualMeasurement(cursor: CGPoint, anchor: CGPoint, screenFrame: CGRect, scale: CGFloat) {
        let anchorLocal = CGPoint(
            x: anchor.x - screenFrame.origin.x,
            y: anchor.y - screenFrame.origin.y
        )

        let rect = CGRect(
            x: min(anchorLocal.x, cursor.x),
            y: min(anchorLocal.y, cursor.y),
            width: abs(cursor.x - anchorLocal.x),
            height: abs(cursor.y - anchorLocal.y)
        )

        rulerColor.withAlphaComponent(0.08).setFill()
        NSBezierPath(rect: rect).fill()

        rulerColor.withAlphaComponent(0.6).setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1.0
        border.stroke()

        if let hPixels = state.horizontalPixels, hPixels > 0 {
            drawPillLabel("\(hPixels)px", at: CGPoint(x: rect.midX, y: rect.maxY + 10))
        }
        if let vPixels = state.verticalPixels, vPixels > 0 {
            drawPillLabel("\(vPixels)px", at: CGPoint(x: rect.maxX + 10, y: rect.midY))
        }

        // Anchor dot
        let dotRect = CGRect(x: anchorLocal.x - 3, y: anchorLocal.y - 3, width: 6, height: 6)
        rulerColor.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    // MARK: - Drawing Helpers

    private func drawTickMark(at point: CGPoint, vertical: Bool) {
        let tickLength: CGFloat = 8
        rulerColor.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath()
        if vertical {
            path.move(to: CGPoint(x: point.x, y: point.y - tickLength / 2))
            path.line(to: CGPoint(x: point.x, y: point.y + tickLength / 2))
        } else {
            path.move(to: CGPoint(x: point.x - tickLength / 2, y: point.y))
            path.line(to: CGPoint(x: point.x + tickLength / 2, y: point.y))
        }
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawPillLabel(_ text: String, at point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let padding = CGSize(width: 8, height: 4)
        let pillRect = CGRect(
            x: point.x - textSize.width / 2 - padding.width,
            y: point.y - textSize.height / 2 - padding.height,
            width: textSize.width + padding.width * 2,
            height: textSize.height + padding.height * 2
        )

        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
        NSColor.black.withAlphaComponent(0.8).setFill()
        pillPath.fill()

        str.draw(at: CGPoint(x: point.x - textSize.width / 2, y: point.y - textSize.height / 2))
    }
}
