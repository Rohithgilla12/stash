import CoreGraphics

enum ScreenGeometry {
    // Converts an AppKit frame (bottom-left origin, y increases upward) to an
    // AX frame (top-left origin of the primary display, y increases downward).
    //
    // Formula: axY = primaryHeight - (appKitY + height)
    // x, width, and height are unchanged.
    static func axFrame(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        let axY = primaryHeight - (rect.minY + rect.height)
        return CGRect(x: rect.minX, y: axY, width: rect.width, height: rect.height)
    }
}
