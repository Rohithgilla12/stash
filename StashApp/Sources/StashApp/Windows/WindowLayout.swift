import Foundation

enum WindowLayout {
    static func frame(for target: SnapTarget, in screen: CGRect, gap: CGFloat) -> CGRect {
        let base: CGRect
        switch target {
        case .fullScreen:
            base = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height)
        case .leftHalf:
            base = CGRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height)
        case .rightHalf:
            base = CGRect(x: screen.minX + screen.width / 2, y: screen.minY, width: screen.width / 2, height: screen.height)
        case .topHalf:
            base = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height / 2)
        case .bottomHalf:
            base = CGRect(x: screen.minX, y: screen.minY + screen.height / 2, width: screen.width, height: screen.height / 2)
        case .topLeft:
            base = CGRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        case .topRight:
            base = CGRect(x: screen.minX + screen.width / 2, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        case .bottomLeft:
            base = CGRect(x: screen.minX, y: screen.minY + screen.height / 2, width: screen.width / 2, height: screen.height / 2)
        case .bottomRight:
            base = CGRect(x: screen.minX + screen.width / 2, y: screen.minY + screen.height / 2, width: screen.width / 2, height: screen.height / 2)
        case .leftThird:
            base = CGRect(x: screen.minX, y: screen.minY, width: screen.width / 3, height: screen.height)
        case .centerThird:
            base = CGRect(x: screen.minX + screen.width / 3, y: screen.minY, width: screen.width / 3, height: screen.height)
        case .rightThird:
            base = CGRect(x: screen.minX + 2 * screen.width / 3, y: screen.minY, width: screen.width / 3, height: screen.height)
        case .leftTwoThirds:
            base = CGRect(x: screen.minX, y: screen.minY, width: 2 * screen.width / 3, height: screen.height)
        case .rightTwoThirds:
            base = CGRect(x: screen.minX + screen.width / 3, y: screen.minY, width: 2 * screen.width / 3, height: screen.height)
        }
        return base.insetBy(dx: gap, dy: gap)
    }
}
