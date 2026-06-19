import AppKit

@MainActor
enum AppIconProvider {
    private static var cache: [String: NSImage] = [:]

    static func icon(forBundleID id: String?) -> NSImage? {
        guard let id else { return nil }
        if let cached = cache[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 32, height: 32)
        cache[id] = img
        return img
    }
}
