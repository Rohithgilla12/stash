import Testing
@testable import StashApp

@Test func isIgnoredNilBundleID() { #expect(!ClipboardIgnoreList.isIgnored(nil, in: ["a"])) }
@Test func isIgnoredEmptyList() { #expect(!ClipboardIgnoreList.isIgnored("a", in: [])) }
@Test func isIgnoredExactMatch() { #expect(ClipboardIgnoreList.isIgnored("com.x.app", in: ["com.x.app"])) }
@Test func isIgnoredCaseInsensitive() { #expect(ClipboardIgnoreList.isIgnored("COM.X.App", in: ["com.x.app"])) }
