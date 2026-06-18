import SwiftUI

@main
struct StashApp: App {
    var body: some Scene {
        MenuBarExtra("Stash", systemImage: "tray.full") {
            Text("Stash")
                .padding()
                .frame(width: 456)
        }
        .menuBarExtraStyle(.window)
    }
}
