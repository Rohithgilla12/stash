import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let viewModel: ClipboardViewModel
    let notesViewModel: NotesViewModel
    private let monitor: ClipboardMonitor

    init() {
        let db = (try? StashDatabase(path: AppPaths.dbURL().path))
            ?? (try! StashDatabase(path: ":memory:"))   // non-fatal fallback
        let store = ClipboardStore(pool: db.pool)
        let monitor = ClipboardMonitor(
            store: store,
            cache: ThumbnailCache(dir: AppPaths.cacheDir()),
            pasteboard: SystemPasteboard(),
            now: { Int64(Date().timeIntervalSince1970 * 1000) },
            makeID: { UUID().uuidString })
        self.monitor = monitor
        self.viewModel = ClipboardViewModel(db: db, store: store, monitor: monitor)
        let notesStore = NotesStore(pool: db.pool)
        self.notesViewModel = NotesViewModel(db: db, store: notesStore)
        // MenuBarExtra content is lazy, so start capture eagerly here; start() is idempotent.
        start()
    }

    func start() {
        viewModel.startObserving()
        notesViewModel.startObserving()
        Task { await monitor.start() }
    }
}
