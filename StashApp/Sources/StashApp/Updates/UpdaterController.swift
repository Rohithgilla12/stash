import Sparkle
import Combine

/// Owns the Sparkle updater for the app's lifetime.
@MainActor
final class UpdaterController: ObservableObject {
    let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
        // Dev builds must NOT auto-update: they're ad-hoc-signed with a different
        // bundle id, so Sparkle correctly rejects the notarized prod release as
        // "improperly signed". Only the Release build runs the updater.
        #if DEV
        let autoStart = false
        #else
        let autoStart = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: autoStart,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
