import SwiftUI

struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(alignment: .center, spacing: Space.xs) {
            Text(title)
                .font(.rounded(10, .semibold))
                .kerning(0.6)
                .foregroundStyle(Tokens.textTertiary)
                .textCase(.uppercase)

            if let count {
                Text("\(count)")
                    .font(.ui(9, .semibold))
                    .foregroundStyle(Tokens.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Tokens.hairline, in: Capsule())
            }

            Spacer()
        }
        .padding(.top, Space.md)
        .padding(.bottom, Space.xs)
        .padding(.horizontal, Space.xs)
    }
}

struct HoverRow<Content: View>: View {
    @State private var hovering = false
    let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(hovering)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(hovering ? Tokens.rowHover : Color.clear)
            )
            .onHover { isHovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    hovering = isHovering
                }
            }
    }
}

struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.ui(9.5, .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(color.opacity(0.14), in: Capsule())
    }
}
