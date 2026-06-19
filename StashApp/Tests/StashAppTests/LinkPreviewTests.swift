import Testing
import CryptoKit
import Foundation
@testable import StashApp

@Test func linkPreviewCodableRoundTrip() throws {
    let original = LinkPreview(title: "Example Title", domain: "example.com", imagePath: "/tmp/abc.png", failed: false)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LinkPreview.self, from: data)
    #expect(decoded == original)
    #expect(decoded.title == "Example Title")
    #expect(decoded.domain == "example.com")
    #expect(decoded.imagePath == "/tmp/abc.png")
    #expect(decoded.failed == false)
}

@Test func cacheKeyStability() {
    let urlString = "https://example.com/some/path?q=1"
    let key1 = sha256Hex(urlString)
    let key2 = sha256Hex(urlString)
    #expect(key1 == key2)
    let allowedChars = CharacterSet(charactersIn: "0123456789abcdef")
    #expect(key1.unicodeScalars.allSatisfy { allowedChars.contains($0) })
    #expect(key1.count == 64)
}

@Test func failedLinkPreviewRoundTrip() throws {
    let original = LinkPreview(title: nil, domain: "example.com", imagePath: nil, failed: true)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LinkPreview.self, from: data)
    #expect(decoded.failed == true)
    #expect(decoded.title == nil)
    #expect(decoded.imagePath == nil)
    #expect(decoded.domain == "example.com")
}

private func sha256Hex(_ string: String) -> String {
    let hash = SHA256.hash(data: Data(string.utf8))
    return hash.map { String(format: "%02x", $0) }.joined()
}
