import SwiftUI

struct SnippetFormView: View {
    let fields: [SnippetField]
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String] = [:]
    @FocusState private var focusedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            titleRow
            fieldsSection
            actionRow
        }
        .padding(Space.lg)
        .background(Tokens.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .frame(width: 480)
        .onAppear {
            focusedField = fields.first?.name
        }
    }

    private var titleRow: some View {
        Text("Fill in snippet")
            .font(.rounded(15, .semibold))
            .foregroundStyle(Tokens.textPrimary)
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ForEach(fields, id: \.name) { field in
                SnippetFieldRow(
                    field: field,
                    value: binding(for: field.name),
                    focusedField: $focusedField
                )
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button("Cancel") { onCancel() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)
            Button("Insert") { commit() }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.accent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.top, Space.xs)
    }

    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { values[name] ?? "" },
            set: { values[name] = $0 }
        )
    }

    private func commit() {
        onSubmit(values)
    }
}

private struct SnippetFieldRow: View {
    let field: SnippetField
    @Binding var value: String
    var focusedField: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(field.label)
                .font(.rounded(11, .medium))
                .foregroundStyle(Tokens.textSecondary)
            TextField("", text: $value)
                .textFieldStyle(.plain)
                .font(Font.rounded(13))
                .foregroundStyle(Tokens.textPrimary)
                .padding(Space.sm)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                .focused(focusedField, equals: field.name)
        }
    }
}
