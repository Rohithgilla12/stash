import SwiftUI

struct NotesWindow: View {
    @Bindable var model: NotesViewModel

    var body: some View {
        HSplitView {
            NotesSidebar(model: model)
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
            NotesEditor(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "#faf8f4"))
    }
}

private struct NotesSidebar: View {
    @Bindable var model: NotesViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Rectangle().fill(Tokens.hairline).frame(height: 1)
            ScrollView {
                LazyVStack(spacing: Space.xs) {
                    ForEach(model.notes) { note in
                        SidebarRow(note: note, isSelected: model.selectedId == note.id) {
                            model.selectedId = note.id
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await model.delete(note) }
                            }
                        }
                    }
                }
                .padding(Space.sm)
            }
        }
        .background(Color(hex: "#f3efe8"))
    }

    private var sidebarHeader: some View {
        HStack {
            Text("Notes")
                .font(.rounded(16, .semibold))
                .foregroundStyle(Tokens.textPrimary)
            Spacer()
            Button {
                Task {
                    if let n = await model.newNote() {
                        model.selectedId = n.id
                    }
                }
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Tokens.accent)
            }
            .buttonStyle(.plain)
            .help("New note")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.md)
    }
}

private struct SidebarRow: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void

    private var chipColor: Color {
        Color(hex: note.color ?? "#fdf0c2")
    }

    private var snippet: String {
        if note.kind == .todo, let first = note.items.first {
            return first.t.isEmpty ? "No tasks" : first.t
        }
        let trimmed = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No content" : trimmed
    }

    var body: some View {
        HoverRow { hovering in
            HStack(spacing: Space.sm) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(chipColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Tokens.hairline, lineWidth: 0.5)
                    )
                    .frame(width: 14, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.rounded(13, .medium))
                        .foregroundStyle(isSelected ? Tokens.accent : Tokens.textPrimary)
                        .lineLimit(1)
                    Text(snippet)
                        .font(.ui(11))
                        .foregroundStyle(Tokens.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(
                isSelected
                    ? Tokens.rowSelected
                    : (hovering ? Tokens.rowHover : Color.clear),
                in: RoundedRectangle(cornerRadius: Tokens.rowRadius)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}

private struct NotesEditor: View {
    @Bindable var model: NotesViewModel

    var body: some View {
        Group {
            if let note = model.selected {
                EditorPane(note: note, onUpdate: { updated in
                    Task { await model.update(updated) }
                })
                .id(note.id)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#faf8f4"))
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(Tokens.accent.opacity(0.4))
            Text("Select or create a note")
                .font(.rounded(15, .medium))
                .foregroundStyle(Tokens.textSecondary)
            Text("Your notes live here and sync to the menu bar.")
                .font(.ui(12))
                .foregroundStyle(Tokens.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private let noteColors: [(bg: String, accent: String, label: String)] = [
    ("#fdf0c2", "#c8642f", "Yellow"),
    ("#fcdcc6", "#b97a4a", "Peach"),
    ("#d4e4f2", "#5b86b8", "Blue"),
    ("#d9ecda", "#5e8a52", "Mint"),
]

private struct EditorPane: View {
    let note: Note
    let onUpdate: (Note) -> Void

    @State private var draft: Note

    init(note: Note, onUpdate: @escaping (Note) -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        self._draft = State(initialValue: note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorToolbar
            Rectangle().fill(Tokens.hairline).frame(height: 1)
            titleField
            Rectangle().fill(Tokens.hairline).frame(height: 1)
            bodyArea
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: Space.sm) {
            colorSwatches
            Spacer()
            kindToggle
            pinButton
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.sm)
    }

    private var colorSwatches: some View {
        HStack(spacing: Space.xs) {
            ForEach(noteColors, id: \.bg) { swatch in
                let isSelected = draft.color == swatch.bg
                Button {
                    draft.color = swatch.bg
                    draft.accent = swatch.accent
                    onUpdate(draft)
                } label: {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: swatch.bg))
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    isSelected
                                        ? Color(hex: swatch.accent)
                                        : Tokens.hairline,
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        )
                        .shadow(
                            color: isSelected ? .black.opacity(0.12) : .clear,
                            radius: 3,
                            y: 1
                        )
                }
                .buttonStyle(.plain)
                .help(swatch.label)
            }
        }
    }

    private var kindToggle: some View {
        let isText = draft.kind == .text

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Tokens.accent.opacity(0.08))

            GeometryReader { geo in
                let segW = geo.size.width / 2
                Capsule()
                    .fill(Tokens.accent)
                    .frame(width: segW)
                    .offset(x: isText ? 0 : segW)
                    .animation(.easeInOut(duration: 0.15), value: isText)
                    .padding(2)
            }

            HStack(spacing: 0) {
                Button {
                    draft.kind = .text
                    onUpdate(draft)
                } label: {
                    Text("Text")
                        .font(.ui(11, .semibold))
                        .foregroundStyle(isText ? .white : Tokens.textSecondary)
                        .frame(width: 52)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                Button {
                    draft.kind = .todo
                    onUpdate(draft)
                } label: {
                    Text("To-do")
                        .font(.ui(11, .semibold))
                        .foregroundStyle(!isText ? .white : Tokens.textSecondary)
                        .frame(width: 52)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
        }
        .frame(width: 108, height: 28)
    }

    private var pinButton: some View {
        Button {
            draft.onDesktop.toggle()
            onUpdate(draft)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: draft.onDesktop ? "pin.fill" : "pin")
                    .foregroundStyle(draft.onDesktop ? Tokens.accent : Tokens.textTertiary)
                Text("Pin")
                    .font(.ui(11))
                    .foregroundStyle(Tokens.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var titleField: some View {
        TextField("Title", text: Binding(
            get: { draft.title },
            set: { draft.title = $0 }
        ))
        .textFieldStyle(.plain)
        .font(.rounded(22, .semibold))
        .foregroundStyle(Tokens.textPrimary)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .onChange(of: draft.title) { _, _ in onUpdate(draft) }
    }

    @ViewBuilder
    private var bodyArea: some View {
        if draft.kind == .text {
            TextEditor(text: Binding(
                get: { draft.body },
                set: { draft.body = $0; onUpdate(draft) }
            ))
            .font(.ui(14))
            .foregroundStyle(Tokens.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .lineSpacing(4)
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            todoArea
        }
    }

    private var todoArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(draft.items.indices, id: \.self) { idx in
                    ChecklistRow(
                        item: draft.items[idx],
                        onChange: { updated in
                            draft.items[idx] = updated
                            onUpdate(draft)
                        },
                        onDelete: {
                            draft.items.remove(at: idx)
                            onUpdate(draft)
                        }
                    )
                }

                Button {
                    draft.items.append(ChecklistItem(t: "", done: false))
                } label: {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Tokens.accent)
                        Text("Add task")
                            .font(.ui(13))
                            .foregroundStyle(Tokens.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(Space.lg)
        }
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let onChange: (ChecklistItem) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Space.sm) {
            Button {
                onChange(ChecklistItem(t: item.t, done: !item.done))
            } label: {
                ZStack {
                    if item.done {
                        Circle()
                            .fill(Tokens.accent)
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                        Circle()
                            .strokeBorder(Tokens.hairline, lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                    }
                }
            }
            .buttonStyle(.plain)

            TextField("Task", text: Binding(
                get: { item.t },
                set: { onChange(ChecklistItem(t: $0, done: item.done)) }
            ))
            .textFieldStyle(.plain)
            .font(.ui(13))
            .foregroundStyle(item.done ? Tokens.textTertiary : Tokens.textPrimary)
            .strikethrough(item.done, color: Tokens.textTertiary)

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.ui(10))
                        .foregroundStyle(Tokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .onHover { isHovering = $0 }
    }
}
