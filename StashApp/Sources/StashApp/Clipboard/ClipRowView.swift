import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var ogPreview: LinkPreview?

    var body: some View {
        HoverRow { hovering in
            HStack(spacing: 10) {
                previewTile
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.kind == .link ? (ogPreview?.title ?? item.title ?? item.text ?? "Untitled") : (item.title ?? item.text ?? "Untitled"))
                        .font(.ui(13, .medium))
                        .foregroundStyle(Tokens.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        if let icon = AppIconProvider.icon(forBundleID: item.appBundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 13, height: 13)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        Text(ClipPresentation.metaLine(for: item))
                            .font(.ui(11))
                            .foregroundStyle(Tokens.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                trailingContent(hovering: hovering)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture(perform: onCopy)
            .task {
                if item.kind == .link {
                    ogPreview = await LinkPreviewService.shared.preview(for: item.text ?? "")
                }
            }
        }
    }

    @ViewBuilder private var previewTile: some View {
        let presentation = ClipPresentation.style(for: item)

        if item.kind == .image, let path = item.previewPath, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if item.kind == .link, let path = ogPreview?.imagePath, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let swatchColor = ClipPresentation.detectedColor(in: item.text) {
            RoundedRectangle(cornerRadius: 8)
                .fill(swatchColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(presentation.tint.opacity(0.14))
                .overlay(
                    Image(systemName: presentation.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(presentation.tint)
                )
        }
    }

    @ViewBuilder private func trailingContent(hovering: Bool) -> some View {
        let presentation = ClipPresentation.style(for: item)

        if hovering {
            HStack(spacing: 2) {
                ghostButton(icon: item.pinned ? "pin.fill" : "pin", action: onTogglePin)

                ghostButton(icon: "doc.on.doc", action: onCopy)

                if let onDelete {
                    ghostButton(icon: "xmark", action: onDelete)
                }
            }
        } else {
            HStack(spacing: Space.sm) {
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Tokens.accent)
                }

                Chip(text: presentation.label, color: presentation.tint)
            }
        }
    }

    private func ghostButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.textTertiary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(GhostIconButtonStyle())
    }
}

private struct GhostIconButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(hovering ? Tokens.accent : Tokens.textTertiary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Tokens.accent.opacity(0.10) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .onHover { isHovering in
                withAnimation(.easeOut(duration: 0.10)) {
                    hovering = isHovering
                }
            }
    }
}
