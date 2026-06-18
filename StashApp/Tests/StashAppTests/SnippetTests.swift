import Testing
import GRDB
@testable import StashApp

@Test func testRoundTripStaticSnippet() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    let snippet = Snippet(
        trigger: ":sig",
        label: "Signature",
        expand: "— Rohith",
        dynamic: nil,
        createdAt: 1000
    )
    try q.write { try snippet.insert($0) }
    let got = try q.read { try Snippet.fetchOne($0, key: ":sig") }
    #expect(got?.trigger == ":sig")
    #expect(got?.label == "Signature")
    #expect(got?.expand == "— Rohith")
    #expect(got?.dynamic == nil)
    #expect(got?.createdAt == 1000)
}

@Test func testRoundTripDynamicSnippet() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    let snippet = Snippet(
        trigger: ":date",
        label: "Date",
        expand: nil,
        dynamic: "date",
        createdAt: 2000
    )
    try q.write { try snippet.insert($0) }
    let got = try q.read { try Snippet.fetchOne($0, key: ":date") }
    #expect(got?.trigger == ":date")
    #expect(got?.label == "Date")
    #expect(got?.expand == nil)
    #expect(got?.dynamic == "date")
    #expect(got?.createdAt == 2000)
}
