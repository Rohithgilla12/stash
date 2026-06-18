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
    #expect(thumb.size.height <= 38.5)
}

@Test func fullPathFromThumbPath() {
    #expect(ThumbnailCache.fullPath(forThumbPath: "/x/abc_thumb.png") == "/x/abc.png")
    #expect(ThumbnailCache.fullPath(forThumbPath: "/x/abc.png") == "/x/abc.png")
    #expect(ThumbnailCache.fullPath(forThumbPath: "/x/no_suffix") == "/x/no_suffix")
}

@Test func deleteRemovesBothFiles() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cache = ThumbnailCache(dir: tmp)
    let img = NSImage(size: NSSize(width: 100, height: 100))
    img.lockFocus(); NSColor.blue.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 100, height: 100)).fill(); img.unlockFocus()

    let paths = try cache.store(img, id: "d")
    #expect(FileManager.default.fileExists(atPath: paths.fullPath))
    #expect(FileManager.default.fileExists(atPath: paths.thumbPath))

    cache.delete(thumbPath: paths.thumbPath)
    #expect(!FileManager.default.fileExists(atPath: paths.fullPath))
    #expect(!FileManager.default.fileExists(atPath: paths.thumbPath))
}
