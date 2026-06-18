import Testing
import Foundation
@testable import StashApp

@Suite struct ScreenGeometryTests {

    @Test func axFrameFlipsYCorrectly() {
        // AppKit (0, 0, 800, 600) on a 1440-tall primary screen
        // axY = 1440 - (0 + 600) = 840
        let appKitRect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let result = ScreenGeometry.axFrame(fromAppKit: appKitRect, primaryHeight: 1440)
        #expect(result == CGRect(x: 0, y: 840, width: 800, height: 600))
    }

    @Test func axFrameTopAlignedWindowMapsToNearZero() {
        // A window at the top of the screen in AppKit (bottom-left origin)
        // AppKit y = primaryHeight - height = 1440 - 600 = 840 means top of screen
        // axY = 1440 - (840 + 600) = 1440 - 1440 = 0
        let appKitRect = CGRect(x: 0, y: 840, width: 800, height: 600)
        let result = ScreenGeometry.axFrame(fromAppKit: appKitRect, primaryHeight: 1440)
        #expect(abs(result.minY) < 1.0)
    }

    @Test func axFrameXUnchanged() {
        let appKitRect = CGRect(x: 123, y: 50, width: 400, height: 300)
        let result = ScreenGeometry.axFrame(fromAppKit: appKitRect, primaryHeight: 1080)
        #expect(result.minX == 123)
    }

    @Test func axFrameWidthUnchanged() {
        let appKitRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenGeometry.axFrame(fromAppKit: appKitRect, primaryHeight: 1080)
        #expect(result.width == 1920)
    }

    @Test func axFrameHeightUnchanged() {
        let appKitRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let result = ScreenGeometry.axFrame(fromAppKit: appKitRect, primaryHeight: 1080)
        #expect(result.height == 1080)
    }

    @Test func snapHotKeyAllHas12Entries() {
        #expect(SnapHotKey.all.count == 12)
    }

    @Test func snapHotKeyAllHasNoDuplicateCombos() {
        let combos = SnapHotKey.all.map { "\($0.keyCode):\($0.modifiers)" }
        let uniqueCombos = Set(combos)
        #expect(combos.count == uniqueCombos.count)
    }
}
