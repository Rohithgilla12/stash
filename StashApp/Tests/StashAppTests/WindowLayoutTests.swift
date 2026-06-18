import Testing
import Foundation
@testable import StashApp

@Suite struct WindowLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let gap: CGFloat = 10

    @Test func leftHalfOriginX() {
        let frame = WindowLayout.frame(for: .leftHalf, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 10) < 1.0)
    }

    @Test func leftHalfWidth() {
        let frame = WindowLayout.frame(for: .leftHalf, in: screen, gap: gap)
        #expect(abs(frame.width - 480) < 1.0)
    }

    @Test func leftHalfHeight() {
        let frame = WindowLayout.frame(for: .leftHalf, in: screen, gap: gap)
        #expect(abs(frame.height - 780) < 1.0)
    }

    @Test func rightHalfOriginX() {
        let frame = WindowLayout.frame(for: .rightHalf, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 510) < 1.0)
    }

    @Test func rightHalfWidth() {
        let frame = WindowLayout.frame(for: .rightHalf, in: screen, gap: gap)
        #expect(abs(frame.width - 480) < 1.0)
    }

    @Test func rightHalfHeight() {
        let frame = WindowLayout.frame(for: .rightHalf, in: screen, gap: gap)
        #expect(abs(frame.height - 780) < 1.0)
    }

    @Test func topHalfOriginY() {
        let frame = WindowLayout.frame(for: .topHalf, in: screen, gap: gap)
        #expect(abs(frame.origin.y - 10) < 1.0)
    }

    @Test func topHalfHeight() {
        let frame = WindowLayout.frame(for: .topHalf, in: screen, gap: gap)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func bottomHalfOriginY() {
        let frame = WindowLayout.frame(for: .bottomHalf, in: screen, gap: gap)
        #expect(abs(frame.origin.y - 410) < 1.0)
    }

    @Test func bottomHalfHeight() {
        let frame = WindowLayout.frame(for: .bottomHalf, in: screen, gap: gap)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func topLeftFrame() {
        let frame = WindowLayout.frame(for: .topLeft, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 10) < 1.0)
        #expect(abs(frame.origin.y - 10) < 1.0)
        #expect(abs(frame.width - 480) < 1.0)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func topRightFrame() {
        let frame = WindowLayout.frame(for: .topRight, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 510) < 1.0)
        #expect(abs(frame.origin.y - 10) < 1.0)
        #expect(abs(frame.width - 480) < 1.0)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func bottomLeftFrame() {
        let frame = WindowLayout.frame(for: .bottomLeft, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 10) < 1.0)
        #expect(abs(frame.origin.y - 410) < 1.0)
        #expect(abs(frame.width - 480) < 1.0)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func bottomRightFrame() {
        let frame = WindowLayout.frame(for: .bottomRight, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 510) < 1.0)
        #expect(abs(frame.origin.y - 410) < 1.0)
        #expect(abs(frame.width - 480) < 1.0)
        #expect(abs(frame.height - 380) < 1.0)
    }

    @Test func leftThirdFrame() {
        let frame = WindowLayout.frame(for: .leftThird, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 10) < 1.0)
        #expect(abs(frame.width - (1000.0 / 3.0 - 20)) < 1.0)
        #expect(abs(frame.height - 780) < 1.0)
    }

    @Test func centerThirdFrame() {
        let frame = WindowLayout.frame(for: .centerThird, in: screen, gap: gap)
        #expect(abs(frame.origin.x - (1000.0 / 3.0 + 10)) < 1.0)
        #expect(abs(frame.width - (1000.0 / 3.0 - 20)) < 1.0)
    }

    @Test func rightThirdFrame() {
        let frame = WindowLayout.frame(for: .rightThird, in: screen, gap: gap)
        #expect(abs(frame.origin.x - (2 * 1000.0 / 3.0 + 10)) < 1.0)
        #expect(abs(frame.width - (1000.0 / 3.0 - 20)) < 1.0)
    }

    @Test func leftTwoThirdsWidth() {
        let frame = WindowLayout.frame(for: .leftTwoThirds, in: screen, gap: gap)
        #expect(abs(frame.width - (2 * 1000.0 / 3.0 - 20)) < 1.0)
    }

    @Test func rightTwoThirdsFrame() {
        let frame = WindowLayout.frame(for: .rightTwoThirds, in: screen, gap: gap)
        #expect(abs(frame.origin.x - (1000.0 / 3.0 + 10)) < 1.0)
        #expect(abs(frame.width - (2 * 1000.0 / 3.0 - 20)) < 1.0)
    }

    @Test func fullScreenFrame() {
        let frame = WindowLayout.frame(for: .fullScreen, in: screen, gap: gap)
        #expect(abs(frame.origin.x - 10) < 1.0)
        #expect(abs(frame.origin.y - 10) < 1.0)
        #expect(abs(frame.width - 980) < 1.0)
        #expect(abs(frame.height - 780) < 1.0)
    }

    @Test func allTargetsInsideScreenBounds() {
        for target in SnapTarget.allCases {
            let frame = WindowLayout.frame(for: target, in: screen, gap: gap)
            #expect(frame.maxX <= screen.maxX, "maxX out of bounds for \(target.rawValue)")
            #expect(frame.maxY <= screen.maxY, "maxY out of bounds for \(target.rawValue)")
        }
    }

    @Test func snapTargetCount() {
        #expect(SnapTarget.allCases.count == 14)
    }

    @Test func snapTargetLabels() {
        #expect(SnapTarget.leftHalf.label == "Left Half")
        #expect(SnapTarget.rightHalf.label == "Right Half")
        #expect(SnapTarget.topHalf.label == "Top Half")
        #expect(SnapTarget.bottomHalf.label == "Bottom Half")
        #expect(SnapTarget.topLeft.label == "Top Left")
        #expect(SnapTarget.topRight.label == "Top Right")
        #expect(SnapTarget.bottomLeft.label == "Bottom Left")
        #expect(SnapTarget.bottomRight.label == "Bottom Right")
        #expect(SnapTarget.leftThird.label == "Left Third")
        #expect(SnapTarget.centerThird.label == "Center Third")
        #expect(SnapTarget.rightThird.label == "Right Third")
        #expect(SnapTarget.leftTwoThirds.label == "Left Two Thirds")
        #expect(SnapTarget.rightTwoThirds.label == "Right Two Thirds")
        #expect(SnapTarget.fullScreen.label == "Full Screen")
    }

    @Test func snapTargetGroups() {
        #expect(SnapTarget.leftHalf.group == "Halves")
        #expect(SnapTarget.rightHalf.group == "Halves")
        #expect(SnapTarget.topHalf.group == "Halves")
        #expect(SnapTarget.bottomHalf.group == "Halves")
        #expect(SnapTarget.topLeft.group == "Quarters")
        #expect(SnapTarget.topRight.group == "Quarters")
        #expect(SnapTarget.bottomLeft.group == "Quarters")
        #expect(SnapTarget.bottomRight.group == "Quarters")
        #expect(SnapTarget.leftThird.group == "Thirds")
        #expect(SnapTarget.centerThird.group == "Thirds")
        #expect(SnapTarget.rightThird.group == "Thirds")
        #expect(SnapTarget.leftTwoThirds.group == "Thirds")
        #expect(SnapTarget.rightTwoThirds.group == "Thirds")
        #expect(SnapTarget.fullScreen.group == "Full Screen")
    }

    @Test func snapTargetHotkeys() {
        #expect(SnapTarget.leftHalf.hotkey == "⌃⌥←")
        #expect(SnapTarget.rightHalf.hotkey == "⌃⌥→")
        #expect(SnapTarget.topHalf.hotkey == "⌃⌥↑")
        #expect(SnapTarget.bottomHalf.hotkey == "⌃⌥↓")
        #expect(SnapTarget.topLeft.hotkey == "⌃⌥U")
        #expect(SnapTarget.topRight.hotkey == "⌃⌥I")
        #expect(SnapTarget.bottomLeft.hotkey == "⌃⌥J")
        #expect(SnapTarget.bottomRight.hotkey == "⌃⌥K")
        #expect(SnapTarget.leftThird.hotkey == "⌃⌥D")
        #expect(SnapTarget.centerThird.hotkey == "⌃⌥F")
        #expect(SnapTarget.rightThird.hotkey == "⌃⌥G")
        #expect(SnapTarget.leftTwoThirds.hotkey == "⌃⌥E")
        #expect(SnapTarget.rightTwoThirds.hotkey == "⌃⌥T")
        #expect(SnapTarget.fullScreen.hotkey == "⌃⌥↩")
    }
}
