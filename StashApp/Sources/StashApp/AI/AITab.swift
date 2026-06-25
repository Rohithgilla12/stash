import SwiftUI

private enum AIMode { case chat, usage }

struct AITab: View {
    let model: AIViewModel
    let assistant: AIAssistant
    let env: AppEnvironment

    @State private var mode: AIMode = .chat
    @State private var prompt: String = ""
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    @State private var thinkScale: CGFloat = 1.0
    @State private var thinkOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                Text("Chat").tag(AIMode.chat)
                Text("Usage").tag(AIMode.usage)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if mode == .chat {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        assistantCard
                        mcpServerCard
                        usageCycleCard
                        activeSessionsCard
                    }
                }
                .task { await model.start() }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        UsageView(model: model)
                    }
                    .padding(12)
                }
                .task {
                    await model.loadUsage()
                    await model.refreshLimits()
                }
            }
        }
    }

    @ViewBuilder private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASSISTANT")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask Claude anything…", text: $prompt, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Tokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Tokens.hairline, lineWidth: 1)
                            )
                    )

                if assistant.isRunning {
                    Button { assistant.cancel() } label: {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Tokens.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Tokens.surface)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        Task { await assistant.run(prompt) }
                    } label: {
                        Text("Send")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(prompt.isEmpty ? Tokens.accent.opacity(0.4) : Tokens.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(prompt.isEmpty)
                }
            }

            FlowLayout(spacing: 6) {
                chipButton("Summarize clipboard") {
                    let texts = env.viewModel.items.prefix(15).compactMap { item -> String? in
                        let t = item.text ?? item.title ?? ""
                        return t.isEmpty ? nil : String(t.prefix(300))
                    }
                    guard !texts.isEmpty else { return }
                    let joined = texts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                    Task { await assistant.run("Summarize these recent clipboard items concisely:\n\n\(joined)") }
                }
                chipButton("Plan my day") {
                    let open = env.tasksViewModel.tasks.filter { !$0.done }
                    let titles = open.map { "- \($0.title)" }.joined(separator: "\n")
                    let planPrompt = titles.isEmpty
                        ? "I have no tasks yet. Propose a good, focused plan for today as a developer working on a macOS app."
                        : "Here are my current tasks:\n\(titles)\n\nPropose a focused, realistic plan for today. Group and prioritize."
                    Task { await assistant.run(planPrompt) }
                }
                chipButton("Rewrite latest clip") {
                    guard let top = env.viewModel.items.first,
                          let text = top.text ?? top.title, !text.isEmpty else { return }
                    Task { await assistant.run("Rewrite this more clearly and professionally:\n\n\(String(text.prefix(2000)))") }
                }
            }

            if assistant.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Tokens.accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(thinkScale)
                        .opacity(thinkOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                thinkScale = 1.5
                                thinkOpacity = 0.4
                            }
                        }
                        .onDisappear {
                            thinkScale = 1.0
                            thinkOpacity = 1.0
                        }
                    Text("Thinking…")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.textSecondary)
                }
            }

            if let err = assistant.errorText {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.08))
                )
            }

            if !assistant.response.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView {
                        Text(assistant.response)
                            .font(.system(size: 13))
                            .foregroundStyle(Tokens.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Tokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Tokens.hairline, lineWidth: 1)
                            )
                    )

                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(assistant.response, forType: .string)
                    } label: {
                        Label("Copy response", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.accent)
                    }
                    .buttonStyle(.plain)
                }
            } else if !assistant.isRunning && assistant.errorText == nil {
                Text("Ask anything, or use a quick action above.")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.textTertiary)
                    .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private func chipButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Tokens.accent.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .disabled(assistant.isRunning)
    }

    private var mcpServerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP SERVER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#3fa45b"))
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        ) {
                            pulseScale = 1.35
                            pulseOpacity = 0.55
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("stash-mcp")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Tokens.textPrimary)
                    Text("Connected · localhost (stdio)")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.textSecondary)
                }

                Spacer()
            }

            FlowLayout(spacing: 5) {
                ForEach(mcpTools, id: \.self) { tool in
                    Text(tool)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Tokens.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Tokens.accent.opacity(0.08))
                        )
                }
            }

            Button { } label: {
                Text("Generate my day")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Tokens.accent.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .help("Ask Claude via MCP to plan your day")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private var usageCycleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("USAGE THIS CYCLE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

            VStack(spacing: 6) {
                claudeUsageRow
                dimRow(name: "Codex")
                dimRow(name: "Stash AI")
            }

            Text("From local Claude Code sessions")
                .font(.system(size: 10))
                .foregroundStyle(Tokens.textTertiary.opacity(0.7))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private var claudeUsageRow: some View {
        let total = model.todayInput + model.todayOutput
        let fraction = min(1.0, Double(total) / 5_000_000) // soft visual scale (~a heavy day of tokens), not an API quota

        return HStack(spacing: 8) {
            Text("Claude")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Tokens.accent)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(height: 5)

            Text("\(formatTokenCount(model.todayInput))↑  \(formatTokenCount(model.todayOutput))↓")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
        }
    }

    private func dimRow(name: String) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.textTertiary.opacity(0.6))
                .frame(width: 70, alignment: .leading)

            GeometryReader { _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 5)
            }
            .frame(height: 5)

            Text("Not connected")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.textTertiary.opacity(0.6))
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
        }
        .opacity(0.55)
    }

    private var activeSessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVE SESSIONS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

            if model.sessions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(Tokens.textTertiary.opacity(0.5))
                    Text("No active sessions")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.sessions.prefix(6), id: \.sessionId) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private func sessionRow(_ session: UsageAggregator.SessionSummary) -> some View {
        let status = UsageAggregator.status(lastSeen: session.lastSeen, now: model.now)
        let dotColor = statusColor(status)
        let elapsed = elapsedString(from: session.firstSeen, to: model.now)

        return HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(session.repo)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.textPrimary)
                    if let branch = session.branch {
                        Text("·")
                            .foregroundStyle(Tokens.textTertiary)
                        Text(branch)
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.textSecondary)
                    }
                }
                Text("\(formatTokenCount(session.totalTokens)) tokens · \(elapsed)")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.textTertiary)
            }

            Spacer()
        }
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .running: return Color(hex: "#3fa45b")
        case .waiting: return Color(hex: "#d8a13a")
        case .idle:    return Color(hex: "#a39a8c")
        }
    }

    private func elapsedString(from start: Date, to end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        if seconds <= 0 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private func formatTokenCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            let m = Double(n) / 1_000_000
            return String(format: "%.1fM", m)
        } else if n >= 1_000 {
            let k = Double(n) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(n)"
    }

    private let mcpTools = [
        "create_task", "list_tasks", "complete_task",
        "update_task", "add_note", "search_clipboard"
    ]
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        _ = maxWidth
    }
}
