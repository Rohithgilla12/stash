import SwiftUI

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env = AppEnvironment()
    @StateObject private var updater = UpdaterController()
    @State private var selection: HubTab = .clipboard

    var body: some Scene {
        MenuBarExtra {
            ContentView(env: env, selection: $selection, checkForUpdates: { updater.checkForUpdates() })
        } label: {
            if env.pomodoro.isRunning {
                Text(env.pomodoro.display)
            } else {
                #if DEV
                Image(systemName: "hammer.fill")   // dev build — distinct from prod's tray
                #else
                Image(systemName: "tray.full")
                #endif
            }
        }
        .menuBarExtraStyle(.window)

        Window("Notes", id: "notes") {
            NotesWindow(model: env.notesViewModel)
                .frame(minWidth: 560, idealWidth: 560, minHeight: 520, idealHeight: 520)
        }
        .windowResizability(.contentSize)

        Window("Tasks", id: "tasks") {
            TasksWindow(model: env.tasksViewModel)
        }
        .windowResizability(.contentSize)

        Window("Stash Preferences", id: "preferences") {
            PreferencesView(env: env, updater: updater)
                .frame(width: 480, height: 420)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
private struct PaletteOverlay: View {
    let env: AppEnvironment
    let openWindow: OpenWindowAction
    let onClose: () -> Void
    let checkForUpdates: (() -> Void)?

    var body: some View {
        CommandPaletteView(
            items: CommandPalette.items(
                env: env,
                openWindow: openWindow,
                dismiss: onClose,
                checkForUpdates: checkForUpdates
            ),
            onClose: onClose
        )
    }
}

@MainActor
private struct ContentView: View {
    let env: AppEnvironment
    let checkForUpdates: () -> Void
    @Bindable var viewModel: ClipboardViewModel
    @Binding var selection: HubTab
    @Environment(\.openWindow) private var openWindow
    @State private var showPalette = false

    init(env: AppEnvironment, selection: Binding<HubTab>, checkForUpdates: @escaping () -> Void) {
        self.env = env
        self.checkForUpdates = checkForUpdates
        self.viewModel = env.viewModel
        self._selection = selection
    }

    var body: some View {
        HubView(
            selection: $selection,
            query: $viewModel.query,
            onPreferences: { openWindow.openActivating(id: "preferences") }
        ) {
            switch selection {
            case .clipboard: ClipboardTab(model: env.viewModel)
            case .notes: NotesTab(model: env.notesViewModel)
            case .todos: TodosTab(model: env.tasksViewModel)
            case .focus: FocusTab(timer: env.pomodoro)
            case .snippets: SnippetsTab(model: env.snippetsViewModel)
            case .windows: WindowsTab()
            case .ai: AITab(model: env.aiViewModel, assistant: env.aiAssistant, env: env)
            }
        }
        .overlay {
            if showPalette {
                PaletteOverlay(env: env, openWindow: openWindow, onClose: { showPalette = false }, checkForUpdates: checkForUpdates)
            }
        }
        .background {
            Button("") { showPalette.toggle() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        }
    }
}
