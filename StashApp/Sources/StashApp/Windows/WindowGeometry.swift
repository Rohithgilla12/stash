import CoreGraphics

enum WindowGeometry {
    /// Clamp `frame` to fit inside `visible` (AX coords): shrink to fit, then nudge fully on-screen.
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let w = min(frame.width, visible.width)
        let h = min(frame.height, visible.height)
        var x = frame.minX, y = frame.minY
        if x < visible.minX { x = visible.minX }
        if y < visible.minY { y = visible.minY }
        if x + w > visible.maxX { x = visible.maxX - w }
        if y + h > visible.maxY { y = visible.maxY - h }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
