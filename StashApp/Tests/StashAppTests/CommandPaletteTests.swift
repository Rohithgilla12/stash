import Testing
@testable import StashApp

@Suite("CommandPalette.filter")
struct CommandPaletteTests {
    private func item(_ title: String, kind: String = "action") -> PaletteItem {
        PaletteItem(id: title, title: title, subtitle: "", symbol: "star", kind: kind, run: {})
    }

    @Test func emptyQueryReturnsAllItemsActionsFirst() {
        let items = [item("Foo", kind: "clip"), item("Bar", kind: "action"), item("Baz", kind: "note")]
        let result = CommandPalette.filter(items, query: "")
        #expect(result.count == 3)
        #expect(result[0].kind == "action")
    }

    @Test func subsequenceMatchesNonContiguous() {
        // "np" is a non-contiguous subsequence of "New Project" (N…P)
        // "New note" has no 'p' so it should not match; "Unrelated" has no 'n' then 'p'
        let items = [item("New Project"), item("New note"), item("Unrelated")]
        let result = CommandPalette.filter(items, query: "np")
        let titles = result.map(\.title)
        #expect(titles.contains("New Project"))
        #expect(!titles.contains("Unrelated"))
    }

    @Test func prefixRanksBeforeMidString() {
        let items = [item("Renew subscription"), item("New note")]
        let result = CommandPalette.filter(items, query: "new")
        #expect(result.first?.title == "New note")
    }

    @Test func noMatchReturnsEmpty() {
        let items = [item("Open Paste browser"), item("New note")]
        let result = CommandPalette.filter(items, query: "zzz")
        #expect(result.isEmpty)
    }

    @Test func caseInsensitiveMatch() {
        let items = [item("New note")]
        let result = CommandPalette.filter(items, query: "NOTE")
        #expect(!result.isEmpty)
    }
}
