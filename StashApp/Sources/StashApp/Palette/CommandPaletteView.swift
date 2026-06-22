import SwiftUI

@MainActor
struct CommandPaletteView: View {
    let items: [PaletteItem]
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var fieldFocused: Bool

    private var filtered: [PaletteItem] { CommandPalette.filter(items, query: query) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            paletteCard
        }
    }

    private var paletteCard: some View {
        VStack(spacing: 0) {
            searchRow
            Divider()
            resultList
            Divider()
            hintBar
        }
        .frame(width: 400)
        .frame(maxHeight: 380)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Tokens.panelFill)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .shadow(radius: 6, y: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onKeyPress(.upArrow) {
            if selection > 0 { selection -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selection < filtered.count - 1 { selection += 1 }
            return .handled
        }
        .onKeyPress(.return) {
            guard !filtered.isEmpty else { return .handled }
            filtered[selection].run()
            return .handled
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onAppear { fieldFocused = true }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var searchRow: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.accent)
            TextField("Search commands and content…", text: $query)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var resultList: some View {
        if filtered.isEmpty {
            Text("No matches")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            Button {
                                item.run()
                            } label: {
                                rowContent(for: item, index: index)
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selection) { _, newSelection in
                    guard newSelection < filtered.count else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(filtered[newSelection].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func rowContent(for item: PaletteItem, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .frame(width: 16)
                .foregroundStyle(Tokens.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(.primary)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Chip(text: item.kind, color: kindColor(item.kind))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            selection == index
                ? Tokens.rowSelected
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private var hintBar: some View {
        HStack {
            Text("↵ Run   ↑↓ Navigate   ⎋ Close")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kindColor(_ kind: String) -> Color {
        switch kind {
        case "action":  return Tokens.accent
        case "clip":    return Tokens.linkColor
        case "note":    return Tokens.priorityMed
        case "snippet": return Tokens.running
        default:        return Tokens.textTertiary
        }
    }
}
