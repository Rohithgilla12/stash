import AppKit

actor ClipboardMonitor {
    private let store: ClipboardStore
    private let cache: ThumbnailCache
    private let pasteboard: PasteboardReading
    private let now: @Sendable () -> Int64
    private let makeID: @Sendable () -> String

    private var lastSeenChangeCount: Int?
    private var ignoreChangeCount: Int?
    private var loop: Task<Void, Never>?

    init(store: ClipboardStore, cache: ThumbnailCache, pasteboard: PasteboardReading,
         now: @Sendable @escaping () -> Int64, makeID: @Sendable @escaping () -> String) {
        self.store = store
        self.cache = cache
        self.pasteboard = pasteboard
        self.now = now
        self.makeID = makeID
    }

    func noteSelfCopy(changeCount: Int) { ignoreChangeCount = changeCount }

    @discardableResult
    func capture(frontApp: String?, frontAppBundleID: String? = nil) async -> Bool {
        let cc = pasteboard.changeCount
        if cc == lastSeenChangeCount { return false }
        lastSeenChangeCount = cc
        if cc == ignoreChangeCount { ignoreChangeCount = nil; return false }
        if pasteboard.isConcealed() { return false }
        if frontAppBundleID == Bundle.main.bundleIdentifier { return false }
        guard let content = ClipClassifier.classify(pasteboard) else { return false }

        let id = makeID()
        var item = ClipItem(id: id, kind: .text, text: nil, app: frontApp,
                            pinned: false, createdAt: now(), title: nil, previewPath: nil,
                            appBundleID: frontAppBundleID)
        switch content {
        case let .text(s):
            item.kind = .text; item.text = s
            item.title = String(s.split(separator: "\n").first ?? "").prefix(120).description
        case let .link(url):
            item.kind = .link; item.text = url.absoluteString; item.title = url.host
        case let .image(img, name):
            item.kind = .image; item.text = name
            item.title = name ?? "Image"
            if let img, let paths = try? cache.store(img, id: id) {
                item.previewPath = paths.thumbPath
            }
        }
        do {
            let removed = try await store.insert(item)
            for path in removed { cache.delete(thumbPath: path) }
            return true
        } catch { return false }
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let front = await MainActor.run {
                    (NSWorkspace.shared.frontmostApplication?.localizedName,
                     NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
                }
                await self?.capture(frontApp: front.0, frontAppBundleID: front.1)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() { loop?.cancel(); loop = nil }
}
