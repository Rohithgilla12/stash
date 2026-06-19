struct KeystrokeBuffer: Sendable {
    private(set) var value: String = ""

    private static let maxLength = 40

    mutating func append(_ s: String) {
        value += s
        if value.count > Self.maxLength {
            value = String(value.suffix(Self.maxLength))
        }
    }

    mutating func backspace() {
        guard !value.isEmpty else { return }
        value.removeLast()
    }

    mutating func reset() {
        value = ""
    }
}
