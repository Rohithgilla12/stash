import SwiftUI

struct PasteBrowserView: View {
    let items: [ClipItem]
    let onPaste: (ClipItem) -> Void
    let onClose: () -> Void

    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var containerFocused: Bool

    private var filtered: [ClipItem] {
        guard !query.isEmpty else { return items }
        let q = query.lowercased()
        return items.filter {
            ($0.title?.lowercased().contains(q) ?? false)
                || ($0.text?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 0) {
                searchRow
                Divider()
                    .background(Tokens.hairline)
                    .padding(.horizontal, Space.lg)
                cardScroll
                hintBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($containerFocused)
        .onKeyPress(.leftArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(characters: .alphanumerics.union(.punctuationCharacters).union(.symbols)) { press in
            query.append(press.characters)
            selection = 0
            return .handled
        }
        .onKeyPress(.delete) {
            if !query.isEmpty {
                query.removeLast()
                selection = 0
            }
            return .handled
        }
        .onAppear {
            containerFocused = true
        }
        .onChange(of: filtered.count) { _, _ in
            selection = 0
        }
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Tokens.panelFill)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var searchRow: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.textTertiary)
                .font(.ui(13))

            Text(query.isEmpty ? "Search clipboard…" : query)
                .font(.ui(13))
                .foregroundStyle(query.isEmpty ? Tokens.textTertiary : Tokens.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !query.isEmpty {
                Button {
                    query = ""
                    selection = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.textTertiary)
                        .font(.ui(13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    @ViewBuilder
    private var cardScroll: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.md) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            PasteCardView(
                                item: item,
                                isSelected: selection == index,
                                onPaste: { onPaste(item) }
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.vertical, Space.md)
                }
                .onChange(of: selection) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "clipboard")
                .font(.ui(28))
                .foregroundStyle(Tokens.textTertiary)
            Text("No clipboard history yet")
                .font(.ui(13))
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hintBar: some View {
        HStack(spacing: Space.xl) {
            hintItem(key: "↵", label: "Paste")
            hintItem(key: "⎋", label: "Close")
            hintItem(key: "← →", label: "Navigate")
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity)
        .background(Tokens.hairline.opacity(0.5))
        .clipShape(
            .rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 0
            )
        )
    }

    private func hintItem(key: String, label: String) -> some View {
        HStack(spacing: Space.xs) {
            Text(key)
                .font(.ui(11, .semibold))
                .foregroundStyle(Tokens.textSecondary)
            Text(label)
                .font(.ui(11))
                .foregroundStyle(Tokens.textTertiary)
        }
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        selection = max(0, min(filtered.count - 1, selection + delta))
    }

    private func pasteSelected() {
        guard !filtered.isEmpty, selection < filtered.count else { return }
        onPaste(filtered[selection])
    }
}
