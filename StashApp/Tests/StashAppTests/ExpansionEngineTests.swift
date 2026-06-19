import Testing
import Foundation
@testable import StashApp

private func makeSnippet(trigger: String, expand: String? = nil, dynamic: String? = nil) -> Snippet {
    Snippet(trigger: trigger, label: trigger, expand: expand, dynamic: dynamic, createdAt: 0)
}

@Test func testStaticExpansion() {
    let s = makeSnippet(trigger: ":sig", expand: "— Rohith")
    let result = ExpansionEngine.resolve(s, now: Date())
    #expect(result == "— Rohith")
}

@Test func testDynamicDate() {
    let s = makeSnippet(trigger: ":date", dynamic: "date")
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 1
    comps.day = 1
    let fixedDate = Calendar.current.date(from: comps)!
    let result = ExpansionEngine.resolve(s, now: fixedDate)
    #expect(!result.isEmpty)
    #expect(result.contains("2024"))
}

@Test func testDynamicShrug() {
    let s = makeSnippet(trigger: ":shrug", dynamic: "shrug")
    let result = ExpansionEngine.resolve(s, now: Date())
    #expect(result == "¯\\_(ツ)_/¯")
}

@Test func testDynamicTime() {
    let s = makeSnippet(trigger: ":time", dynamic: "time")
    let result = ExpansionEngine.resolve(s, now: Date())
    #expect(!result.isEmpty)
}

@Test func testMatchAtEnd() {
    let sig = makeSnippet(trigger: ":sig", expand: "— Rohith")
    let result = ExpansionEngine.match(buffer: "hello :sig", snippets: [sig], now: Date())
    #expect(result?.matchLength == 4)
    #expect(result?.replacement == "— Rohith")
}

@Test func testMatchNotMidBuffer() {
    let sig = makeSnippet(trigger: ":sig", expand: "— Rohith")
    let result = ExpansionEngine.match(buffer: "hello :sig world", snippets: [sig], now: Date())
    #expect(result == nil)
}

@Test func testNoMatch() {
    let result = ExpansionEngine.match(buffer: "nothing here", snippets: [], now: Date())
    #expect(result == nil)
}

@Test func testLongestTriggerWins() {
    let short = makeSnippet(trigger: ":s", expand: "short")
    let long = makeSnippet(trigger: ":sig", expand: "long")
    let result = ExpansionEngine.match(buffer: "type :sig", snippets: [short, long], now: Date())
    #expect(result?.replacement == "long")
    #expect(result?.matchLength == 4)
}

@Test func testExpandedApplies() {
    let sig = makeSnippet(trigger: ":sig", expand: "— Rohith")
    let result = ExpansionEngine.expanded(buffer: "hi :sig", snippets: [sig], now: Date())
    #expect(result?.text.hasSuffix("— Rohith") == true)
    #expect(result?.expandedTrigger == ":sig")
}

@Test func testExpandedNilNoMatch() {
    let result = ExpansionEngine.expanded(buffer: "no match", snippets: [], now: Date())
    #expect(result == nil)
}

@Test func testEmojiRocketExpands() {
    let result = ExpansionEngine.match(buffer: "hello :rocket:", snippets: [], now: Date())
    #expect(result?.replacement == "🚀")
    #expect(result?.matchLength == 8)
}

@Test func testEmojiFireExpands() {
    let result = ExpansionEngine.match(buffer: ":fire:", snippets: [], now: Date())
    #expect(result?.replacement == "🔥")
    #expect(result?.matchLength == 6)
}

@Test func testEmojiPlusOneExpands() {
    let result = ExpansionEngine.match(buffer: ":+1:", snippets: [], now: Date())
    #expect(result?.replacement == "👍")
    #expect(result?.matchLength == 4)
}

@Test func testEmojiMinusOneExpands() {
    let result = ExpansionEngine.match(buffer: ":-1:", snippets: [], now: Date())
    #expect(result?.replacement == "👎")
    #expect(result?.matchLength == 4)
}

@Test func testEmojiNoClosingColonReturnsNil() {
    let result = ExpansionEngine.match(buffer: ":rocket", snippets: [], now: Date())
    #expect(result == nil)
}

@Test func testEmojiUnknownCodeReturnsNil() {
    let result = ExpansionEngine.match(buffer: ":notarealcode123:", snippets: [], now: Date())
    #expect(result == nil)
}

@Test func testEmojiEmptyCodeReturnsNil() {
    let result = ExpansionEngine.match(buffer: "::", snippets: [], now: Date())
    #expect(result == nil)
}

@Test func testSnippetTakesPriorityOverEmoji() {
    let rocketSnippet = makeSnippet(trigger: ":rocket:", expand: "custom rocket")
    let result = ExpansionEngine.match(buffer: "go :rocket:", snippets: [rocketSnippet], now: Date())
    #expect(result?.replacement == "custom rocket")
}
