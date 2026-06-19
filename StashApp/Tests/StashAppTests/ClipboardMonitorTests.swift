import Testing
import GRDB
import AppKit
@testable import StashApp

private final class MutPB: PasteboardReading, @unchecked Sendable {
    var changeCount = 1
    var str: String?
    var concealed: Bool = false
    func string() -> String? { str }
    func image() -> NSImage? { nil }
    func fileURL() -> URL? { nil }
    func isConcealed() -> Bool { concealed }
}

@Test func captureInsertsOnNewLink() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "https://a.com"
    final class Counter: @unchecked Sendable { var t: Int64 = 100 }
    let counter = Counter()
    let mon = ClipboardMonitor(store: store,
                               cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb,
                               now: { counter.t += 1; return counter.t },
                               makeID: { UUID().uuidString })
    let inserted = await mon.capture(frontApp: "Safari")
    #expect(inserted)
    let all = try await store.all()
    #expect(all.first?.kind == .link)
    #expect(all.first?.app == "Safari")
}

@Test func captureIgnoresUnchangedChangeCount() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "hello"
    let mon = ClipboardMonitor(store: store, cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb, now: { 1 }, makeID: { "id1" })
    _ = await mon.capture(frontApp: nil)         // first capture inserts
    let second = await mon.capture(frontApp: nil) // same changeCount -> ignored
    #expect(second == false)
}

@Test func captureSkipsSelfCopy() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "copied-back"
    let mon = ClipboardMonitor(store: store, cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb, now: { 1 }, makeID: { "id1" })
    pb.changeCount = 5
    await mon.noteSelfCopy(changeCount: 5)
    #expect(await mon.capture(frontApp: nil) == false)
}

@Test func captureSkipsConcealedItems() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "secret-password"; pb.changeCount = 2; pb.concealed = true
    let mon = ClipboardMonitor(store: store, cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb, now: { 1 }, makeID: { "id1" })
    let inserted = await mon.capture(frontApp: nil)
    #expect(inserted == false)
    #expect(try await store.all().isEmpty)
}

@Test func captureStoresBundleID() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "some text"; pb.changeCount = 7
    let mon = ClipboardMonitor(store: store, cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb, now: { 1 }, makeID: { "id-bundle" })
    let inserted = await mon.capture(frontApp: "MyApp", frontAppBundleID: "com.example.myapp")
    #expect(inserted)
    let all = try await store.all()
    #expect(all.first?.app == "MyApp")
    #expect(all.first?.appBundleID == "com.example.myapp")
}
