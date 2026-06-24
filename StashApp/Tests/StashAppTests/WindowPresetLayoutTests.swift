import Testing
import CoreGraphics
@testable import StashApp

@Suite struct WindowPresetLayoutTests {
    // A 1000×800 display at origin (top-left AX space).
    let rect = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func preset(_ a: PresetAnchor, wMode: PresetSizeMode = .percent, w: Double = 0.5,
                hMode: PresetSizeMode = .percent, h: Double = 0.5,
                dx: Double = 0, dy: Double = 0) -> WindowPreset {
        WindowPreset(id: "t", name: "t", widthMode: wMode, width: w, heightMode: hMode, height: h,
                     anchor: a, xOffset: dx, yOffset: dy, displayMode: "active", displayIndex: 0,
                     hotkeyKeyCode: nil, hotkeyModifiers: nil, createdAt: 0)
    }

    @Test func percentCenter() {
        let f = WindowLayout.frame(for: preset(.center), in: rect)
        #expect(f == CGRect(x: 250, y: 200, width: 500, height: 400))
    }
    @Test func pointsTopLeft() {
        let f = WindowLayout.frame(for: preset(.topLeft, wMode: .points, w: 600, hMode: .points, h: 400), in: rect)
        #expect(f == CGRect(x: 0, y: 0, width: 600, height: 400))
    }
    @Test func rightAnchorRightAligns() {
        let f = WindowLayout.frame(for: preset(.right, w: 0.3), in: rect)
        #expect(f.maxX == 1000)
        #expect(f.width == 300)
    }
    @Test func bottomAnchorBottomAligns() {
        let f = WindowLayout.frame(for: preset(.bottom, h: 0.5), in: rect)
        #expect(f.maxY == 800)
    }
    @Test func offsetShifts() {
        let f = WindowLayout.frame(for: preset(.topLeft, wMode: .points, w: 200, hMode: .points, h: 200, dx: 20, dy: 30), in: rect)
        #expect(f.origin == CGPoint(x: 20, y: 30))
    }
    @Test func oversizeClampsToDisplay() {
        let f = WindowLayout.frame(for: preset(.center, wMode: .points, w: 5000, hMode: .points, h: 5000), in: rect)
        #expect(f.width == 1000)
        #expect(f.height == 800)
    }
}
