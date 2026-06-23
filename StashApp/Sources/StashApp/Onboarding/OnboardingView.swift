import SwiftUI
import UserNotifications

@MainActor
struct OnboardingView: View {
    let env: AppEnvironment

    @State private var step: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: shortcutsStep
                default: doneStep
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 0, y: 12)),
                removal: .opacity.combined(with: .offset(x: 0, y: -8))
            ))
            .id(step)

            Spacer()
            footer
        }
        .frame(width: 540, height: 600)
        .background(Tokens.panelFill)
    }

    private var welcomeStep: some View {
        VStack(spacing: Space.lg) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(16)

            Text("Stash")
                .font(.rounded(32, .bold))
                .foregroundStyle(Tokens.accent)

            Text("Your menu-bar command center for clipboard, notes, tasks & snippets")
                .font(.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text("Stash lives up here ↑ in your menu bar")
                .font(.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.xxl)
    }

    private var permissionsStep: some View {
        PermissionsStepView(env: env)
    }

    private var shortcutsStep: some View {
        VStack(spacing: Space.lg) {
            Text("Keyboard Shortcuts")
                .font(.rounded(26, .bold))

            VStack(spacing: Space.sm) {
                ShortcutRow(keys: "⌃⌥V", label: "Paste browser")
                ShortcutRow(keys: "⌃⌥S", label: "Sticky notes")
                ShortcutRow(keys: "⌃⌥C", label: "Quick capture")
                ShortcutRow(keys: "⌘K", label: "Command palette")
            }
            .padding(.horizontal, Space.xl)

            Text("Prefer your own keys? Every action also has a `stash://` deeplink — wire them in Raycast or Karabiner.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(.top, Space.xxl)
    }

    private var doneStep: some View {
        VStack(spacing: Space.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Tokens.running)

            Text("You're all set!")
                .font(.rounded(26, .bold))

            Text("Stash is ready. Open it any time from the menu bar, or use your shortcuts.")
                .font(.ui(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .padding(.top, Space.xxl)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i == step ? Tokens.accent : Tokens.hairline)
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()
            Button(step == 3 ? "Done" : "Next") {
                if step == 3 {
                    dismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { step += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.accent)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
    }
}

@MainActor
private struct PermissionsStepView: View {
    let env: AppEnvironment

    @State private var accessibilityGranted = AccessibilityAuthorizer.isTrusted
    @State private var inputMonitoringGranted = AccessibilityAuthorizer.inputMonitoringGranted
    @State private var notificationsGranted = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Text("Permissions")
                .font(.rounded(26, .bold))

            VStack(spacing: Space.md) {
                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Window snapping + text expansion",
                    isGranted: accessibilityGranted,
                    onGrant: { AccessibilityAuthorizer.requestOnce() }
                )

                PermissionRow(
                    title: "Input Monitoring",
                    subtitle: "Watches your typing for snippet triggers",
                    isGranted: inputMonitoringGranted,
                    onGrant: { AccessibilityAuthorizer.requestInputMonitoringOnce() }
                )

                PermissionRow(
                    title: "Notifications",
                    subtitle: "Reminders when a task is due",
                    isGranted: notificationsGranted,
                    onGrant: {
                        Task {
                            _ = await env.scheduler.requestAuthorization()
                            notificationsGranted = await env.scheduler.authorizationStatus() == .authorized
                        }
                    }
                )
            }
            .padding(.horizontal, Space.xl)
            .task {
                notificationsGranted = await env.scheduler.authorizationStatus() == .authorized
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.5))
                    accessibilityGranted = AccessibilityAuthorizer.isTrusted
                    inputMonitoringGranted = AccessibilityAuthorizer.inputMonitoringGranted
                    notificationsGranted = await env.scheduler.authorizationStatus() == .authorized
                }
            }

            Text("All optional — you can skip and enable later in Preferences.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.xxl)
    }
}

@MainActor
private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let isGranted: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ui(13, .medium))
                Text(subtitle)
                    .font(.ui(11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: Space.sm) {
                Text(isGranted ? "Granted" : "Not granted")
                    .font(.ui(11, .medium))
                    .foregroundStyle(isGranted ? Tokens.running : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(isGranted ? Tokens.running.opacity(0.12) : Tokens.hairline)
                    )

                if !isGranted {
                    Button("Grant", action: onGrant)
                        .buttonStyle(.bordered)
                        .tint(Tokens.accent)
                        .font(.ui(12))
                }
            }
        }
    }
}

@MainActor
private struct ShortcutRow: View {
    let keys: String
    let label: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.mono(12, .semibold))
                .foregroundStyle(Tokens.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5).fill(Tokens.hairline)
                )

            Text(label)
                .font(.ui(13))

            Spacer()
        }
    }
}
