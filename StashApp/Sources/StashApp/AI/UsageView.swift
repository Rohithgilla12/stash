import SwiftUI

struct UsageView: View {
    let model: AIViewModel

    var body: some View {
        VStack(spacing: 12) {
            liveLimitsCard
            costCard
            tokensCard
            histogramCard
            byModelCard
            footnote
            refreshButton
        }
    }

    private var liveLimitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("LIVE LIMITS")
            liveLimitsContent
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    @ViewBuilder private var liveLimitsContent: some View {
        switch model.limitsState {
        case .loading:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .unavailable(let reason):
            Text("Live limits unavailable · \(reason) · experimental")
                .font(.system(size: 11))
                .foregroundStyle(Tokens.textTertiary)
        case .idle, .loaded:
            if let limits = model.limits {
                limitsRows(limits)
            } else {
                Text("Live limits unavailable · experimental")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.textTertiary)
            }
        }
    }

    private func limitsRows(_ limits: ClaudeLimits) -> some View {
        VStack(spacing: 6) {
            if let w = limits.session { limitRow(w) }
            if let w = limits.weekly  { limitRow(w) }
            if let w = limits.sonnet  { limitRow(w) }
            if let w = limits.opus    { limitRow(w) }
        }
    }

    private func limitRow(_ window: UsageWindow) -> some View {
        HStack(spacing: 8) {
            Text(window.label)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.textPrimary)
                .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Tokens.accent)
                        .frame(width: geo.size.width * max(0, min(1, window.percentLeft / 100)), height: 5)
                }
            }
            .frame(height: 5)

            Text(String(format: "%.0f%% left", window.percentLeft))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Tokens.textSecondary)
                .frame(width: 56, alignment: .trailing)

            Text(resetLabel(window))
                .font(.system(size: 11))
                .foregroundStyle(Tokens.textTertiary)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)
        }
    }

    private func resetLabel(_ window: UsageWindow) -> String {
        guard let resetsAt = window.resetsAt else { return "–" }
        let seconds = resetsAt.timeIntervalSince(model.now)
        guard seconds > 0 else { return "–" }
        return "resets in \(humanizedInterval(seconds))"
    }

    private func humanizedInterval(_ seconds: Double) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h \(Int(seconds / 60) % 60)m" }
        return "\(Int(seconds / 86400))d \(Int(seconds / 3600) % 24)h"
    }

    private var costCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("COST")
            VStack(spacing: 4) {
                simpleRow(label: "Today", value: String(format: "$%.2f", model.todayCost))
                simpleRow(label: "30 days", value: String(format: "$%.2f", model.cost30d))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private var tokensCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("TOKENS")
            VStack(spacing: 4) {
                simpleRow(label: "30 days", value: formatTokens(model.tokens30d))
                simpleRow(label: "Latest session", value: formatTokens(model.latestTokens))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private func simpleRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Tokens.textSecondary)
        }
    }

    private var histogramCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("30-DAY HISTOGRAM")
            histogramBars
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private var histogramBars: some View {
        let maxTokens = model.daily.map(\.tokens).max() ?? 1
        let totalHeight: CGFloat = 44

        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(model.daily.indices, id: \.self) { idx in
                let bucket = model.daily[idx]
                let barHeight: CGFloat = {
                    guard maxTokens > 0, bucket.tokens > 0 else { return 0 }
                    return max(2, CGFloat(bucket.tokens) / CGFloat(maxTokens) * totalHeight)
                }()
                RoundedRectangle(cornerRadius: 2)
                    .fill(bucket.tokens > 0 ? Tokens.accent : Color.primary.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight > 0 ? barHeight : 2)
                    .opacity(bucket.tokens > 0 ? 1 : 0)
            }
        }
        .frame(height: totalHeight)
    }

    private var byModelCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("BY MODEL")
            if model.byModel.isEmpty {
                Text("No data")
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.textTertiary)
            } else {
                byModelContent
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Tokens.rowRadius)
                .fill(Tokens.panelFill)
                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        )
    }

    private var byModelContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let top = model.byModel.first {
                Text(top.model)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }
            ForEach(model.byModel.prefix(8).indices, id: \.self) { idx in
                let bucket = model.byModel[idx]
                HStack {
                    Text(bucket.model)
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(String(format: "$%.4f", bucket.cost))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Tokens.textSecondary)
                }
            }
        }
    }

    private var footnote: some View {
        Text("Estimated from local Claude logs at API rates.")
            .font(.system(size: 10))
            .foregroundStyle(Tokens.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var refreshButton: some View {
        HStack {
            Spacer()
            Button("Refresh") {
                Task {
                    await model.loadUsage()
                    await model.refreshLimits()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Tokens.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Tokens.accent.opacity(0.10))
            )
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000_000 { return String(format: "%.1fB", Double(n) / 1_000_000_000) }
        if n >= 1_000_000     { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000         { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
