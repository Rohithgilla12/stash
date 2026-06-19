import SwiftUI

struct ClipboardTab: View {
    @Bindable var model: ClipboardViewModel
    @State private var showCopied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            listContent

            if showCopied {
                copiedToast
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 6)),
                        removal: .opacity
                    ))
            }
        }
    }

    @ViewBuilder private var listContent: some View {
        if model.items.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 1) {
                if !model.pinned.isEmpty {
                    SectionHeader("Pinned", count: model.pinned.count)

                    ForEach(model.pinned) { item in
                        ClipRowView(
                            item: item,
                            onCopy: { copy(item) },
                            onTogglePin: { Task { await model.togglePin(item) } }
                        )
                    }
                }

                if !model.recent.isEmpty {
                    HStack(spacing: 0) {
                        SectionHeader("Recent", count: model.recent.count)
                        Button("Clear") { Task { await model.clearUnpinned() } }
                            .buttonStyle(.plain)
                            .font(.ui(10, .medium))
                            .foregroundStyle(Tokens.textTertiary)
                            .padding(.trailing, Space.xs)
                    }

                    ForEach(model.recent) { item in
                        ClipRowView(
                            item: item,
                            onCopy: { copy(item) },
                            onTogglePin: { Task { await model.togglePin(item) } },
                            onDelete: { Task { await model.delete(item) } }
                        )
                    }
                }
            }
            .padding(.bottom, Space.sm)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Tokens.accent.opacity(0.5))

            VStack(spacing: Space.xs) {
                Text("Nothing copied yet")
                    .font(.rounded(15, .medium))
                    .foregroundStyle(Tokens.textSecondary)

                Text("Copy text, links or images and they'll appear here.")
                    .font(.ui(12))
                    .foregroundStyle(Tokens.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl + Space.lg)
        .padding(.horizontal, Space.xl)
    }

    private var copiedToast: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text("Copied")
                .font(.ui(12, .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs + 2)
        .background(Tokens.accent, in: Capsule())
        .padding(.bottom, Space.sm)
        .shadow(color: Tokens.accent.opacity(0.25), radius: 8, y: 2)
    }

    private func copy(_ item: ClipItem) {
        Task { await model.copyBack(item) }
        withAnimation(.easeOut(duration: 0.20)) { showCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.20)) { showCopied = false }
        }
    }
}
