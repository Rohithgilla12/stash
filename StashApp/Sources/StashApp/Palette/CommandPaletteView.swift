import SwiftUI

@MainActor
struct CommandPaletteView: View {
    let items: [PaletteItem]
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var containerFocused: Bool

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
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Tokens.panelFill)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6, y: 3)
        .focusable()
        .focused($containerFocused)
        .onKeyPress { press in handleKey(press) }
        .onAppear { containerFocused = true }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    /// One handler for all keys so ordering is explicit (backspace was missed
    /// when split across separate `.onKeyPress` modifiers).
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:   if selection > 0 { selection -= 1 }; return .handled
        case .downArrow: if selection < filtered.count - 1 { selection += 1 }; return .handled
        case .return:    if selection < filtered.count { filtered[selection].run() }; return .handled
        case .escape:    onClose(); return .handled
        default: break
        }
        if press.key == .delete || press.characters == "\u{7F}" || press.characters == "\u{8}" {
            if !query.isEmpty { query.removeLast(); selection = 0 }
            return .handled
        }
        guard press.modifiers.subtracting(.shift).isEmpty else { return .ignored }
        let typed = press.characters.filter { ch in
            ch.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7F }
        }
        if !typed.isEmpty {
            query.append(typed)
            selection = 0
            return .handled
        }
        return .ignored
    }

    private var searchRow: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.accent)
            Text(query.isEmpty ? "Search commands and content…" : query)
                .foregroundStyle(query.isEmpty ? .tertiary : .primary)
            Spacer()
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
