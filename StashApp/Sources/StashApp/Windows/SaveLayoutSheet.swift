import SwiftUI

struct SaveLayoutSheet: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Tokens.textPrimary)

            TextField("My layout", text: $name)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
                .padding(8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                .focused($isFocused)
                .onSubmit {
                    guard !trimmedName.isEmpty else { return }
                    onSave(trimmedName)
                    dismiss()
                }

            HStack(spacing: Space.md) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Tokens.textSecondary)

                Spacer()

                Button("Save") {
                    onSave(trimmedName)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(trimmedName.isEmpty ? Tokens.textTertiary : Tokens.accent)
                .disabled(trimmedName.isEmpty)
            }
        }
        .padding(Space.md)
        .frame(minWidth: 300, minHeight: 120)
        .onAppear { isFocused = true }
    }
}
