import SwiftUI
import GRDB
import AppKit

@MainActor
@Observable
final class ClipboardViewModel {
    var items: [ClipItem] = []
    var query: String = ""

    private let db: StashDatabase
    private let store: ClipboardStore
    private let monitor: ClipboardMonitor
    private var observationTask: Task<Void, Never>?

    init(db: StashDatabase, store: ClipboardStore, monitor: ClipboardMonitor) {
        self.db = db
        self.store = store
        self.monitor = monitor
    }

    var pinned: [ClipItem] { items.filter { $0.pinned && Self.matches($0, query: query) } }
    var recent: [ClipItem] { items.filter { !$0.pinned && Self.matches($0, query: query) } }

    nonisolated static func matches(_ item: ClipItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return (item.title?.lowercased().contains(q) ?? false)
            || (item.text?.lowercased().contains(q) ?? false)
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try ClipItem.order(Column("pinned").desc, Column("created_at").desc).fetchAll(db)
        }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await rows in observation.values(in: self.db.pool) {
                    self.items = rows
                }
            } catch {
                #if DEBUG
                print("ClipboardViewModel observation error:", error)
                #endif
            }
        }
    }

    func togglePin(_ item: ClipItem) async {
        try? await store.setPinned(id: item.id, pinned: !item.pinned)
    }

    func delete(_ item: ClipItem) async {
        try? await store.delete(id: item.id)
    }

    func clearAll() async {
        try? await store.clearAll()
    }

    func clearUnpinned() async {
        try? await store.clearUnpinned()
    }

    func copyBack(_ item: ClipItem) async {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.kind == .image, let path = item.previewPath {
            let full = ThumbnailCache.fullPath(forThumbPath: path)
            if let img = NSImage(contentsOfFile: full) ?? NSImage(contentsOfFile: path) {
                pb.writeObjects([img])
            }
        } else if let text = item.text {
            pb.setString(text, forType: .string)
        }
        await monitor.noteSelfCopy(changeCount: pb.changeCount)
    }
}
