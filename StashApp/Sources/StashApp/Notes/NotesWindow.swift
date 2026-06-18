import SwiftUI

struct NotesWindow: View {
    @Bindable var model: NotesViewModel

    var body: some View {
        HSplitView {
            NotesSidebar(model: model)
                .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)
            NotesEditor(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.panelFill)
    }
}

private struct NotesSidebar: View {
    @Bindable var model: NotesViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.notes) { note in
                        SidebarRow(note: note, isSelected: model.selectedId == note.id) {
                            model.selectedId = note.id
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var sidebarHeader: some View {
        HStack {
            Text("Notes")
                .font(.system(.headline, design: .rounded).weight(.semibold))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct SidebarRow: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(note.color.map { Color(hex: $0) } ?? Color(hex: "#fdf0c2"))
                .frame(width: 8, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .lineLimit(1)
                    .font(.system(.callout).weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Tokens.accent : Tokens.textPrimary)
                Text(sidebarSnippet)
                    .font(.caption2)
                    .foregroundStyle(Tokens.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isSelected
                ? Tokens.accent.opacity(0.12)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: Tokens.rowRadius)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var sidebarSnippet: String {
        if note.kind == .todo, let first = note.items.first {
            return first.t
        }
        return note.body.isEmpty ? "No content" : note.body
    }
}

private struct NotesEditor: View {
    @Bindable var model: NotesViewModel
    @State private var draft: Note?

    var body: some View {
        Group {
            if let note = model.selected {
                EditorPane(note: note, onUpdate: { updated in
                    Task { await model.update(updated) }
                })
                .id(note.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 36))
                        .foregroundStyle(Tokens.textTertiary.opacity(0.5))
                    Text("Select or create a note")
                        .font(.callout)
                        .foregroundStyle(Tokens.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
            Divider()
            titleField
            Divider()
            bodyArea
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            colorSwatches
            Spacer()
            kindPicker
            Toggle("Pin to desktop", isOn: Binding(
                get: { draft.onDesktop },
                set: { draft.onDesktop = $0; onUpdate(draft) }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)
            .foregroundStyle(Tokens.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var colorSwatches: some View {
        HStack(spacing: 6) {
            ForEach(noteColors, id: \.bg) { swatch in
                Button {
                    draft.color = swatch.bg
                    draft.accent = swatch.accent
                    onUpdate(draft)
                } label: {
                    Circle()
                        .fill(Color(hex: swatch.bg))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(
                                draft.color == swatch.bg
                                    ? Color(hex: swatch.accent)
                                    : Color.black.opacity(0.12),
                                lineWidth: draft.color == swatch.bg ? 2 : 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .help(swatch.label)
            }
        }
    }

    private var kindPicker: some View {
        Picker("", selection: Binding(
            get: { draft.kind },
            set: { draft.kind = $0; onUpdate(draft) }
        )) {
            Text("Text").tag(NoteKind.text)
            Text("To-do").tag(NoteKind.todo)
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .labelsHidden()
    }

    private var titleField: some View {
        TextField("Title", text: Binding(
            get: { draft.title },
            set: { draft.title = $0 }
        ), onCommit: { onUpdate(draft) })
        .textFieldStyle(.plain)
        .font(.system(.title2, design: .rounded).weight(.semibold))
        .foregroundStyle(Tokens.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: draft.title) { _, _ in onUpdate(draft) }
    }

    @ViewBuilder
    private var bodyArea: some View {
        if draft.kind == .text {
            TextEditor(text: Binding(
                get: { draft.body },
                set: { draft.body = $0; onUpdate(draft) }
            ))
            .font(.system(.body))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
            todoArea
        }
    }

    private var todoArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
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
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle").foregroundStyle(Tokens.accent)
                        Text("Add task")
                            .font(.callout)
                            .foregroundStyle(Tokens.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(14)
        }
    }
}

private struct ChecklistRow: View {
    let item: ChecklistItem
    let onChange: (ChecklistItem) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onChange(ChecklistItem(t: item.t, done: !item.done))
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? Tokens.accent : Tokens.textTertiary)
            }
            .buttonStyle(.plain)

            TextField("Task", text: Binding(
                get: { item.t },
                set: { onChange(ChecklistItem(t: $0, done: item.done)) }
            ))
            .textFieldStyle(.plain)
            .font(.callout)
            .strikethrough(item.done, color: Tokens.textTertiary)
            .foregroundStyle(item.done ? Tokens.textTertiary : Tokens.textPrimary)

            Button(action: onDelete) {
                Image(systemName: "xmark").font(.caption).foregroundStyle(Tokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }
}
