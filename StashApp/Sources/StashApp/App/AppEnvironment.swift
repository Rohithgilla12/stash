import SwiftUI
import GRDB

@MainActor
@Observable
final class AppEnvironment {
    let viewModel: ClipboardViewModel
    let notesViewModel: NotesViewModel
    let tasksViewModel: TasksViewModel
    let snippetsViewModel: SnippetsViewModel
    let aiViewModel: AIViewModel
    private let systemExpander = SystemExpander()
    private let monitor: ClipboardMonitor
    private let stickyManager: StickyNotesManager
    private let db: StashDatabase
    private var stickyObservationTask: Task<Void, Never>?
    private let snapper = WindowSnapper()
    private var snapHotKeys: [GlobalHotKey] = []

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
        self.aiViewModel = AIViewModel(reader: ClaudeTranscriptReader())

        self.stickyManager = StickyNotesManager(
            onToggleItem: { [weak notesVM] note, _ in Task { await notesVM?.update(note) } },
            onOpenNote: { [weak notesVM] note in notesVM?.selectedId = note.id }
        )

        wireExpander()
        start()
    }

    private func wireExpander() {
        let expander = systemExpander
        snippetsViewModel.onExpanderToggled = { [weak expander] isOn in
            expander?.setEnabled(isOn) ?? false
        }
        snippetsViewModel.onSnippetsChanged = { [weak expander] snippets in
            expander?.snippets = snippets
        }
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
        registerSnapHotKeys()
        if !snapper.isTrusted { snapper.ensureTrusted() }
        if snippetsViewModel.expanderEnabled {
            systemExpander.setEnabled(true)
        }
    }

    private func registerSnapHotKeys() {
        var registered: [GlobalHotKey] = []
        for hk in SnapHotKey.all {
            if let key = GlobalHotKey(keyCode: hk.keyCode, modifiers: hk.modifiers, handler: { [weak self] in
                self?.snapper.snap(hk.target)
            }) {
                registered.append(key)
            } else {
                #if DEBUG
                print("[Stash] Could not register snap hotkey for \(hk.target) (combo already claimed?)")
                #endif
            }
        }
        snapHotKeys = registered
        #if DEBUG
        print("[Stash] Snap hotkeys registered: \(registered.count)/\(SnapHotKey.all.count)")
        #endif
    }

    private func startStickyObservation() {
        guard stickyObservationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try Note.filter(Column("on_desktop") == true).fetchAll(db)
        }
        stickyObservationTask = Task { [weak self] in
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
