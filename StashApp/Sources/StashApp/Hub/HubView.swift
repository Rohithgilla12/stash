import SwiftUI

struct HubView<Content: View>: View {
    @Binding var selection: HubTab
    @Binding var query: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            searchField
            tabBar
            ScrollView { content() }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .padding(12)
        .frame(width: Tokens.panelWidth, height: Tokens.panelHeight)
        .background(Tokens.panelFill)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Tokens.textTertiary)
            TextField("Search", text: $query).textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(HubTab.allCases) { tab in
                Button { selection = tab } label: {
                    Text(tab.label)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .foregroundStyle(selection == tab ? Color.white : Tokens.textSecondary)
                        .background(selection == tab ? Tokens.accent : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Preferences…") {}.buttonStyle(.plain)
                .font(.caption).foregroundStyle(Tokens.textTertiary)
        }
    }
}
