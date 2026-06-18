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
            default: ComingSoonView(tab: selection)
            }
        }
    }
}
