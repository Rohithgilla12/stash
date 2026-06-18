import SwiftUI

struct AITab: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                mcpServerCard
                usageCycleCard
                activeSessionsCard
            }
        }
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

            Text("Connect provider keys in Preferences to see usage.")
                .font(.system(size: 12))
                .foregroundStyle(Tokens.textTertiary)

            VStack(spacing: 6) {
                ForEach(placeholderProviders, id: \.name) { provider in
                    HStack(spacing: 8) {
                        Text(provider.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Tokens.textTertiary.opacity(0.6))
                            .frame(width: 70, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: "#e0dbd6"))
                                .frame(height: 5)
                        }
                        .frame(height: 5)

                        Text("—")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Tokens.textTertiary.opacity(0.6))
                            .frame(width: 28, alignment: .trailing)
                    }
                    .opacity(0.55)
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

    private var activeSessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVE SESSIONS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)

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
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private let mcpTools = [
        "create_task", "list_tasks", "complete_task",
        "update_task", "add_note", "search_clipboard"
    ]

    private struct ProviderPlaceholder {
        let name: String
    }

    private let placeholderProviders = [
        ProviderPlaceholder(name: "Claude"),
        ProviderPlaceholder(name: "Codex"),
        ProviderPlaceholder(name: "Stash AI")
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
