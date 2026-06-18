import Foundation

enum StickyLayout: Sendable {
    static func frame(
        index: Int,
        in screen: CGRect,
        size: CGSize,
        margin: CGFloat = 16,
        step: CGFloat = 30
    ) -> CGRect {
        let columnCapacity = max(1, Int((screen.height - margin - size.height) / step) + 1)

        let column = index / columnCapacity
        let row = index % columnCapacity

        let baseX = screen.maxX - size.width - margin
        let baseY = screen.maxY - size.height - margin

        let originX = baseX - CGFloat(row) * step - CGFloat(column) * (size.width + margin)
        let originY = baseY - CGFloat(row) * step

        return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
    }
}
