import Testing
@testable import StashApp

@Test func testBufferStartsEmpty() {
    let buf = KeystrokeBuffer()
    #expect(buf.value == "")
}

@Test func testAppendBuildsString() {
    var buf = KeystrokeBuffer()
    buf.append("h")
    buf.append("i")
    #expect(buf.value == "hi")
}

@Test func testAppendMultiCharString() {
    var buf = KeystrokeBuffer()
    buf.append("hello")
    #expect(buf.value == "hello")
}

@Test func testBackspaceRemovesLastChar() {
    var buf = KeystrokeBuffer()
    buf.append("abc")
    buf.backspace()
    #expect(buf.value == "ab")
}

@Test func testBackspaceOnEmptyIsNoOp() {
    var buf = KeystrokeBuffer()
    buf.backspace()
    #expect(buf.value == "")
}

@Test func testBackspaceOnSingleChar() {
    var buf = KeystrokeBuffer()
    buf.append("x")
    buf.backspace()
    #expect(buf.value == "")
}

@Test func testResetClears() {
    var buf = KeystrokeBuffer()
    buf.append("hello world")
    buf.reset()
    #expect(buf.value == "")
}

@Test func testResetOnEmptyIsNoOp() {
    var buf = KeystrokeBuffer()
    buf.reset()
    #expect(buf.value == "")
}

@Test func testAppendPast40CharsCapsAt40() {
    var buf = KeystrokeBuffer()
    let longString = String(repeating: "a", count: 50)
    buf.append(longString)
    #expect(buf.value.count == 40)
}

@Test func testCapKeepsLastChars() {
    var buf = KeystrokeBuffer()
    let prefix = String(repeating: "a", count: 30)
    let suffix = "0123456789012345678901234567890123456789"
    buf.append(prefix)
    buf.append(suffix)
    #expect(buf.value.count == 40)
    let expectedSuffix = String(suffix.suffix(40))
    #expect(buf.value.hasSuffix(expectedSuffix))
}

@Test func testCapPreservesOrder() {
    var buf = KeystrokeBuffer()
    buf.append("12345678901234567890")
    buf.append("abcdefghijabcdefghij")
    buf.append("ZZZZZZZZZZZZZZZZZZZZZ")
    let result = buf.value
    #expect(result.count == 40)
    #expect(result.hasSuffix("ZZZZZZZZZZZZZZZZZZZZZ".suffix(min(21, result.count))))
}

@Test func testAppendExactly40DoesNotTruncate() {
    var buf = KeystrokeBuffer()
    let exactly40 = String(repeating: "x", count: 40)
    buf.append(exactly40)
    #expect(buf.value.count == 40)
    #expect(buf.value == exactly40)
}

@Test func testAppendIncrementallyPast40() {
    var buf = KeystrokeBuffer()
    for i in 0..<50 {
        buf.append(String(i % 10))
    }
    #expect(buf.value.count == 40)
}

@Test func testResetThenAppendWorks() {
    var buf = KeystrokeBuffer()
    buf.append("something")
    buf.reset()
    buf.append("new")
    #expect(buf.value == "new")
}

@Test func testBackspaceThenAppend() {
    var buf = KeystrokeBuffer()
    buf.append("ab")
    buf.backspace()
    buf.append("c")
    #expect(buf.value == "ac")
}
