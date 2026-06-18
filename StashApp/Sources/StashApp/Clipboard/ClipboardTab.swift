import SwiftUI

struct ClipboardTab: View {
    @Bindable var model: ClipboardViewModel
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.pinned.isEmpty {
                section("PINNED", model.pinned)
            }
            section("RECENT", model.recent)
            if model.items.isEmpty {
                Text("Nothing copied yet").font(.callout)
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("Copied to clipboard")
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Tokens.accent, in: Capsule()).foregroundStyle(.white)
                    .padding(.bottom, 8).transition(.opacity)
            }
        }
    }

    private func section(_ title: String, _ rows: [ClipItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(Tokens.textTertiary)
            ForEach(rows) { item in
                ClipRowView(item: item,
                            onCopy: { copy(item) },
                            onTogglePin: { Task { await model.togglePin(item) } })
            }
        }
    }

    private func copy(_ item: ClipItem) {
        Task { await model.copyBack(item) }
        withAnimation { showCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { showCopied = false }
        }
    }
}
