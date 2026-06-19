import Testing
@testable import StashApp

@Test func hubTabHasSevenOrderedTabs() {
    #expect(HubTab.allCases.map(\.label) == ["Clipboard","Notes","To-dos","Focus","Snippets","Windows","AI"])
}
