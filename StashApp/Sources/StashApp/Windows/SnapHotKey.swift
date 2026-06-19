import Carbon

struct SnapHotKey: Sendable {
    let target: SnapTarget
    let keyCode: UInt32
    let modifiers: UInt32

    static let all: [SnapHotKey] = {
        let mods = UInt32(controlKey | optionKey)
        return [
            // Halves
            SnapHotKey(target: .leftHalf,     keyCode: 123, modifiers: mods),
            SnapHotKey(target: .rightHalf,    keyCode: 124, modifiers: mods),
            SnapHotKey(target: .bottomHalf,   keyCode: 125, modifiers: mods),
            SnapHotKey(target: .topHalf,      keyCode: 126, modifiers: mods),
            // Full screen
            SnapHotKey(target: .fullScreen,   keyCode: 36,  modifiers: mods),
            // Quarters (U / I / J / K)
            SnapHotKey(target: .topLeft,      keyCode: 32,  modifiers: mods),
            SnapHotKey(target: .topRight,     keyCode: 34,  modifiers: mods),
            SnapHotKey(target: .bottomLeft,   keyCode: 38,  modifiers: mods),
            SnapHotKey(target: .bottomRight,  keyCode: 40,  modifiers: mods),
            // Thirds (D / F / G)
            SnapHotKey(target: .leftThird,    keyCode: 2,   modifiers: mods),
            SnapHotKey(target: .centerThird,  keyCode: 3,   modifiers: mods),
            SnapHotKey(target: .rightThird,   keyCode: 5,   modifiers: mods),
        ]
    }()
}
