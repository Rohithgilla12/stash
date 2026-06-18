import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.text ?? "Untitled")
                    .lineLimit(1)
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Tokens.textPrimary)
                Text(sub).font(.caption).foregroundStyle(Tokens.textTertiary).lineLimit(1)
            }
            Spacer()
            Button(action: onTogglePin) {
                Circle()
                    .fill(item.pinned ? Tokens.accent : Color.black.opacity(0.18))
                    .frame(width: 8, height: 8)
            }.buttonStyle(.plain)
            Text(item.kind.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(8)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }

    @ViewBuilder private var preview: some View {
        if item.kind == .image, let path = item.previewPath, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                .frame(width: Tokens.thumbSize.width, height: Tokens.thumbSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Tokens.accent.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: icon).foregroundStyle(Tokens.accent).font(.system(size: 13)))
        }
    }

    private var icon: String {
        switch item.kind { case .text: "doc.text"; case .link: "link"; case .image: "photo" }
    }

    private var sub: String {
        let t = Date(timeIntervalSince1970: TimeInterval(item.createdAt) / 1000)
        let rel = RelativeDateTimeFormatter().localizedString(for: t, relativeTo: Date())
        return [rel, item.app].compactMap { $0 }.joined(separator: " · ")
    }
}
