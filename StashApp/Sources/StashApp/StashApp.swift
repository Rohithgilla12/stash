import SwiftUI

@main
struct StashApp: App {
    @State private var env = AppEnvironment()
    @State private var selection: HubTab = .clipboard

    var body: some Scene {
        MenuBarExtra("Stash", systemImage: "tray.full") {
            ContentView(env: env, selection: $selection)
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
    }
}

@MainActor
private struct ContentView: View {
    let env: AppEnvironment
    @Bindable var viewModel: ClipboardViewModel
    @Binding var selection: HubTab

    init(env: AppEnvironment, selection: Binding<HubTab>) {
        self.env = env
        self.viewModel = env.viewModel
        self._selection = selection
    }

    var body: some View {
        HubView(selection: $selection, query: $viewModel.query) {
            switch selection {
            case .clipboard: ClipboardTab(model: env.viewModel)
            case .notes: NotesTab(model: env.notesViewModel)
            case .todos: TodosTab(model: env.tasksViewModel)
            default: ComingSoonView(tab: selection)
            }
        }
    }
}
