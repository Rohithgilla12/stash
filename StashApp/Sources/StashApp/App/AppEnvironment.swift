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
    let aiAssistant = AIAssistant()
    let scheduler = TaskReminderScheduler()
    let pomodoro = PomodoroTimer()
    private let systemExpander = SystemExpander()
    private let monitor: ClipboardMonitor
    private var stickyManager: StickyNotesManager!
    private let db: StashDatabase
    private var stickyObservationTask: Task<Void, Never>?
    let snapper = WindowSnapper()
    private var snapHotKeys: [GlobalHotKey] = []
    private var presetHotKeys: [GlobalHotKey] = []
    let windowPresetStore: WindowPresetStore
    var windowPresets: [WindowPreset] = []
    private var presetObservationTask: Task<Void, Never>?
    let savedLayoutStore: SavedLayoutStore
    var savedLayouts: [SavedLayout] = []
    private var layoutObservationTask: Task<Void, Never>?
    private let pasteBrowser = PasteBrowserController()
    private let quickCapture = QuickCaptureController()

    var requestOpenWindow: ((String) -> Void)?

    var globalHotkeysEnabled: Bool = true {
        didSet {
            guard hotkeysSettingLoaded else { return }
            UserDefaults.standard.set(globalHotkeysEnabled, forKey: "globalHotkeysEnabled")
            applyHotkeys()
        }
    }
    private var hotkeysSettingLoaded = false

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
        self.windowPresetStore = WindowPresetStore(pool: database.pool)
        self.savedLayoutStore = SavedLayoutStore(pool: database.pool)
        self.aiViewModel = AIViewModel(reader: ClaudeTranscriptReader())

        self.stickyManager = StickyNotesManager(
            onToggleItem: { [weak notesVM] note, _ in Task { await notesVM?.update(note) } },
            onOpenNote: { [weak self] note in
                self?.notesViewModel.selectedId = note.id
                self?.requestOpenWindow?("notes")
            }
        )

        tasksViewModel.onTasksChanged = { [weak self] tasks in
            Task { await self?.scheduler.sync(tasks) }
        }
        wireExpander()
        wirePasteBrowser()
        wireQuickCapture()
        globalHotkeysEnabled = UserDefaults.standard.object(forKey: "globalHotkeysEnabled") as? Bool ?? true
        hotkeysSettingLoaded = true
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
            if (q("action") ?? "").lowercased() == "nextdisplay" {
                snapper.moveToNextDisplay()
                return
            }
            if let name = q("preset"),
               let preset = windowPresets.first(where: { $0.name.lowercased() == name.lowercased() }) {
                snapper.snap(preset)
            } else if let raw = q("target") ?? url.pathComponents.dropFirst(2).first,
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
        case "capture":
            if let text = q("text"), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                quickSave(text, asTask: (q("type")?.lowercased() != "note"))
            } else {
                quickCapture.show()
            }
        default:
            break
        }
    }

    private func wirePasteBrowser() {
        pasteBrowser.itemsProvider = { [weak self] in self?.viewModel.items ?? [] }
        pasteBrowser.onPin = { [weak self] item in
            Task { await self?.viewModel.togglePin(item) }
        }
        pasteBrowser.onDelete = { [weak self] item in
            Task { await self?.viewModel.delete(item) }
        }
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

    func completeTask(id: String) async {
        guard let task = tasksViewModel.tasks.first(where: { $0.id == id }) else { return }
        await tasksViewModel.toggle(task)
    }

    private func syncRemindersIfAuthorized() async {
        guard await scheduler.authorizationStatus() == .authorized else { return }
        await scheduler.sync(tasksViewModel.tasks)
    }

    func start() {
        viewModel.startObserving()
        notesViewModel.startObserving()
        tasksViewModel.startObserving()
        snippetsViewModel.startObserving()
        Task { await monitor.start() }
        Task { await snippetsViewModel.seed() }
        Task { await self.syncRemindersIfAuthorized() }
        startStickyObservation()
        startPresetObservation()
        startLayoutObservation()
        applyHotkeys()
        // Do NOT prompt for Accessibility at launch — only when the user actually
        // uses a feature that needs it (a snap hotkey, or enabling the expander),
        // and then at most once per launch (see AccessibilityAuthorizer).
        if snippetsViewModel.expanderEnabled {
            systemExpander.setEnabled(true)
        }
    }

    func showQuickCapture() {
        quickCapture.show()
    }

    private func quickSave(_ text: String, asTask: Bool) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if asTask {
            Task { await tasksViewModel.add(t) }
        } else {
            Task {
                if let note = await notesViewModel.newNote() {
                    var n = note
                    n.title = String(t.split(separator: "\n").first.map(String.init) ?? t).prefix(80).description
                    n.body = t
                    await notesViewModel.update(n)
                }
            }
        }
    }

    private func wireQuickCapture() {
        quickCapture.onSave = { [weak self] text, asTask in
            self?.quickSave(text, asTask: asTask)
        }
    }

    private func applyHotkeys() {
        if globalHotkeysEnabled {
            stickyManager.registerHotKey()
            pasteBrowser.registerHotKey()
            quickCapture.registerHotKey()
            registerSnapHotKeys()
            registerPresetHotKeys()
        } else {
            stickyManager.unregisterHotKey()
            pasteBrowser.unregisterHotKey()
            quickCapture.unregisterHotKey()
            snapHotKeys = []
            presetHotKeys = []
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

    private func registerPresetHotKeys() {
        presetHotKeys = []
        guard globalHotkeysEnabled else { return }
        var registered: [GlobalHotKey] = []
        for preset in windowPresets {
            guard let code = preset.hotkeyKeyCode, let mods = preset.hotkeyModifiers else { continue }
            let captured = preset
            if let key = GlobalHotKey(keyCode: UInt32(code), modifiers: UInt32(mods), handler: { [weak self] in
                self?.snapper.snap(captured)
            }) {
                registered.append(key)
            } else {
                #if DEBUG
                print("[Stash] Could not register hotkey for preset '\(preset.name)' (combo already claimed?)")
                #endif
            }
        }
        presetHotKeys = registered
        #if DEBUG
        print("[Stash] Preset hotkeys registered: \(registered.count)/\(windowPresets.filter { $0.hotkeyKeyCode != nil && $0.hotkeyModifiers != nil }.count)")
        #endif
    }

    private func startPresetObservation() {
        guard presetObservationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try WindowPreset.order(Column("created_at"), Column("id")).fetchAll(db)
        }
        presetObservationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await presets in observation.values(in: self.db.pool) {
                    await MainActor.run {
                        self.windowPresets = presets
                        self.registerPresetHotKeys()
                    }
                }
            } catch {
                #if DEBUG
                print("WindowPreset observation error:", error)
                #endif
            }
        }
    }

    func saveWindowPreset(_ preset: WindowPreset) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.windowPresetStore.upsert(preset)
            } catch {
                #if DEBUG
                print("saveWindowPreset failed:", error)
                #endif
            }
        }
    }

    func deleteWindowPreset(id: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.windowPresetStore.delete(id: id)
            } catch {
                #if DEBUG
                print("deleteWindowPreset failed:", error)
                #endif
            }
        }
    }

    private func startLayoutObservation() {
        guard layoutObservationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try SavedLayout.order(Column("created_at"), Column("id")).fetchAll(db)
        }
        layoutObservationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await layouts in observation.values(in: self.db.pool) {
                    await MainActor.run {
                        self.savedLayouts = layouts
                    }
                }
            } catch {
                #if DEBUG
                print("SavedLayout observation error:", error)
                #endif
            }
        }
    }

    func saveCurrentLayout(name: String) {
        let entries = snapper.captureCurrentLayout()
        guard !entries.isEmpty else { return }
        let existing = savedLayouts.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let layout = SavedLayout(
            id: existing?.id ?? UUID().uuidString,
            name: name,
            entriesJSON: SavedLayout.encode(entries),
            hotkeyKeyCode: existing?.hotkeyKeyCode,
            hotkeyModifiers: existing?.hotkeyModifiers,
            createdAt: existing?.createdAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        )
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.savedLayoutStore.upsert(layout)
            } catch {
                #if DEBUG
                print("saveCurrentLayout failed:", error)
                #endif
            }
        }
    }

    func deleteLayout(id: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.savedLayoutStore.delete(id: id)
            } catch {
                #if DEBUG
                print("deleteLayout failed:", error)
                #endif
            }
        }
    }

    func recallLayout(_ layout: SavedLayout) async -> WindowSnapper.LayoutRecallSummary {
        return await snapper.recall(layout.entries)
    }

    func renameLayout(_ layout: SavedLayout, name: String) {
        var updated = layout
        updated.name = name
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.savedLayoutStore.upsert(updated)
            } catch {
                #if DEBUG
                print("renameLayout failed:", error)
                #endif
            }
        }
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
