import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let viewModel: ClipboardViewModel
    let notesViewModel: NotesViewModel
    let tasksViewModel: TasksViewModel
    let snippetsViewModel: SnippetsViewModel
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
        let tasksStore = TasksStore(pool: db.pool)
        self.tasksViewModel = TasksViewModel(db: db.pool, store: tasksStore)
        let snippetsStore = SnippetsStore(pool: db.pool)
        self.snippetsViewModel = SnippetsViewModel(db: db.pool, store: snippetsStore)
        // MenuBarExtra content is lazy, so start capture eagerly here; start() is idempotent.
        start()
    }

    func start() {
        viewModel.startObserving()
        notesViewModel.startObserving()
        tasksViewModel.startObserving()
        snippetsViewModel.startObserving()
        Task { await monitor.start() }
        Task { await snippetsViewModel.seed() }
    }
}
