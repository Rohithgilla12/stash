import Testing
import Foundation
@testable import StashApp

@Suite struct StickyLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let size = CGSize(width: 220, height: 220)
    let margin: CGFloat = 16
    let step: CGFloat = 30

    @Test func index0OriginX() {
        let frame = StickyLayout.frame(index: 0, in: screen, size: size)
        let expectedX = screen.maxX - size.width - margin
        #expect(abs(frame.origin.x - expectedX) < 0.5)
    }

    @Test func index0OriginY() {
        let frame = StickyLayout.frame(index: 0, in: screen, size: size)
        let expectedY = screen.maxY - size.height - margin
        #expect(abs(frame.origin.y - expectedY) < 0.5)
    }

    @Test func index0Size() {
        let frame = StickyLayout.frame(index: 0, in: screen, size: size)
        #expect(abs(frame.width - size.width) < 0.5)
        #expect(abs(frame.height - size.height) < 0.5)
    }

    @Test func index1OffsetByStep() {
        let f0 = StickyLayout.frame(index: 0, in: screen, size: size)
        let f1 = StickyLayout.frame(index: 1, in: screen, size: size)
        #expect(abs(f1.origin.x - (f0.origin.x - step)) < 0.5)
        #expect(abs(f1.origin.y - (f0.origin.y - step)) < 0.5)
    }

    @Test func index2OffsetByTwoSteps() {
        let f0 = StickyLayout.frame(index: 0, in: screen, size: size)
        let f2 = StickyLayout.frame(index: 2, in: screen, size: size)
        #expect(abs(f2.origin.x - (f0.origin.x - 2 * step)) < 0.5)
        #expect(abs(f2.origin.y - (f0.origin.y - 2 * step)) < 0.5)
    }

    @Test func allFramesIntersectScreen() {
        for i in 0..<20 {
            let frame = StickyLayout.frame(index: i, in: screen, size: size)
            #expect(frame.intersects(screen), "index \(i) frame does not intersect screen")
        }
    }

    @Test func frameWidthAndHeightPreserved() {
        for i in 0..<10 {
            let frame = StickyLayout.frame(index: i, in: screen, size: size)
            #expect(abs(frame.width - size.width) < 0.5, "index \(i) width mismatch")
            #expect(abs(frame.height - size.height) < 0.5, "index \(i) height mismatch")
        }
    }

    @Test func wrapsToNewColumnWhenBelowScreen() {
        let smallScreen = CGRect(x: 0, y: 0, width: 800, height: 300)
        let smallSize = CGSize(width: 220, height: 220)
        for i in 0..<5 {
            let frame = StickyLayout.frame(index: i, in: smallScreen, size: smallSize)
            #expect(frame.intersects(smallScreen), "index \(i) should still intersect screen after wrap")
        }
    }

    @Test func customMarginAndStep() {
        let f0 = StickyLayout.frame(index: 0, in: screen, size: size, margin: 20, step: 25)
        let expectedX = screen.maxX - size.width - 20
        let expectedY = screen.maxY - size.height - 20
        #expect(abs(f0.origin.x - expectedX) < 0.5)
        #expect(abs(f0.origin.y - expectedY) < 0.5)

        let f1 = StickyLayout.frame(index: 1, in: screen, size: size, margin: 20, step: 25)
        #expect(abs(f1.origin.x - (f0.origin.x - 25)) < 0.5)
        #expect(abs(f1.origin.y - (f0.origin.y - 25)) < 0.5)
    }
}
