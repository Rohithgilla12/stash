import SwiftUI

struct WindowsTab: View {
    let snapper: WindowSnapper
    let presets: [WindowPreset]
    let onSave: (WindowPreset) -> Void
    let onDelete: (String) -> Void
    let layouts: [SavedLayout]
    let onSaveLayout: (String) -> Void
    let onDeleteLayout: (String) -> Void
    let onRenameLayout: (SavedLayout, String) -> Void
    let onRecallLayout: (_ layout: SavedLayout) async -> WindowSnapper.LayoutRecallSummary

    @State private var activeTarget: SnapTarget? = nil
    @State private var showToast: Bool = false
    @State private var toastLabel: String = ""
    @State private var targetAppName: String = "No active window"
    @State private var showAddPreset = false
    @State private var editingPreset: WindowPreset? = nil
    @State private var isTrusted: Bool = false
    @State private var showSaveLayout = false
    @State private var renamingLayout: SavedLayout? = nil

    private let groupOrder = ["Halves", "Quarters", "Thirds", "Full Screen"]
    private let previewScreenRect = CGRect(x: 0, y: 0, width: 360, height: 200)
    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !isTrusted {
                accessibilityBanner
            }
            previewArea
            snapGrid
            if NSScreen.screens.count > 1 {
                nextDisplayRow
            }
            presetsSection
            layoutsSection
        }
        .onAppear {
            targetAppName = snapper.targetAppName ?? "No active window"
            isTrusted = snapper.isTrusted
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                isTrusted = snapper.isTrusted
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastLabel)
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Tokens.accent, in: Capsule()).foregroundStyle(.white)
                    .padding(.bottom, 8).transition(.opacity)
            }
        }
        .sheet(isPresented: $showAddPreset) {
            WindowPresetEditor(editingPreset: nil, onSave: onSave)
        }
        .sheet(item: $editingPreset) { preset in
            WindowPresetEditor(editingPreset: preset, onSave: onSave)
        }
        .sheet(isPresented: $showSaveLayout) {
            SaveLayoutSheet(initialName: "") { name in
                onSaveLayout(name)
            }
        }
        .sheet(item: $renamingLayout) { layout in
            SaveLayoutSheet(initialName: layout.name) { newName in
                onRenameLayout(layout, newName)
            }
        }
    }

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Text("Window management needs Accessibility access")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Settings") {
                AccessibilityAuthorizer.requestOnce()
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Tokens.accent)
            .buttonStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Tokens.accent.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.accent.opacity(0.08))
                .stroke(Tokens.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var nextDisplayRow: some View {
        Button {
            snapper.moveToNextDisplay()
            let label = isTrusted ? "Moved to next display" : "Enable Accessibility to snap"
            toastLabel = label
            withAnimation { showToast = true }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                await MainActor.run { withAnimation { showToast = false } }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.textSecondary)
                Text("Move to Next Display")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
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

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader("Presets")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 8)],
                spacing: 8
            ) {
                ForEach(presets) { preset in
                    presetCard(preset)
                }
                addPresetTile
            }
        }
    }

    private func tapPreset(_ preset: WindowPreset) {
        snapper.snap(preset)
        toastLabel = snapper.isTrusted ? "Snapped to \(preset.name)" : "Enable Accessibility to snap"
        withAnimation { showToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run { withAnimation { showToast = false } }
        }
    }

    private func presetCard(_ preset: WindowPreset) -> some View {
        Button {
            tapPreset(preset)
        } label: {
            VStack(spacing: 4) {
                miniDiagramForPreset(preset)
                Text(preset.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { editingPreset = preset }
            Button("Delete", role: .destructive) { onDelete(preset.id) }
        }
    }

    private var addPresetTile: some View {
        Button {
            showAddPreset = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(width: 38, height: 25)
                Text("New Preset")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Tokens.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 6).padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniDiagramForPreset(_ preset: WindowPreset) -> some View {
        let diagramRect = CGRect(x: 0, y: 0, width: 38, height: 25)
        let highlight = WindowLayout.frame(for: preset, in: diagramRect)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.06))
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            RoundedRectangle(cornerRadius: 2)
                .fill(Tokens.accent)
                .frame(width: max(highlight.width, 1), height: max(highlight.height, 1))
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

    private var layoutsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader("Layouts")
            ForEach(layouts) { layout in
                layoutRow(layout)
            }
            saveLayoutButton
        }
    }

    private var saveLayoutButton: some View {
        Button {
            showSaveLayout = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isTrusted ? Tokens.textSecondary : Tokens.textTertiary)
                Text("Save current windows…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isTrusted ? Tokens.textPrimary : Tokens.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isTrusted)
        .opacity(isTrusted ? 1 : 0.5)
    }

    private func layoutRow(_ layout: SavedLayout) -> some View {
        Button {
            recallLayout(layout)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(layout.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(1)
                    Text("\(layout.entries.count) apps")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.trianglehead.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.textTertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Tokens.rowRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename") { renamingLayout = layout }
            Button("Delete", role: .destructive) { onDeleteLayout(layout.id) }
        }
    }

    private func recallLayout(_ layout: SavedLayout) {
        toastLabel = isTrusted ? "Recalling…" : "Enable Accessibility to recall"
        withAnimation { showToast = true }
        Task {
            if isTrusted {
                let summary = await onRecallLayout(layout)
                await MainActor.run {
                    toastLabel = "Placed \(summary.placed) · launched \(summary.launched) · skipped \(summary.skipped)"
                }
            }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { withAnimation { showToast = false } }
        }
    }
}
