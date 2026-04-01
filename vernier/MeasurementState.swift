import AppKit

enum MeasurementMode {
    case hover
    case measuring
}

@Observable
class MeasurementState {
    var isActive: Bool = false
    var cursorPosition: CGPoint = .zero
    var activeScreen: NSScreen? = nil

    // Detected edges in screen points (global coordinates)
    var nearestLeftEdge: CGFloat? = nil
    var nearestRightEdge: CGFloat? = nil
    var nearestTopEdge: CGFloat? = nil
    var nearestBottomEdge: CGFloat? = nil

    // Click-to-measure
    var anchorPoint: CGPoint? = nil
    var measurementMode: MeasurementMode = .hover
    var isDragging: Bool = false

    // True scale derived from captured image dimensions / screen points.
    // Set by OverlayView when the frozen frame is loaded.
    var trueScaleX: CGFloat = 2.0
    var trueScaleY: CGFloat = 2.0

    var horizontalPixels: Int? {
        if measurementMode == .measuring, let anchor = anchorPoint {
            return Int(round(abs(cursorPosition.x - anchor.x) * trueScaleX))
        }
        guard let left = nearestLeftEdge, let right = nearestRightEdge else { return nil }
        return Int(round((right - left) * trueScaleX))
    }

    var verticalPixels: Int? {
        if measurementMode == .measuring, let anchor = anchorPoint {
            return Int(round(abs(cursorPosition.y - anchor.y) * trueScaleY))
        }
        guard let top = nearestTopEdge, let bottom = nearestBottomEdge else { return nil }
        return Int(round((top - bottom) * trueScaleY))
    }

    func clearEdges() {
        nearestLeftEdge = nil
        nearestRightEdge = nil
        nearestTopEdge = nil
        nearestBottomEdge = nil
    }
}
