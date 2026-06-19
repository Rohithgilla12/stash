import SwiftUI
import ServiceManagement

@MainActor
struct PreferencesView: View {
    let env: AppEnvironment

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var linkPreviewsEnabled: Bool =
        UserDefaults.standard.object(forKey: "linkPreviewsEnabled") as? Bool ?? true
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            generalSection
            clipboardSection
            textExpansionSection
            aboutSection
        }
        .formStyle(.grouped)
        .tint(Tokens.accent)
        .frame(width: 480, height: 420)
    }

    @ViewBuilder private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility")
                    Text(AccessibilityAuthorizer.isTrusted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(AccessibilityAuthorizer.isTrusted ? Color.green : Color.secondary)
                }
                Spacer()
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
            }
        }
    }

    @ViewBuilder private var clipboardSection: some View {
        Section("Clipboard") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Link previews", isOn: $linkPreviewsEnabled)
                    .onChange(of: linkPreviewsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "linkPreviewsEnabled")
                    }
                Text("Fetches title and image for copied links over the network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Clear History…") {
                showClearConfirm = true
            }
            .foregroundStyle(.red)
            .confirmationDialog(
                "Clear clipboard history?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear (keep pinned)", role: .destructive) {
                    Task { await env.viewModel.clearUnpinned() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    @ViewBuilder private var textExpansionSection: some View {
        Section("Text Expansion") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(
                    "Expand snippets system-wide",
                    isOn: Binding(
                        get: { env.snippetsViewModel.expanderEnabled },
                        set: { env.snippetsViewModel.expanderEnabled = $0 }
                    )
                )
                Text("Requires Accessibility permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Stash").font(.headline)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
            }

            Link(
                "View on GitHub",
                destination: URL(string: "https://github.com/Rohithgilla12/stash")!
            )
            .tint(Tokens.accent)
        }
    }
}
