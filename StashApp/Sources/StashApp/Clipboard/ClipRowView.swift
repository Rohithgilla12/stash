import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    var onDelete: (() -> Void)? = nil
    var onActed: (String) -> Void = { _ in }

    @State private var ogPreview: LinkPreview?
    @State private var showQR = false

    private var titleText: String {
        if item.kind == .link {
            return ogPreview?.title ?? item.title ?? item.text ?? "Untitled"
        }
        return item.title ?? item.text ?? "Untitled"
    }

    var body: some View {
        HoverRow { hovering in
            rowContent(hovering: hovering)
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
        .contextMenu { contextMenuItems }
        .popover(isPresented: $showQR) { QRPopoverView(text: item.text ?? "") }
    }

    @ViewBuilder private var contextMenuItems: some View {
        if item.kind == .link {
            Button("Open Link") {
                if let u = URL(string: item.text ?? "") { NSWorkspace.shared.open(u) }
            }
        }

        Button("Copy") { onCopy() }

        if (item.kind == .text || item.kind == .link), let src = item.text, !src.isEmpty {
            Menu("Transform") {
                ForEach(TextTransform.allCases, id: \.self) { transform in
                    if transform.apply(src) != nil {
                        Button(transform.rawValue) {
                            if let result = transform.apply(src) {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(result, forType: .string)
                                onActed("Transformed → clipboard")
                            }
                        }
                    }
                }
            }
        }

        if (item.kind == .text || item.kind == .link), !(item.text ?? "").isEmpty {
            Button("Show QR Code") { showQR = true }
        }
    }

    private func rowContent(hovering: Bool) -> some View {
        HStack(spacing: 10) {
            previewTile
                .frame(width: 40, height: 40)
            details
            Spacer()
            trailingContent(hovering: hovering)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleText)
                .font(.ui(13, .medium))
                .foregroundStyle(Tokens.textPrimary)
                .lineLimit(1)
            metaRow
        }
    }

    private var metaRow: some View {
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

private struct QRPopoverView: View {
    let text: String
    @State private var qrImage: NSImage?

    var body: some View {
        VStack(spacing: Space.sm) {
            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Couldn't generate QR")
                    .foregroundStyle(.secondary)
                    .frame(width: 220, height: 220)
            }

            Text(text.count > 60 ? String(text.prefix(60)) + "…" : text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 260)
        .task {
            qrImage = QRCode.image(from: text)
        }
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
