import Testing
@testable import StashApp

@Test func hubTabHasSixOrderedTabs() {
    #expect(HubTab.allCases.map(\.label) == ["Clipboard","Notes","To-dos","Snippets","Windows","AI"])
}
