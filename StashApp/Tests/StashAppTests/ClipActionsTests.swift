import Testing
@testable import StashApp

@Test func upperTransform() { #expect(TextTransform.upper.apply("aBc") == "ABC") }
@Test func lowerTransform() { #expect(TextTransform.lower.apply("ABC") == "abc") }
@Test func trimTransform() { #expect(TextTransform.trim.apply(" x ") == "x") }
@Test func base64RoundTrip() {
    let original = "hello world"
    let encoded = TextTransform.base64Encode.apply(original)
    #expect(encoded != nil)
    let decoded = TextTransform.base64Decode.apply(encoded!)
    #expect(decoded == original)
}
@Test func base64DecodeInvalid() { #expect(TextTransform.base64Decode.apply("not base64!!") == nil) }
@Test func jsonPrettyValid() {
    let result = TextTransform.jsonPretty.apply("{\"b\":1,\"a\":2}")
    #expect(result != nil)
    let r = result!
    #expect(r.range(of: "\"a\"")!.lowerBound < r.range(of: "\"b\"")!.lowerBound)
}
@Test func jsonPrettyInvalid() { #expect(TextTransform.jsonPretty.apply("nope") == nil) }
@Test func urlRoundTrip() {
    let original = "hello world & more"
    let encoded = TextTransform.urlEncode.apply(original)
    #expect(encoded != nil)
    let decoded = TextTransform.urlDecode.apply(encoded!)
    #expect(decoded == original)
}
