import CoreGraphics

struct EdgeResult {
    let left: CGFloat?
    let right: CGFloat?
    let top: CGFloat?
    let bottom: CGFloat?
}

/// Holds raw pixel data from a frozen screenshot for instant edge lookups.
/// Reads directly from the CGImage's data provider — no CGContext drawing,
/// so no upside-down coordinate bugs on macOS.
class FrozenFrame {
    private let pixelData: CFData
    private let ptr: UnsafePointer<UInt8>

    let width: Int
    let height: Int
    private let bytesPerRow: Int
    private let bytesPerPixel: Int

    var threshold: Int = 5

    init?(cgImage: CGImage) {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else { return nil }

        self.pixelData = data
        self.ptr = CFDataGetBytePtr(data)
        self.width = cgImage.width
        self.height = cgImage.height
        self.bytesPerRow = cgImage.bytesPerRow
        self.bytesPerPixel = cgImage.bitsPerPixel / 8

        guard self.bytesPerPixel >= 3 else { return nil }
    }

    func findEdges(fromX cx: Int, fromY cy: Int) -> EdgeResult {
        let cx = max(0, min(cx, width - 1))
        let cy = max(0, min(cy, height - 1))
        let t = threshold

        var left: CGFloat? = nil
        for x in stride(from: cx - 1, through: 0, by: -1) {
            if diff(x1: x, y1: cy, x2: x + 1, y2: cy) >= t {
                left = CGFloat(x + 1)
                break
            }
        }

        var right: CGFloat? = nil
        for x in (cx + 1)..<width {
            if diff(x1: x, y1: cy, x2: x - 1, y2: cy) >= t {
                right = CGFloat(x - 1)
                break
            }
        }

        var top: CGFloat? = nil
        for y in stride(from: cy - 1, through: 0, by: -1) {
            if diff(x1: cx, y1: y, x2: cx, y2: y + 1) >= t {
                top = CGFloat(y + 1)
                break
            }
        }

        var bottom: CGFloat? = nil
        for y in (cy + 1)..<height {
            if diff(x1: cx, y1: y, x2: cx, y2: y - 1) >= t {
                bottom = CGFloat(y - 1)
                break
            }
        }

        return EdgeResult(left: left, right: right, top: top, bottom: bottom)
    }

    @inline(__always)
    private func diff(x1: Int, y1: Int, x2: Int, y2: Int) -> Int {
        let i1 = y1 * bytesPerRow + x1 * bytesPerPixel
        let i2 = y2 * bytesPerRow + x2 * bytesPerPixel

        let b1 = Int(ptr[i1])
        let b2 = Int(ptr[i2])
        let g1 = Int(ptr[i1 + 1])
        let g2 = Int(ptr[i2 + 1])
        let r1 = Int(ptr[i1 + 2])
        let r2 = Int(ptr[i2 + 2])

        return max(abs(r1 - r2), max(abs(g1 - g2), abs(b1 - b2)))
    }
}
