import SwiftUI

struct ComingSoonView: View {
    let tab: HubTab
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 26))
                .foregroundStyle(Tokens.accent.opacity(0.7))
            Text("\(tab.label) coming soon")
                .font(.system(.callout, design: .rounded).weight(.medium))
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
