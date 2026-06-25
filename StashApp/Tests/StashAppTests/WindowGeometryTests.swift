import Testing
import CoreGraphics
@testable import StashApp

@Suite struct WindowGeometryTests {
    @Test func inBoundsUnchanged() {
        let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(WindowGeometry.clamp(CGRect(x: 100, y: 100, width: 400, height: 300), to: v) == CGRect(x: 100, y: 100, width: 400, height: 300))
    }
    @Test func oversizeShrinks() {
        let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let c = WindowGeometry.clamp(CGRect(x: 0, y: 0, width: 5000, height: 5000), to: v)
        #expect(c.width == 1000 && c.height == 800)
    }
    @Test func offRightNudgesLeft() {
        let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let c = WindowGeometry.clamp(CGRect(x: 900, y: 100, width: 400, height: 300), to: v)
        #expect(c.maxX == 1000 && c.width == 400)
    }
    @Test func offTopLeftNudgesIntoBounds() {
        let v = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let c = WindowGeometry.clamp(CGRect(x: -50, y: -30, width: 400, height: 300), to: v)
        #expect(c.minX == 0 && c.minY == 0)
    }
}
