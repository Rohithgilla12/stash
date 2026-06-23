import SwiftUI

struct QuickCaptureView: View {
    let onSave: (String, Bool) -> Void
    let onClose: () -> Void

    @State private var text = ""
    @State private var asTask = true
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            inputRow
            Divider().opacity(0.3)
            bottomRow
        }
        .padding(16)
        .background(Tokens.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .frame(width: 500)
        .onKeyPress(.escape) { onClose(); return .handled }
        .onAppear { focused = true }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(Tokens.accent)
                .font(.system(size: 16, weight: .medium))
            TextField("Capture a thought…", text: $text)
                .textFieldStyle(.plain)
                .font(Font.rounded(16))
                .focused($focused)
                .onSubmit { commit() }
        }
        .padding(.bottom, 12)
    }

    private var bottomRow: some View {
        HStack {
            TypeToggle(asTask: $asTask)
            Spacer()
            Text("↵ Save   ⎋ Cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, asTask)
    }
}

private struct TypeToggle: View {
    @Binding var asTask: Bool

    var body: some View {
        HStack(spacing: 4) {
            pill(label: "Task", selected: asTask) { asTask = true }
            pill(label: "Note", selected: !asTask) { asTask = false }
        }
    }

    private func pill(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Font.rounded(12, .medium))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? Tokens.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
