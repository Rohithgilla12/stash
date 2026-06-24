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

    static func frame(for preset: WindowPreset, in rect: CGRect) -> CGRect {
        func resolve(_ mode: PresetSizeMode, _ value: Double, axis: CGFloat) -> CGFloat {
            let raw = mode == .percent ? axis * CGFloat(value) : CGFloat(value)
            return min(max(raw, 1), axis)   // clamp to the display
        }
        let w = resolve(preset.widthMode, preset.width, axis: rect.width)
        let h = resolve(preset.heightMode, preset.height, axis: rect.height)

        var x: CGFloat
        switch preset.anchor {
        case .center, .top, .bottom:            x = rect.minX + (rect.width - w) / 2
        case .left, .topLeft, .bottomLeft:      x = rect.minX
        case .right, .topRight, .bottomRight:   x = rect.maxX - w
        }
        var y: CGFloat
        switch preset.anchor {  // AX space: y increases downward, so .top == minY
        case .center, .left, .right:            y = rect.minY + (rect.height - h) / 2
        case .top, .topLeft, .topRight:         y = rect.minY
        case .bottom, .bottomLeft, .bottomRight: y = rect.maxY - h
        }
        return CGRect(x: x + CGFloat(preset.xOffset), y: y + CGFloat(preset.yOffset), width: w, height: h)
    }
}
