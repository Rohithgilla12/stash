import Testing
@testable import StashApp

@Test func matchesIsCaseInsensitiveOverTitleAndText() {
    let i = ClipItem(id: "1", kind: .text, text: "Hello World", app: nil,
                     pinned: false, createdAt: 1, title: "Greeting", previewPath: nil)
    #expect(ClipboardViewModel.matches(i, query: "hello"))
    #expect(ClipboardViewModel.matches(i, query: "GREET"))
    #expect(!ClipboardViewModel.matches(i, query: "zzz"))
    #expect(ClipboardViewModel.matches(i, query: ""))
}
