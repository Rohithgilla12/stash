import SwiftUI
import ServiceManagement
import UserNotifications
import UniformTypeIdentifiers

@MainActor
struct PreferencesView: View {
    let env: AppEnvironment
    let updater: UpdaterController

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var linkPreviewsEnabled: Bool =
        UserDefaults.standard.object(forKey: "linkPreviewsEnabled") as? Bool ?? true
    @State private var showClearConfirm = false
    @State private var reminderStatus: UNAuthorizationStatus = .notDetermined
    @State private var ignoredBundleIDs: [String] = []

    var body: some View {
        Form {
            generalSection
            clipboardSection
            textExpansionSection
            keyboardShortcutsSection
            softwareUpdateSection
            aboutSection
        }
        .formStyle(.grouped)
        .tint(Tokens.accent)
        .frame(width: 480, height: 620)
        .onAppear { ignoredBundleIDs = ClipboardIgnoreList.bundleIDs }
    }

    private var reminderStatusText: String {
        switch reminderStatus {
        case .authorized: return "On"
        case .denied: return "Denied — open Settings"
        default: return "Not enabled"
        }
    }

    private var reminderStatusColor: Color {
        switch reminderStatus {
        case .authorized: return Color.green
        default: return Color.secondary
        }
    }

    private var reminderButtonTitle: String {
        switch reminderStatus {
        case .notDetermined: return "Enable Reminders"
        case .denied: return "Open Notification Settings"
        default: return ""
        }
    }

    private func reminderButtonAction() {
        Task {
            if reminderStatus == .notDetermined {
                _ = await env.scheduler.requestAuthorization()
                await env.scheduler.sync(env.tasksViewModel.tasks)
            } else if reminderStatus == .denied {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                )
            }
            await loadReminderStatus()
        }
    }

    private func loadReminderStatus() async {
        reminderStatus = await env.scheduler.authorizationStatus()
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

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input Monitoring")
                    Text(AccessibilityAuthorizer.inputMonitoringGranted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundStyle(
                            AccessibilityAuthorizer.inputMonitoringGranted ? Color.green : Color.secondary
                        )
                    Text("Needed (with Accessibility) for the system-wide text expander.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Input Monitoring Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
                    )
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Task reminders")
                    Text(reminderStatusText)
                        .font(.caption)
                        .foregroundStyle(reminderStatusColor)
                    Text("Get notified when a task is due.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if reminderStatus != .authorized {
                    Button(reminderButtonTitle) {
                        reminderButtonAction()
                    }
                }
            }
            .task { await loadReminderStatus() }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome tour")
                    Text("Revisit the setup guide.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show") {
                    env.requestOpenWindow?("onboarding")
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

            ignoredAppsSubsection
        }
    }

    @ViewBuilder private var ignoredAppsSubsection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ignored Apps")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Clipboard from these apps is never saved to history.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if ignoredBundleIDs.isEmpty {
                ignoredAppsEmptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(ignoredBundleIDs, id: \.self) { bundleID in
                        ignoredAppRow(bundleID: bundleID)
                    }
                }
                .background(Tokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.rowRadius))
            }

            Button("Add App…") {
                addIgnoredApp()
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var ignoredAppsEmptyState: some View {
        Text("No ignored apps.")
            .font(.caption)
            .foregroundStyle(Tokens.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }

    @ViewBuilder private func ignoredAppRow(bundleID: String) -> some View {
        HStack(spacing: 8) {
            if let nsImage = AppIconProvider.icon(forBundleID: bundleID) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }

            Text(displayName(for: bundleID))
                .lineLimit(1)

            Spacer()

            Button {
                ClipboardIgnoreList.remove(bundleID)
                ignoredBundleIDs = ClipboardIgnoreList.bundleIDs
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from ignored apps")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url)
        else { return bundleID }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundleID
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let id = Bundle(url: url)?.bundleIdentifier else { return }
                ClipboardIgnoreList.add(id)
                ignoredBundleIDs = ClipboardIgnoreList.bundleIDs
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

    @ViewBuilder private var keyboardShortcutsSection: some View {
        Section("Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(
                    "Built-in global shortcuts",
                    isOn: Binding(
                        get: { env.globalHotkeysEnabled },
                        set: { env.globalHotkeysEnabled = $0 }
                    )
                )
                Text("⌃⌥S sticky notes · ⌃⌥V paste browser · ⌃⌥ arrows window snapping. Turn off if you trigger Stash via stash:// deeplinks or Karabiner. (The text-expander toggle above is separate.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var softwareUpdateSection: some View {
        Section("Software Update") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stash")
                        .font(.headline)
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }

            VStack(alignment: .leading, spacing: 4) {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                )
                Text("Updates are downloaded from GitHub and verified before installing.")
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
