import SwiftUI
import GRDB

@MainActor
@Observable
final class AppEnvironment {
    /// Set in init so the URL-scheme handler (AppDelegate) can reach the live instance.
    static weak var shared: AppEnvironment?

    let viewModel: ClipboardViewModel
    let notesViewModel: NotesViewModel
    let tasksViewModel: TasksViewModel
    let snippetsViewModel: SnippetsViewModel
    let aiViewModel: AIViewModel
    let pomodoro = PomodoroTimer()
    private let systemExpander = SystemExpander()
    private let monitor: ClipboardMonitor
    private let stickyManager: StickyNotesManager
    private let db: StashDatabase
    private var stickyObservationTask: Task<Void, Never>?
    private let snapper = WindowSnapper()
    private var snapHotKeys: [GlobalHotKey] = []
    private let pasteBrowser = PasteBrowserController()

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
        wirePasteBrowser()
        start()
        AppEnvironment.shared = self
    }

    /// Handles `stash://` deeplinks (so Karabiner / Shortcuts / `open` can drive any
    /// action without relying on Stash's built-in global hotkeys).
    ///   stash://paste                          — toggle the Paste browser
    ///   stash://snap?target=leftHalf           — snap the focused window (SnapTarget rawValue)
    ///   stash://stickies                       — toggle desktop sticky notes
    ///   stash://expander?state=on|off|toggle   — system-wide text expander
    ///   stash://note?title=...&body=...        — create a note
    ///   stash://task?title=...                 — create a task (due Today)
    func handleDeeplink(_ url: URL) {
        guard url.scheme == "stash" else { return }
        // The action is the host (stash://paste) or the first path segment.
        let action = (url.host?.isEmpty == false ? url.host : nil)
            ?? url.pathComponents.first(where: { $0 != "/" })
            ?? ""
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        func q(_ name: String) -> String? { comps?.queryItems?.first { $0.name == name }?.value }

        switch action.lowercased() {
        case "paste":
            pasteBrowser.toggle()
        case "snap":
            if let raw = q("target") ?? url.pathComponents.dropFirst(2).first,
               let target = SnapTarget(rawValue: raw) {
                snapper.snap(target)
            }
        case "stickies":
            stickyManager.toggleVisibility()
        case "expander":
            switch (q("state") ?? "toggle").lowercased() {
            case "on": snippetsViewModel.expanderEnabled = true
            case "off": snippetsViewModel.expanderEnabled = false
            default: snippetsViewModel.expanderEnabled.toggle()
            }
        case "note":
            let title = q("title"); let body = q("body")
            Task { [weak self] in
                if let note = await self?.notesViewModel.newNote() {
                    var n = note
                    if let title { n.title = title }
                    if let body { n.body = body }
                    if title != nil || body != nil { await self?.notesViewModel.update(n) }
                    self?.notesViewModel.selectedId = n.id
                }
            }
        case "task":
            if let title = q("title"), !title.isEmpty {
                Task { [weak self] in await self?.tasksViewModel.add(title) }
            }
        default:
            break
        }
    }

    private func wirePasteBrowser() {
        pasteBrowser.itemsProvider = { [weak self] in self?.viewModel.items ?? [] }
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
        pasteBrowser.registerHotKey()
        registerSnapHotKeys()
        // Do NOT prompt for Accessibility at launch — only when the user actually
        // uses a feature that needs it (a snap hotkey, or enabling the expander),
        // and then at most once per launch (see AccessibilityAuthorizer).
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
