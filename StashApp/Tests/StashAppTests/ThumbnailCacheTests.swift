import Testing
import AppKit
import Foundation
@testable import StashApp

@Test func storesThumbAndFull() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cache = ThumbnailCache(dir: tmp)
    let img = NSImage(size: NSSize(width: 400, height: 300))
    img.lockFocus(); NSColor.red.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 400, height: 300)).fill(); img.unlockFocus()

    let paths = try cache.store(img, id: "abc")
    #expect(FileManager.default.fileExists(atPath: paths.fullPath))
    #expect(FileManager.default.fileExists(atPath: paths.thumbPath))

    let thumb = NSImage(contentsOfFile: paths.thumbPath)!
    #expect(thumb.size.width <= 58.5)
}
