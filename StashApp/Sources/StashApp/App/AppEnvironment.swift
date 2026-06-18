import SwiftUI
import GRDB

@MainActor
@Observable
final class AppEnvironment {
    let viewModel: ClipboardViewModel
    let notesViewModel: NotesViewModel
    let tasksViewModel: TasksViewModel
    let snippetsViewModel: SnippetsViewModel
    private let monitor: ClipboardMonitor
    private let stickyManager: StickyNotesManager
    private let db: StashDatabase

    init() {
        let database = (try? StashDatabase(path: AppPaths.dbURL().path))
            ?? (try! StashDatabase(path: ":memory:"))
        self.db = database
        let store = ClipboardStore(pool: database.pool)
        let monitor = ClipboardMonitor(
            store: store,
            cache: ThumbnailCache(dir: AppPaths.cacheDir()),
            pasteboard: SystemPasteboard(),
            now: { Int64(Date().timeIntervalSince1970 * 1000) },
            makeID: { UUID().uuidString })
        self.monitor = monitor
        self.viewModel = ClipboardViewModel(db: database, store: store, monitor: monitor)
        let notesStore = NotesStore(pool: database.pool)
        let notesVM = NotesViewModel(db: database, store: notesStore)
        self.notesViewModel = notesVM
        let tasksStore = TasksStore(pool: database.pool)
        self.tasksViewModel = TasksViewModel(db: database.pool, store: tasksStore)
        let snippetsStore = SnippetsStore(pool: database.pool)
        self.snippetsViewModel = SnippetsViewModel(db: database.pool, store: snippetsStore)

        self.stickyManager = StickyNotesManager(
            onToggleItem: { note, _ in
                Task { await notesVM.update(note) }
            },
            onOpenNote: { note in
                notesVM.selectedId = note.id
            }
        )

        start()
    }

    func start() {
        viewModel.startObserving()
        notesViewModel.startObserving()
        tasksViewModel.startObserving()
        snippetsViewModel.startObserving()
        Task { await monitor.start() }
        Task { await snippetsViewModel.seed() }
        startStickyObservation()
        stickyManager.registerHotKey()
    }

    private func startStickyObservation() {
        let observation = ValueObservation.tracking { db in
            try Note.filter(Column("on_desktop") == true).fetchAll(db)
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                for try await notes in observation.values(in: self.db.pool) {
                    await MainActor.run {
                        self.stickyManager.sync(notes: notes)
                    }
                }
            } catch {
                #if DEBUG
                print("StickyNotesManager observation error:", error)
                #endif
            }
        }
    }
}
