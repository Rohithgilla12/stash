import AppKit
import Foundation

struct ThumbnailCache: Sendable {
    let dir: URL
    init(dir: URL) { self.dir = dir }

    func store(_ image: NSImage, id: String) throws -> (fullPath: String, thumbPath: String) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let full = dir.appendingPathComponent("\(id).png")
        let thumb = dir.appendingPathComponent("\(id)_thumb.png")
        try png(from: resized(image, maxEdge: 1024)).write(to: full)
        try png(from: resized(image, fitting: Tokens.thumbSize)).write(to: thumb)
        return (full.path, thumb.path)
    }

    private func png(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    private func resized(_ image: NSImage, maxEdge: CGFloat) -> NSImage {
        let s = image.size
        let scale = min(1, maxEdge / max(max(s.width, s.height), 1))
        return scaled(image, to: NSSize(width: s.width * scale, height: s.height * scale))
    }

    private func resized(_ image: NSImage, fitting box: CGSize) -> NSImage {
        let s = image.size
        let scale = min(box.width / max(s.width, 1), box.height / max(s.height, 1))
        return scaled(image, to: NSSize(width: s.width * scale, height: s.height * scale))
    }

    private func scaled(_ image: NSImage, to size: NSSize) -> NSImage {
        let out = NSImage(size: size)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
