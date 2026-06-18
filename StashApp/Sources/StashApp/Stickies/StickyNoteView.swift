import SwiftUI

struct StickyNoteView: View {
    let note: Note
    let onToggleItem: (Int) -> Void
    let onOpen: () -> Void

    private var backgroundColor: Color {
        Color(hex: note.color ?? "#fdf0c2")
    }

    private var accentColor: Color {
        Color(hex: note.accent ?? "#c8642f")
    }

    private var rotation: Double {
        let hash = note.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let normalized = Double(hash % 100) / 100.0
        return (normalized - 0.5) * 6.0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                        .padding(.top, 2)

                    if !note.title.isEmpty {
                        Text(note.title)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Tokens.textPrimary)
                            .lineLimit(2)
                    }
                }

                Group {
                    if note.kind == .todo {
                        checklistView
                    } else {
                        Text(note.body)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(Tokens.textSecondary)
                            .lineLimit(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)

            Button(action: onOpen) {
                Color.clear
            }
            .buttonStyle(.plain)
            .allowsHitTesting(note.kind != .todo)
        }
        .frame(width: 220, height: 220)
        .rotationEffect(.degrees(rotation))
    }

    @ViewBuilder
    private var checklistView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(note.items.indices, id: \.self) { idx in
                    let item = note.items[idx]
                    Button {
                        onToggleItem(idx)
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(item.done ? accentColor : Tokens.textTertiary)
                            Text(item.t)
                                .font(.system(.caption, design: .default))
                                .foregroundStyle(item.done ? Tokens.textTertiary : Tokens.textPrimary)
                                .strikethrough(item.done)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onTapGesture { onOpen() }
    }
}
