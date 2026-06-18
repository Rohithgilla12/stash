import SwiftUI

struct NotesTab: View {
    @Bindable var model: NotesViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            newNoteButton
            if model.notes.isEmpty {
                Text("No notes yet").font(.callout)
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(model.notes) { note in
                    NoteRowView(note: note) {
                        model.selectedId = note.id
                        openWindow.openActivating(id: "notes")
                    }
                }
            }
        }
    }

    private var newNoteButton: some View {
        Button {
            Task {
                if let n = await model.newNote() {
                    model.selectedId = n.id
                    openWindow.openActivating(id: "notes")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").foregroundStyle(Tokens.accent)
                Text("New note")
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Tokens.textPrimary)
                Spacer()
            }
            .padding(8)
            .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct NoteRowView: View {
    let note: Note
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            colorChip
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .lineLimit(1)
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Tokens.textPrimary)
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(Tokens.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Text(note.kind == .todo ? "TODO" : "NOTE")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(8)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var colorChip: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(note.color.map { Color(hex: $0) } ?? Color(hex: "#fdf0c2"))
            .frame(width: 14, height: 30)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
    }

    private var snippet: String {
        if note.kind == .todo, let first = note.items.first {
            return first.t
        }
        return note.body.isEmpty ? "No content" : note.body
    }
}
