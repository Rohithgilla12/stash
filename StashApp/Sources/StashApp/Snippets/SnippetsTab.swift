import SwiftUI

struct SnippetsTab: View {
    @Bindable var model: SnippetsViewModel
    @State private var showToast = false
    @State private var toastMessage = ""

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
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                .onChange(of: model.demoText) { _, _ in model.onDemoChange() }
        }
    }

    private var snippetList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SNIPPETS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            if model.snippets.isEmpty {
                Text("No snippets yet")
                    .font(.callout)
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(model.snippets) { snippet in
                            SnippetRowView(snippet: snippet) {
                                model.insert(snippet)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SnippetRowView: View {
    let snippet: Snippet
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(snippet.trigger)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Tokens.accent)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Tokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.label)
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(1)
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(Tokens.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var previewText: String {
        if let gen = snippet.dynamic {
            return "dynamic · \(gen)"
        }
        return snippet.expand ?? ""
    }
}
