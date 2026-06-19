import SwiftUI

struct PasteCardView: View {
    let item: ClipItem
    let isSelected: Bool
    let onPaste: () -> Void

    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 220
    private let cornerRadius: CGFloat = 12

    private var presentation: ClipPresentation.Style {
        ClipPresentation.style(for: item)
    }

    var body: some View {
        Button(action: onPaste) {
            ZStack(alignment: .topLeading) {
                cardBackground

                VStack(alignment: .leading, spacing: 0) {
                    chipRow
                    Spacer(minLength: Space.xs)
                    previewContent
                    Spacer(minLength: Space.xs)
                    footerMeta
                }
                .padding(Space.md)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .buttonStyle(CardButtonStyle(isSelected: isSelected, cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Tokens.surface.opacity(1.15))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Tokens.accent, lineWidth: 2)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Tokens.hairline, lineWidth: 1)
                )
        }
    }

    private var chipRow: some View {
        Chip(text: presentation.label, color: presentation.tint)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.kind {
        case .image:
            imagePreview
        case .text:
            if let color = ClipPresentation.detectedColor(in: item.text) {
                colorSwatchPreview(color: color)
            } else {
                textPreview
            }
        case .link:
            linkPreview
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let path = item.previewPath, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 130)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Tokens.imageColor.opacity(0.12))
                Image(systemName: "photo")
                    .foregroundStyle(Tokens.imageColor)
                    .font(.ui(28))
            }
            .frame(maxWidth: .infinity, maxHeight: 130)
        }
    }

    private func colorSwatchPreview(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: 100)
            .overlay(
                Text(item.text ?? "")
                    .font(.mono(11, .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2)
            )
    }

    private var textPreview: some View {
        Text(item.text ?? "")
            .font(.ui(12))
            .foregroundStyle(Tokens.textPrimary)
            .lineLimit(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: false)
    }

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let title = item.title {
                Text(title)
                    .font(.ui(12, .semibold))
                    .foregroundStyle(Tokens.textPrimary)
                    .lineLimit(3)
            }
            Text(item.text ?? "")
                .font(.ui(11))
                .foregroundStyle(Tokens.textTertiary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var footerMeta: some View {
        Text(ClipPresentation.metaLine(for: item))
            .font(.ui(10))
            .foregroundStyle(Tokens.textTertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
