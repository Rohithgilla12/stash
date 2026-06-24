import SwiftUI

struct WindowsTab: View {
    let snapper: WindowSnapper

    @State private var activeTarget: SnapTarget? = nil
    @State private var showToast: Bool = false
    @State private var toastLabel: String = ""
    @State private var targetAppName: String = "No active window"

    private let groupOrder = ["Halves", "Quarters", "Thirds", "Full Screen"]
    private let previewScreenRect = CGRect(x: 0, y: 0, width: 360, height: 200)
    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            previewArea
            snapGrid
        }
        .onAppear {
            // Capture once on appear — the targeted app is stable while the popover
            // is open (it was active before the user opened Stash).
            targetAppName = snapper.targetAppName ?? "No active window"
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastLabel)
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Tokens.accent, in: Capsule()).foregroundStyle(.white)
                    .padding(.bottom, 8).transition(.opacity)
            }
        }
    }

    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)

            safariRect
        }
        .frame(width: 360, height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var safariRect: some View {
        let target = activeTarget ?? .fullScreen
        let frame = WindowLayout.frame(for: target, in: previewScreenRect, gap: 6)

        return RoundedRectangle(cornerRadius: 4)
            .fill(Tokens.accent.opacity(0.25))
            .stroke(Tokens.accent, lineWidth: 1.5)
            .overlay(
                Text(targetAppName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Tokens.accent)
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .animation(.easeInOut(duration: 0.34), value: activeTarget)
    }

    private var snapGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupOrder, id: \.self) { group in
                let targets = SnapTarget.allCases.filter { $0.group == group }
                if !targets.isEmpty {
                    groupSection(group, targets: targets)
                }
            }
        }
    }

    private func groupSection(_ name: String, targets: [SnapTarget]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(targets) { target in
                    snapCard(target)
                }
            }
        }
    }

    private func snapCard(_ target: SnapTarget) -> some View {
        let isActive = activeTarget == target

        return Button {
            tap(target)
        } label: {
            VStack(spacing: 4) {
                miniDiagram(for: target)
                Text(target.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(target.hotkey)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(isActive ? Tokens.accent.opacity(0.1) : Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(isActive ? Tokens.accent : Color.primary.opacity(0.1), lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniDiagram(for target: SnapTarget) -> some View {
        let diagramRect = CGRect(x: 0, y: 0, width: 38, height: 25)
        let highlight = WindowLayout.frame(for: target, in: diagramRect, gap: 1)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.06))
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)

            RoundedRectangle(cornerRadius: 2)
                .fill(Tokens.accent)
                .frame(width: highlight.width, height: highlight.height)
                .offset(x: highlight.minX, y: highlight.minY)
        }
        .frame(width: 38, height: 25)
    }

    private func tap(_ target: SnapTarget) {
        snapper.snap(target)
        withAnimation { activeTarget = target }
        let label = snapper.isTrusted ? "Snapped: \(target.label)" : "Enable Accessibility to snap"
        toastLabel = label
        withAnimation { showToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                withAnimation { showToast = false }
            }
        }
    }
}
