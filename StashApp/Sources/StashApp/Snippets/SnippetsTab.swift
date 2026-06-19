import SwiftUI

struct SnippetsTab: View {
    @Bindable var model: SnippetsViewModel
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAddSheet = false
    @State private var editingSnippet: Snippet?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            expanderToggle
            demoField
            snippetList
        }
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Tokens.accent, in: Capsule()).foregroundStyle(.white)
                    .padding(.bottom, 8).transition(.opacity)
            }
        }
        .onChange(of: model.lastExpanded) { _, newValue in
            guard let trigger = newValue else { return }
            toastMessage = "Expanded \(trigger)"
            withAnimation { showToast = true }
            model.lastExpanded = nil
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation { showToast = false }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            SnippetEditorSheet(editingSnippet: nil) { snippet in
                model.insert(snippet)
            }
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorSheet(editingSnippet: snippet) { updated in
                model.update(updated)
            }
        }
    }

    private var expanderToggle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Expand snippets system-wide", isOn: $model.expanderEnabled)
                .toggleStyle(.switch)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
            Text("Requires Accessibility permission")
                .font(.caption)
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(.bottom, 2)
    }

    private var demoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LIVE DEMO")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            TextField("Type a trigger like :shrug or :date…", text: $model.demoText)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
                .padding(8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                .onChange(of: model.demoText) { _, _ in model.onDemoChange() }
        }
    }

    private var snippetList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeader("Snippets")
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Tokens.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Space.xs)
            }
            if model.snippets.isEmpty {
                HStack(spacing: Space.xs) {
                    Text("No snippets yet. Tap")
                        .font(.callout)
                        .foregroundStyle(Tokens.textTertiary)
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Tokens.accent)
                    }
                    .buttonStyle(.plain)
                    Text("to add one.")
                        .font(.callout)
                        .foregroundStyle(Tokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.snippets) { snippet in
                            SnippetRowView(
                                snippet: snippet,
                                onTapInsert: { model.insert(snippet) },
                                onEdit: { editingSnippet = snippet },
                                onDelete: { model.delete(snippet) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SnippetRowView: View {
    let snippet: Snippet
    let onTapInsert: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HoverRow { hovering in
            HStack(spacing: 10) {
                Text(snippet.trigger)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Tokens.accent)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.xs) {
                        Text(snippet.label)
                            .font(.system(.callout).weight(.medium))
                            .foregroundStyle(Tokens.textPrimary)
                            .lineLimit(1)
                        if snippet.dynamic != nil {
                            Chip(text: "auto", color: Tokens.textTertiary)
                        }
                    }
                    Text(previewText)
                        .font(.caption)
                        .foregroundStyle(Tokens.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: Space.xs) {
                    if snippet.dynamic == nil {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(Tokens.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .opacity(hovering ? 1 : 0)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTapInsert)
        }
    }

    private var previewText: String {
        if let gen = snippet.dynamic {
            return "dynamic · \(gen)"
        }
        return snippet.expand ?? ""
    }
}

private struct SnippetEditorSheet: View {
    let editingSnippet: Snippet?
    let onSave: (Snippet) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trigger: String
    @State private var label: String
    @State private var expansion: String

    init(editingSnippet: Snippet?, onSave: @escaping (Snippet) -> Void) {
        self.editingSnippet = editingSnippet
        self.onSave = onSave
        _trigger = State(initialValue: editingSnippet?.trigger ?? "")
        _label = State(initialValue: editingSnippet?.label ?? "")
        _expansion = State(initialValue: editingSnippet?.expand ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(editingSnippet == nil ? "New Snippet" : "Edit Snippet")
                .font(.headline)
                .foregroundStyle(Tokens.textPrimary)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("TRIGGER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.textTertiary)
                TextField(":sig", text: $trigger)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("LABEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tokens.textTertiary)
                TextField("Label", text: $label)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
            }

            if editingSnippet?.dynamic != nil {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("EXPANSION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Tokens.textTertiary)
                    Text("Dynamic — generated at expand time")
                        .font(.callout)
                        .foregroundStyle(Tokens.textTertiary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                }
            } else {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("REPLACEMENT TEXT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Tokens.textTertiary)
                    TextEditor(text: $expansion)
                        .font(.callout)
                        .foregroundStyle(Tokens.textPrimary)
                        .frame(minHeight: 72)
                        .padding(4)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                        .overlay(alignment: .topLeading) {
                            if expansion.isEmpty {
                                Text("Replacement text...")
                                    .font(.callout)
                                    .foregroundStyle(Tokens.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }

            HStack(spacing: Space.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.textSecondary)

                Spacer()

                Button("Save") {
                    let trimmed = trigger.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let createdAt = editingSnippet?.createdAt ?? Int64(Date().timeIntervalSince1970 * 1000)
                    let snippet = Snippet(
                        trigger: trimmed,
                        label: label.isEmpty ? trimmed : label,
                        expand: editingSnippet?.dynamic != nil ? nil : (expansion.isEmpty ? nil : expansion),
                        dynamic: editingSnippet?.dynamic,
                        createdAt: createdAt
                    )
                    onSave(snippet)
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(trigger.trimmingCharacters(in: .whitespaces).isEmpty ? Tokens.textTertiary : Tokens.accent)
                .disabled(trigger.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Space.lg)
        .frame(width: 320)
    }
}
