import SwiftUI

struct PasteBrowserView: View {
    private let initialItems: [ClipItem]
    let onPaste: (ClipItem) -> Void
    let onPin: (ClipItem) -> Void
    let onDelete: (ClipItem) -> Void
    let onClose: () -> Void

    @State private var localItems: [ClipItem]
    @State private var query: String = ""
    @State private var selection: Int = 0
    @FocusState private var containerFocused: Bool

    init(items: [ClipItem], onPaste: @escaping (ClipItem) -> Void,
         onPin: @escaping (ClipItem) -> Void,
         onDelete: @escaping (ClipItem) -> Void,
         onClose: @escaping () -> Void) {
        self.initialItems = items
        self.onPaste = onPaste
        self.onPin = onPin
        self.onDelete = onDelete
        self.onClose = onClose
        self._localItems = State(initialValue: items)
    }

    private var filtered: [ClipItem] {
        guard !query.isEmpty else { return localItems }
        let q = query.lowercased()
        return localItems.filter {
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
        .onKeyPress { press in handleKey(press) }
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
                                badgeIndex: index < 9 ? index + 1 : nil,
                                onPaste: { onPaste(item) },
                                onPin: {
                                    onPin(item)
                                    if let li = localItems.firstIndex(where: { $0.id == item.id }) {
                                        localItems[li].pinned.toggle()
                                    }
                                },
                                onDelete: {
                                    onDelete(item)
                                    localItems.removeAll { $0.id == item.id }
                                    selection = min(selection, max(0, filtered.count - 1))
                                }
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
            hintItem(key: "⌘1–9", label: "Quick paste")
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

    /// One handler for all keys so ordering is explicit.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:  moveSelection(by: -1); return .handled
        case .rightArrow: moveSelection(by: 1);  return .handled
        case .return:     pasteSelected();        return .handled
        case .escape:     onClose();              return .handled
        default: break
        }

        // ⌘1–⌘9 quick-paste
        if press.modifiers.contains(.command),
           let digit = press.characters.first?.wholeNumberValue,
           digit >= 1 && digit <= 9 {
            let idx = digit - 1
            if idx < filtered.count { onPaste(filtered[idx]) }
            return .handled
        }

        // P key (no modifiers) — pin/unpin selected card
        if press.modifiers.isEmpty, press.characters.lowercased() == "p" {
            let idx = selection
            guard idx < filtered.count else { return .ignored }
            let item = filtered[idx]
            onPin(item)
            if let li = localItems.firstIndex(where: { $0.id == item.id }) {
                localItems[li].pinned.toggle()
            }
            return .handled
        }

        // Backspace / forward-delete
        if press.key == .delete || press.characters == "\u{7F}" || press.characters == "\u{8}" {
            if !query.isEmpty {
                query.removeLast()
                selection = 0
            } else {
                let f = filtered
                guard !f.isEmpty, selection < f.count else { return .handled }
                let item = f[selection]
                onDelete(item)
                localItems.removeAll { $0.id == item.id }
                selection = min(selection, max(0, filtered.count - 1))
            }
            return .handled
        }

        // Printable characters → append (ignore ⌘/⌃/⌥ combos and control chars).
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
}
