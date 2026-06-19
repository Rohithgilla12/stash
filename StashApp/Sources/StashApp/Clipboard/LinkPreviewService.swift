import AppKit
import CryptoKit
import Foundation
import LinkPresentation

// LPLinkMetadata and NSItemProvider predate Sendable and are not annotated as such.
// These boxes are single-use bridges from the LP/NSItemProvider completion callbacks
// into Swift concurrency. @unchecked Sendable is the standard workaround for bridging
// Objective-C framework types that have not yet adopted Sendable.
private struct MetadataBox: @unchecked Sendable {
    let title: String?
    let imageProvider: NSItemProvider?
}

private struct ImageBox: @unchecked Sendable {
    let image: NSImage?
}

@MainActor final class LinkPreviewService {
    static let shared = LinkPreviewService()

    private let cacheDir: URL
    private var memoryCache: [String: LinkPreview] = [:]

    private init() {
        cacheDir = AppPaths.cacheDir().appendingPathComponent("linkpreviews")
    }

    func preview(for urlString: String) async -> LinkPreview? {
        let key = cacheKey(for: urlString)

        if let cached = memoryCache[key] { return cached }

        let jsonURL = cacheDir.appendingPathComponent("\(key).json")
        if let data = try? Data(contentsOf: jsonURL),
           let stored = try? JSONDecoder().decode(LinkPreview.self, from: data) {
            memoryCache[key] = stored
            return stored
        }

        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            return nil
        }

        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = false

        let box = await withCheckedContinuation { (continuation: CheckedContinuation<MetadataBox?, Never>) in
            nonisolated(unsafe) var resumed = false
            provider.startFetchingMetadata(for: url) { [provider] meta, _ in
                _ = provider
                guard !resumed else { return }
                resumed = true
                guard let meta else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: MetadataBox(title: meta.title, imageProvider: meta.imageProvider))
            }
        }

        guard let box else {
            let result = LinkPreview(title: nil, domain: url.host, imagePath: nil, failed: true)
            persist(result, key: key)
            return result
        }

        let ogTitle = box.title
        let domain = url.host?.replacingOccurrences(of: "www.", with: "")

        var imagePath: String? = nil
        if let imageProvider = box.imageProvider {
            let imgBox = await withCheckedContinuation { (continuation: CheckedContinuation<ImageBox, Never>) in
                nonisolated(unsafe) var resumed = false
                imageProvider.loadObject(ofClass: NSImage.self) { obj, _ in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: ImageBox(image: obj as? NSImage))
                }
            }

            if let img = imgBox.image {
                let resized = resizeImage(img, maxEdge: 600)
                let pngURL = cacheDir.appendingPathComponent("\(key).png")
                if let data = try? pngData(from: resized) {
                    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                    try? data.write(to: pngURL)
                    imagePath = pngURL.path
                } else {
                    // TODO: distinguish transient image-load failure from "link has no og:image"
                    // Currently cached as success-no-image; a link with a real og:image that
                    // fails transiently here will never retry until its cache entry is evicted.
                    #if DEBUG
                    print("[LinkPreview] image load failed or unavailable for \(url.host ?? urlString); caching title-only result")
                    #endif
                }
            } else {
                // TODO: distinguish transient image-load failure from "link has no og:image"
                // Currently cached as success-no-image; a link with a real og:image that
                // fails transiently here will never retry until its cache entry is evicted.
                #if DEBUG
                print("[LinkPreview] image load failed or unavailable for \(url.host ?? urlString); caching title-only result")
                #endif
            }
        }

        let result = LinkPreview(title: ogTitle, domain: domain, imagePath: imagePath, failed: false)
        persist(result, key: key)
        return result
    }

    private func cacheKey(for urlString: String) -> String {
        let hash = SHA256.hash(data: Data(urlString.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func persist(_ preview: LinkPreview, key: String) {
        memoryCache[key] = preview
        let jsonURL = cacheDir.appendingPathComponent("\(key).json")
        if let data = try? JSONEncoder().encode(preview) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            try? data.write(to: jsonURL)
        }
    }

    private func resizeImage(_ image: NSImage, maxEdge: CGFloat) -> NSImage {
        let s = image.size
        let scale = min(1.0, maxEdge / max(max(s.width, s.height), 1))
        let newSize = NSSize(width: s.width * scale, height: s.height * scale)
        let out = NSImage(size: newSize)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: s),
                   operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }

    private func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
