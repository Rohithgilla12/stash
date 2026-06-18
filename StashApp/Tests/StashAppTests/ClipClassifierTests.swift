import Testing
import AppKit
@testable import StashApp

private final class FakePB: PasteboardReading, @unchecked Sendable {
    var changeCount = 0
    var _string: String?
    var _image: NSImage?
    var _file: URL?
    init(changeCount: Int = 0, _string: String? = nil, _image: NSImage? = nil, _file: URL? = nil) {
        self.changeCount = changeCount; self._string = _string; self._image = _image; self._file = _file
    }
    func string() -> String? { _string }
    func image() -> NSImage? { _image }
    func fileURL() -> URL? { _file }
}

@Test func classifiesURLStringAsLink() {
    let c = ClipClassifier.classify(FakePB(_string: "https://example.com/x"))
    #expect(c == .link(URL(string: "https://example.com/x")!))
}

@Test func classifiesPlainStringAsText() {
    let c = ClipClassifier.classify(FakePB(_string: "just some words"))
    #expect(c == .text("just some words"))
}

@Test func classifiesImageWhenPresent() {
    let img = NSImage(size: NSSize(width: 2, height: 2))
    let c = ClipClassifier.classify(FakePB(_string: nil, _image: img))
    guard case .image = c else { Issue.record("expected image"); return }
}

@Test func returnsNilWhenEmpty() {
    #expect(ClipClassifier.classify(FakePB()) == nil)
}

@Test func blankStringIsNil() {
    #expect(ClipClassifier.classify(FakePB(_string: "   ")) == nil)
}

@Test func classifiesImageFileURLAsImage() {
    let url = URL(fileURLWithPath: "/tmp/photo.png")
    let c = ClipClassifier.classify(FakePB(_file: url))
    guard case let .image(_, name) = c else { Issue.record("expected image"); return }
    #expect(name == "photo.png")
}
