import AppKit

enum CapturedContent: Equatable {
    case text(String)
    case link(URL)
    case image(NSImage?, suggestedName: String?)

    static func == (lhs: CapturedContent, rhs: CapturedContent) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)): return a == b
        case let (.link(a), .link(b)): return a == b
        case let (.image(_, a), .image(_, b)): return a == b
        default: return false
        }
    }
}

enum ClipClassifier {
    static func classify(_ pb: PasteboardReading) -> CapturedContent? {
        if let url = pb.fileURL(), isImageFile(url) {
            return .image(NSImage(contentsOf: url), suggestedName: url.lastPathComponent)
        }
        if let img = pb.image() {
            return .image(img, suggestedName: nil)
        }
        if let s = pb.string() {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if let url = asWebURL(trimmed) { return .link(url) }
            return .text(s)
        }
        return nil
    }

    private static func isImageFile(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "tiff", "heic", "webp"].contains(url.pathExtension.lowercased())
    }

    private static func asWebURL(_ s: String) -> URL? {
        guard !s.contains(" "), let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }
}
