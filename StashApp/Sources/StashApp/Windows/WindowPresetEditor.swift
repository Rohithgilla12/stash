import SwiftUI

struct WindowPresetEditor: View {
    private enum DisplayOption: Hashable {
        case active, main, index(Int)
        var label: String {
            switch self {
            case .active: "Active Display"
            case .main: "Main Display"
            case .index(let i): "Display \(i + 1)"
            }
        }
    }

    let editingPreset: WindowPreset?
    let onSave: (WindowPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var widthValue: Double
    @State private var widthMode: PresetSizeMode
    @State private var heightValue: Double
    @State private var heightMode: PresetSizeMode
    @State private var anchor: PresetAnchor
    @State private var xOffset: Double
    @State private var yOffset: Double
    @State private var displayOption: DisplayOption

    init(editingPreset: WindowPreset?, onSave: @escaping (WindowPreset) -> Void) {
        self.editingPreset = editingPreset
        self.onSave = onSave

        let p = editingPreset
        _name = State(initialValue: p?.name ?? "")
        _widthMode = State(initialValue: p?.widthMode ?? .percent)
        _widthValue = State(initialValue: p.map { $0.widthMode == .percent ? $0.width * 100 : $0.width } ?? 60)
        _heightMode = State(initialValue: p?.heightMode ?? .percent)
        _heightValue = State(initialValue: p.map { $0.heightMode == .percent ? $0.height * 100 : $0.height } ?? 60)
        _anchor = State(initialValue: p?.anchor ?? .center)
        _xOffset = State(initialValue: p?.xOffset ?? 0)
        _yOffset = State(initialValue: p?.yOffset ?? 0)
        if let p {
            if p.displayMode == "main" {
                _displayOption = State(initialValue: .main)
            } else if p.displayMode == "index" {
                _displayOption = State(initialValue: .index(p.displayIndex))
            } else {
                _displayOption = State(initialValue: .active)
            }
        } else {
            _displayOption = State(initialValue: .active)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                titleRow
                nameSection
                dimensionsSection
                anchorSection
                offsetSection
                displaySection
                actionButtons
            }
            .padding(Space.md)
        }
        .frame(minWidth: 340, minHeight: 320)
    }

    private var titleRow: some View {
        Text(editingPreset == nil ? "New Preset" : "Edit Preset")
            .font(.headline)
            .foregroundStyle(Tokens.textPrimary)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("NAME")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            TextField("My preset", text: $name)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
                .padding(8)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        }
    }

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("SIZE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            HStack(spacing: Space.xs) {
                Text("W")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.textSecondary)
                    .frame(width: 14)
                TextField("60", value: $widthValue, format: .number)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                    .frame(maxWidth: .infinity)
                Picker("", selection: $widthMode) {
                    Text("%").tag(PresetSizeMode.percent)
                    Text("pt").tag(PresetSizeMode.points)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
            }
            HStack(spacing: Space.xs) {
                Text("H")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.textSecondary)
                    .frame(width: 14)
                TextField("60", value: $heightValue, format: .number)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Tokens.textPrimary)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
                    .frame(maxWidth: .infinity)
                Picker("", selection: $heightMode) {
                    Text("%").tag(PresetSizeMode.percent)
                    Text("pt").tag(PresetSizeMode.points)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
            }
        }
    }

    private var anchorSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("ANCHOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            AnchorGrid(selected: $anchor)
        }
    }

    private var offsetSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("OFFSET")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            Stepper("X: \(Int(xOffset)) pt", value: $xOffset, in: -500...500, step: 10)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
            Stepper("Y: \(Int(yOffset)) pt", value: $yOffset, in: -500...500, step: 10)
                .font(.callout)
                .foregroundStyle(Tokens.textPrimary)
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("DISPLAY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
            Picker("Display", selection: $displayOption) {
                Text(DisplayOption.active.label).tag(DisplayOption.active)
                Text(DisplayOption.main.label).tag(DisplayOption.main)
                ForEach(0..<NSScreen.screens.count, id: \.self) { i in
                    Text(DisplayOption.index(i).label).tag(DisplayOption.index(i))
                }
            }
            .pickerStyle(.menu)
            .font(.callout)
            .foregroundStyle(Tokens.textPrimary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Space.md) {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.textSecondary)

            Spacer()

            Button("Save") { commitSave() }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Tokens.textTertiary : Tokens.accent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func commitSave() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { dismiss(); return }

        let clampedWidth: Double
        let storedWidth: Double
        if widthMode == .percent {
            clampedWidth = min(max(widthValue, 10), 100)
            storedWidth = clampedWidth / 100.0
        } else {
            clampedWidth = min(max(widthValue, 200), 10_000)
            storedWidth = clampedWidth
        }

        let clampedHeight: Double
        let storedHeight: Double
        if heightMode == .percent {
            clampedHeight = min(max(heightValue, 10), 100)
            storedHeight = clampedHeight / 100.0
        } else {
            clampedHeight = min(max(heightValue, 200), 10_000)
            storedHeight = clampedHeight
        }

        let (dm, di): (String, Int)
        switch displayOption {
        case .active: (dm, di) = ("active", 0)
        case .main: (dm, di) = ("main", 0)
        case .index(let i): (dm, di) = ("index", i)
        }

        let preset = WindowPreset(
            id: editingPreset?.id ?? UUID().uuidString,
            name: trimmedName,
            widthMode: widthMode,
            width: storedWidth,
            heightMode: heightMode,
            height: storedHeight,
            anchor: anchor,
            xOffset: xOffset,
            yOffset: yOffset,
            displayMode: dm,
            displayIndex: di,
            hotkeyKeyCode: nil,
            hotkeyModifiers: nil,
            createdAt: editingPreset?.createdAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        )
        onSave(preset)
        dismiss()
    }
}

private struct AnchorGrid: View {
    @Binding var selected: PresetAnchor

    private let layout: [[PresetAnchor]] = [
        [.topLeft, .top, .topRight],
        [.left, .center, .right],
        [.bottomLeft, .bottom, .bottomRight]
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<layout.count, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(layout[row], id: \.self) { cell in
                        anchorButton(cell)
                    }
                }
            }
        }
    }

    private func anchorButton(_ anchor: PresetAnchor) -> some View {
        Button {
            selected = anchor
        } label: {
            Image(systemName: selected == anchor ? "circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(selected == anchor ? Tokens.accent : Tokens.textTertiary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected == anchor ? Tokens.accent.opacity(0.1) : Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}
