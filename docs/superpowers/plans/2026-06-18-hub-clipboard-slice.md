# Stash Slice 1 — Menu-bar Hub + Clipboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app (the Stash "hub") whose Clipboard tab captures text, links, and images/GIFs from the system pasteboard, persists them to the shared `stash.db`, and shows them live; the other five tabs render styled placeholders.

**Architecture:** SwiftUI `App` with a `MenuBarExtra(.window)` scene hosting `HubView` (search + 6-tab bar + scrollable content). A `ClipboardMonitor` actor polls `NSPasteboard.changeCount`, classifies each change via a pure `ClipClassifier`, caches image thumbnails to a sidecar dir, and writes rows through a `ClipboardStore` actor into a GRDB `DatabasePool` (WAL) at `~/Library/Application Support/Stash/stash.db` — the same file the Node MCP server uses. A `@MainActor @Observable ClipboardViewModel` subscribes to a GRDB `ValueObservation` so the UI updates live.

**Tech Stack:** Swift 6.3 (strict concurrency), SwiftUI, AppKit (`NSPasteboard`, `NSWorkspace`), GRDB.swift (SQLite), XcodeGen (project generation), Swift Testing (`import Testing`), xcodebuild.

## Global Constraints

- Swift 6 strict concurrency: store/monitor are `actor`s, views are `@MainActor`, all DB record types are `Sendable`.
- Target platform: macOS 26 (`macosx` deployment target `14.0` minimum to keep `MenuBarExtra`/GRDB happy; build SDK is 26).
- App is an **agent app**: `LSUIElement = true` (Info.plist), no Dock icon.
- App is **non-sandboxed** (`com.apple.security.app-sandbox = false` / no sandbox entitlement) so it shares `~/Library/Application Support/Stash/stash.db` with the Node MCP server.
- DB path: `~/Library/Application Support/Stash/stash.db`; image cache: `~/Library/Application Support/Stash/clip-cache/`. Honor `STASH_DB` / `STASH_DB_DIR` env overrides for parity with `mcp-server/src/db.ts` and tests.
- Shared SQLite schema is the contract: any `clipboard` table change is mirrored in `mcp-server/src/db.ts`.
- History cap: 200 most-recent **non-pinned** rows; pinned rows are never auto-deleted.
- Design tokens (verbatim from `README.md`): accent terracotta `#c8642f`; panel fill `rgba(252,250,246,0.93)`; panel radius `16`, rows/cards radius `9`; text primary `#2c2925`, secondary `#6b655c`, tertiary `#9a948a`; preview thumb `58×38`; panel width `456`, content max-height `600`.
- Pasteboard poll interval: `0.5s`.
- Do NOT use banner comments like `// ===== Section =====` (user preference).

---

### Task 1: Project scaffold — XcodeGen + GRDB + empty MenuBarExtra

**Files:**
- Create: `StashApp/project.yml`
- Create: `StashApp/Sources/StashApp/StashApp.swift`
- Create: `StashApp/Sources/StashApp/Info.plist`
- Create: `StashApp/.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable `StashApp` scheme and a `StashAppTests` test target; an `App` named `StashApp`.

- [ ] **Step 1: Install XcodeGen**

Run: `brew install xcodegen`
Expected: `xcodegen` on PATH (`xcodegen --version` prints a version).

- [ ] **Step 2: Write `StashApp/project.yml`**

```yaml
name: StashApp
options:
  bundleIdPrefix: com.rohithgilla.stash
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift
    from: "7.0.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  StashApp:
    type: application
    platform: macOS
    sources:
      - path: Sources/StashApp
    info:
      path: Sources/StashApp/Info.plist
      properties:
        LSUIElement: true
        CFBundleDisplayName: Stash
        NSHumanReadableCopyright: ""
    settings:
      base:
        ENABLE_APP_SANDBOX: NO
        GENERATE_INFOPLIST_FILE: NO
        PRODUCT_BUNDLE_IDENTIFIER: com.rohithgilla.stash.app
        COMBINE_HIDPI_IMAGES: YES
    dependencies:
      - package: GRDB
  StashAppTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/StashAppTests
    dependencies:
      - target: StashApp
      - package: GRDB
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.rohithgilla.stash.tests
schemes:
  StashApp:
    build:
      targets:
        StashApp: all
        StashAppTests: [test]
    run:
      config: Debug
    test:
      targets:
        - StashAppTests
```

- [ ] **Step 3: Write a minimal `Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>StashApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
```

- [ ] **Step 4: Write a minimal `StashApp.swift`**

```swift
import SwiftUI

@main
struct StashApp: App {
    var body: some Scene {
        MenuBarExtra("Stash", systemImage: "tray.full") {
            Text("Stash")
                .padding()
                .frame(width: 456)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Write `StashApp/.gitignore`**

```
*.xcodeproj
.build/
DerivedData/
```

- [ ] **Step 6: Generate the project**

Run: `cd StashApp && xcodegen generate`
Expected: `Created project at StashApp/StashApp.xcodeproj`.

- [ ] **Step 7: Build it**

Run: `cd StashApp && xcodebuild -scheme StashApp -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

(If `git init` has not been run, do that first: `git init` at repo root.)
```bash
git add StashApp/project.yml StashApp/Sources StashApp/.gitignore
git commit -m "feat(app): scaffold StashApp menu-bar shell with XcodeGen + GRDB"
```

---

### Task 2: Design tokens

**Files:**
- Create: `StashApp/Sources/StashApp/Design/Tokens.swift`
- Test: `StashApp/Tests/StashAppTests/TokensTests.swift`

**Interfaces:**
- Produces:
  - `extension Color { init(hex: String) }` — parses `"#rrggbb"`.
  - `enum Tokens` with: `static let accent: Color`, `panelFill: Color`, `textPrimary/textSecondary/textTertiary: Color`, `panelRadius: CGFloat = 16`, `rowRadius: CGFloat = 9`, `panelWidth: CGFloat = 456`, `contentMaxHeight: CGFloat = 600`, `thumbSize: CGSize = .init(width: 58, height: 38)`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import SwiftUI
@testable import StashApp

@Test func hexParsesSixDigits() {
    let c = Color(hex: "#c8642f")
    let ns = NSColor(c).usingColorSpace(.sRGB)!
    #expect(abs(ns.redComponent - 200.0/255) < 0.01)
    #expect(abs(ns.greenComponent - 100.0/255) < 0.01)
    #expect(abs(ns.blueComponent - 47.0/255) < 0.01)
}

@Test func tokenConstantsMatchSpec() {
    #expect(Tokens.panelWidth == 456)
    #expect(Tokens.panelRadius == 16)
    #expect(Tokens.thumbSize == CGSize(width: 58, height: 38))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `Color(hex:)` / `Tokens` not found.

- [ ] **Step 3: Implement `Tokens.swift`**

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum Tokens {
    static let accent = Color(hex: "#c8642f")
    static let panelFill = Color(.sRGB, red: 252/255, green: 250/255, blue: 246/255, opacity: 0.93)
    static let textPrimary = Color(hex: "#2c2925")
    static let textSecondary = Color(hex: "#6b655c")
    static let textTertiary = Color(hex: "#9a948a")
    static let panelRadius: CGFloat = 16
    static let rowRadius: CGFloat = 9
    static let panelWidth: CGFloat = 456
    static let contentMaxHeight: CGFloat = 600
    static let thumbSize = CGSize(width: 58, height: 38)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/Design StashApp/Tests/StashAppTests/TokensTests.swift
git commit -m "feat(app): add design tokens from README"
```

---

### Task 3: ClipItem record + Database (GRDB setup & migrations)

**Files:**
- Create: `StashApp/Sources/StashApp/Data/ClipKind.swift`
- Create: `StashApp/Sources/StashApp/Data/ClipItem.swift`
- Create: `StashApp/Sources/StashApp/Data/Database.swift`
- Test: `StashApp/Tests/StashAppTests/DatabaseTests.swift`

**Interfaces:**
- Produces:
  - `enum ClipKind: String, Codable, Sendable { case text, link, image }`
  - `struct ClipItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable` with stored columns: `id: String`, `kind: ClipKind` (stored via raw string column `kind`), `text: String?`, `app: String?`, `pinned: Bool`, `createdAt: Int64` (column `created_at`), `title: String?`, `previewPath: String?` (column `preview_path`). `static let databaseTableName = "clipboard"`. Custom `CodingKeys` map `createdAt -> created_at`, `previewPath -> preview_path`.
  - `enum AppPaths { static func dbURL() -> URL; static func cacheDir() -> URL }` honoring `STASH_DB`/`STASH_DB_DIR`.
  - `struct StashDatabase: Sendable { let pool: DatabasePool; init(path: String) throws; static func migrator() -> DatabaseMigrator }`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import GRDB
import Foundation
@testable import StashApp

@Test func migratorCreatesClipboardWithNewColumns() throws {
    let q = try DatabaseQueue()
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { db in try db.columns(in: "clipboard").map(\.name) }
    #expect(Set(cols).isSuperset(of: ["id","kind","text","app","pinned","created_at","title","preview_path"]))
}

@Test func migratorUpgradesNodeStyleTableWithoutDataLoss() throws {
    let q = try DatabaseQueue()
    // Simulate the Node server's original CREATE (no title/preview_path).
    try q.write { db in
        try db.execute(sql: """
            CREATE TABLE clipboard (
              id TEXT PRIMARY KEY, kind TEXT NOT NULL, text TEXT, app TEXT,
              pinned INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
            INSERT INTO clipboard (id,kind,text,app,pinned,created_at)
              VALUES ('a','text','hello','Safari',0,123);
        """)
    }
    try StashDatabase.migrator().migrate(q)
    let cols = try q.read { db in try db.columns(in: "clipboard").map(\.name) }
    #expect(cols.contains("title"))
    #expect(cols.contains("preview_path"))
    let still = try q.read { try ClipItem.fetchOne($0, key: "a") }
    #expect(still?.text == "hello")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `StashDatabase` / `ClipItem` not found.

- [ ] **Step 3: Implement `ClipKind.swift`**

```swift
enum ClipKind: String, Codable, Sendable {
    case text, link, image
}
```

- [ ] **Step 4: Implement `ClipItem.swift`**

```swift
import GRDB

struct ClipItem: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable, Equatable {
    var id: String
    var kind: ClipKind
    var text: String?
    var app: String?
    var pinned: Bool
    var createdAt: Int64
    var title: String?
    var previewPath: String?

    static let databaseTableName = "clipboard"

    enum CodingKeys: String, CodingKey {
        case id, kind, text, app, pinned
        case createdAt = "created_at"
        case title
        case previewPath = "preview_path"
    }
}
```

- [ ] **Step 5: Implement `Database.swift`**

```swift
import GRDB
import Foundation

enum AppPaths {
    static func baseDir() -> URL {
        if let dir = ProcessInfo.processInfo.environment["STASH_DB_DIR"] {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Stash", isDirectory: true)
    }
    static func dbURL() -> URL {
        if let p = ProcessInfo.processInfo.environment["STASH_DB"] {
            return URL(fileURLWithPath: p)
        }
        return baseDir().appendingPathComponent("stash.db")
    }
    static func cacheDir() -> URL {
        baseDir().appendingPathComponent("clip-cache", isDirectory: true)
    }
}

struct StashDatabase: Sendable {
    let pool: DatabasePool

    init(path: String) throws {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        var config = Configuration()
        config.prepareDatabase { db in try db.execute(sql: "PRAGMA journal_mode = WAL") }
        pool = try DatabasePool(path: path, configuration: config)
        try Self.migrator().migrate(pool)
    }

    static func migrator() -> DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_clipboard") { db in
            if try !db.tableExists("clipboard") {
                try db.create(table: "clipboard") { t in
                    t.column("id", .text).primaryKey()
                    t.column("kind", .text).notNull()
                    t.column("text", .text)
                    t.column("app", .text)
                    t.column("pinned", .integer).notNull().defaults(to: 0)
                    t.column("created_at", .integer).notNull()
                }
            }
        }
        m.registerMigration("v2_clip_previews") { db in
            let cols = try db.columns(in: "clipboard").map(\.name)
            if !cols.contains("title") { try db.alter(table: "clipboard") { $0.add(column: "title", .text) } }
            if !cols.contains("preview_path") { try db.alter(table: "clipboard") { $0.add(column: "preview_path", .text) } }
        }
        return m
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add StashApp/Sources/StashApp/Data
git add StashApp/Tests/StashAppTests/DatabaseTests.swift
git commit -m "feat(app): add ClipItem record and GRDB migrations"
```

---

### Task 4: Mirror schema change in the MCP server (contract sync)

**Files:**
- Modify: `mcp-server/src/db.ts:38-45`

**Interfaces:**
- Produces: a Node-side `clipboard` table whose `CREATE TABLE IF NOT EXISTS` includes `title` and `preview_path`, so a Node-first DB creation matches the app's post-migration schema.

- [ ] **Step 1: Update the `clipboard` CREATE in `db.ts`**

Replace the `CREATE TABLE IF NOT EXISTS clipboard (...)` block with:

```ts
CREATE TABLE IF NOT EXISTS clipboard (
  id           TEXT PRIMARY KEY,
  kind         TEXT NOT NULL,              -- 'text' | 'link' | 'image' | ...
  text         TEXT,
  app          TEXT,
  pinned       INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL,
  title        TEXT,                       -- display label (link title / filename / first line)
  preview_path TEXT                        -- sidecar file for image/GIF thumbnails
);
```

- [ ] **Step 2: Verify the server still builds**

Run: `cd mcp-server && npm install && npm run build`
Expected: `tsc` exits 0; `dist/server.js` produced.

- [ ] **Step 3: Commit**

```bash
git add mcp-server/src/db.ts
git commit -m "feat(mcp): add title/preview_path to clipboard schema (app contract sync)"
```

---

### Task 5: ClipClassifier (pure pasteboard classification)

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/PasteboardReading.swift`
- Create: `StashApp/Sources/StashApp/Clipboard/ClipClassifier.swift`
- Test: `StashApp/Tests/StashAppTests/ClipClassifierTests.swift`

**Interfaces:**
- Produces:
  - `protocol PasteboardReading: Sendable { var changeCount: Int { get }; func string() -> String?; func image() -> NSImage?; func fileURL() -> URL? }`
  - `enum CapturedContent: Equatable { case text(String); case link(URL); case image(NSImage?, suggestedName: String?) }` — NOT `Sendable` (it carries `NSImage`); it is produced and consumed entirely inside `ClipboardMonitor`'s actor isolation, so it never crosses a concurrency boundary. `NSImage` is not `Equatable`, so conform manually comparing only the associated metadata for `image` (see Step 3).
  - `enum ClipClassifier { static func classify(_ pb: PasteboardReading) -> CapturedContent? }` — returns `nil` when nothing usable is present. Order: image/file-image first, then URL string, then plain text.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import AppKit
@testable import StashApp

private final class FakePB: PasteboardReading, @unchecked Sendable {
    var changeCount = 0
    var _string: String?
    var _image: NSImage?
    var _file: URL?
    init(changeCount: Int = 0, _string: String? = nil, _image: NSImage? = nil, _file: URL? = nil) {
        self.changeCount = changeCount; self._string = _string; self._image = _image; self._file = _file
    }
    func string() -> String? { _string }
    func image() -> NSImage? { _image }
    func fileURL() -> URL? { _file }
}

@Test func classifiesURLStringAsLink() {
    let c = ClipClassifier.classify(FakePB(_string: "https://example.com/x"))
    #expect(c == .link(URL(string: "https://example.com/x")!))
}

@Test func classifiesPlainStringAsText() {
    let c = ClipClassifier.classify(FakePB(_string: "just some words"))
    #expect(c == .text("just some words"))
}

@Test func classifiesImageWhenPresent() {
    let img = NSImage(size: NSSize(width: 2, height: 2))
    let c = ClipClassifier.classify(FakePB(_string: nil, _image: img))
    guard case .image = c else { Issue.record("expected image"); return }
}

@Test func returnsNilWhenEmpty() {
    #expect(ClipClassifier.classify(FakePB()) == nil)
}

@Test func blankStringIsNil() {
    #expect(ClipClassifier.classify(FakePB(_string: "   ")) == nil)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — types not found.

- [ ] **Step 3: Implement `PasteboardReading.swift` and `ClipClassifier.swift`**

`PasteboardReading.swift`:
```swift
import AppKit

protocol PasteboardReading: Sendable {
    var changeCount: Int { get }
    func string() -> String?
    func image() -> NSImage?
    func fileURL() -> URL?
}
```

`ClipClassifier.swift`:
```swift
import AppKit

enum CapturedContent: Equatable {
    case text(String)
    case link(URL)
    case image(NSImage?, suggestedName: String?)

    static func == (lhs: CapturedContent, rhs: CapturedContent) -> Bool {
        switch (lhs, rhs) {
        case let (.text(a), .text(b)): return a == b
        case let (.link(a), .link(b)): return a == b
        case let (.image(_, a), .image(_, b)): return a == b
        default: return false
        }
    }
}

enum ClipClassifier {
    static func classify(_ pb: PasteboardReading) -> CapturedContent? {
        if let url = pb.fileURL(), isImageFile(url) {
            return .image(NSImage(contentsOf: url), suggestedName: url.lastPathComponent)
        }
        if let img = pb.image() {
            return .image(img, suggestedName: nil)
        }
        if let s = pb.string() {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if let url = asWebURL(trimmed) { return .link(url) }
            return .text(s)
        }
        return nil
    }

    private static func isImageFile(_ url: URL) -> Bool {
        ["png","jpg","jpeg","gif","tiff","heic","webp"].contains(url.pathExtension.lowercased())
    }

    private static func asWebURL(_ s: String) -> URL? {
        guard !s.contains(" "), let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/PasteboardReading.swift
git add StashApp/Sources/StashApp/Clipboard/ClipClassifier.swift
git add StashApp/Tests/StashAppTests/ClipClassifierTests.swift
git commit -m "feat(app): add pasteboard classifier"
```

---

### Task 6: ThumbnailCache

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/ThumbnailCache.swift`
- Test: `StashApp/Tests/StashAppTests/ThumbnailCacheTests.swift`

**Interfaces:**
- Produces:
  - `struct ThumbnailCache: Sendable { let dir: URL; init(dir: URL) }`
  - `func store(_ image: NSImage, id: String) throws -> (fullPath: String, thumbPath: String)` — writes `<id>.png` (full, capped to max 1024px on the long edge) and `<id>_thumb.png` (capped to `Tokens.thumbSize`) into `dir`; returns absolute paths. Returns the thumb path in `preview_path`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import AppKit
import Foundation
@testable import StashApp

@Test func storesThumbAndFull() throws {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cache = ThumbnailCache(dir: tmp)
    let img = NSImage(size: NSSize(width: 400, height: 300))
    img.lockFocus(); NSColor.red.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 400, height: 300)).fill(); img.unlockFocus()

    let paths = try cache.store(img, id: "abc")
    #expect(FileManager.default.fileExists(atPath: paths.fullPath))
    #expect(FileManager.default.fileExists(atPath: paths.thumbPath))

    let thumb = NSImage(contentsOfFile: paths.thumbPath)!
    #expect(thumb.size.width <= 58.5)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `ThumbnailCache` not found.

- [ ] **Step 3: Implement `ThumbnailCache.swift`**

```swift
import AppKit
import Foundation

struct ThumbnailCache: Sendable {
    let dir: URL
    init(dir: URL) { self.dir = dir }

    func store(_ image: NSImage, id: String) throws -> (fullPath: String, thumbPath: String) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let full = dir.appendingPathComponent("\(id).png")
        let thumb = dir.appendingPathComponent("\(id)_thumb.png")
        try png(from: resized(image, maxEdge: 1024)).write(to: full)
        try png(from: resized(image, fitting: Tokens.thumbSize)).write(to: thumb)
        return (full.path, thumb.path)
    }

    private func png(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    private func resized(_ image: NSImage, maxEdge: CGFloat) -> NSImage {
        let s = image.size
        let scale = min(1, maxEdge / max(s.width, s.height))
        return scaled(image, to: NSSize(width: s.width * scale, height: s.height * scale))
    }

    private func resized(_ image: NSImage, fitting box: CGSize) -> NSImage {
        let s = image.size
        let scale = min(box.width / max(s.width, 1), box.height / max(s.height, 1))
        return scaled(image, to: NSSize(width: s.width * scale, height: s.height * scale))
    }

    private func scaled(_ image: NSImage, to size: NSSize) -> NSImage {
        let out = NSImage(size: size)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/ThumbnailCache.swift
git add StashApp/Tests/StashAppTests/ThumbnailCacheTests.swift
git commit -m "feat(app): add thumbnail cache"
```

---

### Task 7: ClipboardStore (insert / dedup / cap / pin)

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/ClipboardStore.swift`
- Test: `StashApp/Tests/StashAppTests/ClipboardStoreTests.swift`

**Interfaces:**
- Consumes: `StashDatabase` (Task 3), `ClipItem` (Task 3).
- Produces:
  - `actor ClipboardStore { init(pool: DatabasePool, cap: Int = 200) }`
  - `func insert(_ item: ClipItem) async throws` — inserts, then trims oldest non-pinned beyond `cap`. Dedup: if the newest row has the same `kind` + `text` + `title`, skip insert.
  - `func setPinned(id: String, pinned: Bool) async throws`
  - `func all() async throws -> [ClipItem]` — ordered `pinned DESC, created_at DESC`.
  - `func newest() async throws -> ClipItem?`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import GRDB
@testable import StashApp

private func mk(_ id: String, _ text: String, pinned: Bool = false, at: Int64) -> ClipItem {
    ClipItem(id: id, kind: .text, text: text, app: nil, pinned: pinned,
             createdAt: at, title: text, previewPath: nil)
}

@Test func insertAndFetch() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "one", at: 1))
    let all = try await store.all()
    #expect(all.count == 1)
    #expect(all.first?.text == "one")
}

@Test func dedupSkipsIdenticalNewest() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "dup", at: 1))
    try await store.insert(mk("b", "dup", at: 2))
    #expect(try await store.all().count == 1)
}

@Test func capTrimsOldestNonPinned() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool, cap: 2)
    try await store.insert(mk("a", "1", at: 1))
    try await store.insert(mk("b", "2", at: 2))
    try await store.insert(mk("c", "3", at: 3))
    let all = try await store.all()
    #expect(all.count == 2)
    #expect(!all.contains { $0.id == "a" })
}

@Test func pinnedSurvivesCap() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool, cap: 1)
    try await store.insert(mk("a", "keep", pinned: true, at: 1))
    try await store.insert(mk("b", "2", at: 2))
    try await store.insert(mk("c", "3", at: 3))
    let all = try await store.all()
    #expect(all.contains { $0.id == "a" })
}

@Test func setPinnedToggles() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    try await store.insert(mk("a", "x", at: 1))
    try await store.setPinned(id: "a", pinned: true)
    #expect(try await store.all().first?.pinned == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `ClipboardStore` not found. (Note: `DatabasePool(path: ":memory:")` is supported by GRDB.)

- [ ] **Step 3: Implement `ClipboardStore.swift`**

```swift
import GRDB

actor ClipboardStore {
    private let pool: DatabasePool
    private let cap: Int

    init(pool: DatabasePool, cap: Int = 200) {
        self.pool = pool
        self.cap = cap
    }

    func newest() throws -> ClipItem? {
        try pool.read { db in
            try ClipItem.order(Column("created_at").desc).fetchOne(db)
        }
    }

    func insert(_ item: ClipItem) throws {
        if let last = try newest(),
           last.kind == item.kind, last.text == item.text, last.title == item.title {
            return
        }
        try pool.write { db in
            try item.insert(db)
            try Self.trim(db, cap: cap)
        }
    }

    func setPinned(id: String, pinned: Bool) throws {
        _ = try pool.write { db in
            try ClipItem.filter(key: id).updateAll(db, Column("pinned").set(to: pinned))
        }
    }

    func all() throws -> [ClipItem] {
        try pool.read { db in
            try ClipItem
                .order(Column("pinned").desc, Column("created_at").desc)
                .fetchAll(db)
        }
    }

    private static func trim(_ db: Database, cap: Int) throws {
        try db.execute(sql: """
            DELETE FROM clipboard
            WHERE pinned = 0 AND id NOT IN (
              SELECT id FROM clipboard WHERE pinned = 0
              ORDER BY created_at DESC LIMIT ?)
            """, arguments: [cap])
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/ClipboardStore.swift
git add StashApp/Tests/StashAppTests/ClipboardStoreTests.swift
git commit -m "feat(app): add ClipboardStore with dedup/cap/pin"
```

---

### Task 8: ClipboardMonitor (pasteboard polling + capture pipeline)

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/SystemPasteboard.swift`
- Create: `StashApp/Sources/StashApp/Clipboard/ClipboardMonitor.swift`
- Test: `StashApp/Tests/StashAppTests/ClipboardMonitorTests.swift`

**Interfaces:**
- Consumes: `PasteboardReading` (Task 5), `ClipClassifier`/`CapturedContent` (Task 5), `ClipboardStore` (Task 7), `ThumbnailCache` (Task 6), `ClipItem`/`ClipKind` (Task 3).
- Produces:
  - `struct SystemPasteboard: PasteboardReading` — wraps `NSPasteboard.general`.
  - `actor ClipboardMonitor` with:
    - `init(store: ClipboardStore, cache: ThumbnailCache, pasteboard: PasteboardReading, now: @Sendable @escaping () -> Int64, makeID: @Sendable @escaping () -> String)`
    - `func capture(frontApp: String?) async -> Bool` — reads pasteboard once; if `changeCount` changed and not self-induced, classifies, builds a `ClipItem`, stores image to cache for `.image`, inserts via store; returns `true` if a row was inserted.
    - `func noteSelfCopy(changeCount: Int)` — records a changeCount to ignore (used by copy-back).
    - `func start()` / `func stop()` — drive a `Task` that calls `capture` every 0.5s using `Timer`-free `Task.sleep`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import GRDB
import AppKit
@testable import StashApp

private final class MutPB: PasteboardReading, @unchecked Sendable {
    var changeCount = 1
    var str: String?
    func string() -> String? { str }
    func image() -> NSImage? { nil }
    func fileURL() -> URL? { nil }
}

@Test func captureInsertsOnNewLink() async throws {
    let db = try StashDatabase(path: ":memory:")
    let store = ClipboardStore(pool: db.pool)
    let pb = MutPB(); pb.str = "https://a.com"
    var t: Int64 = 100
    let mon = ClipboardMonitor(store: store,
                               cache: ThumbnailCache(dir: AppPaths.cacheDir()),
                               pasteboard: pb,
                               now: { t += 1; return t },
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `ClipboardMonitor` / `SystemPasteboard` not found.

- [ ] **Step 3: Implement `SystemPasteboard.swift`**

```swift
import AppKit

struct SystemPasteboard: PasteboardReading {
    // No stored NSPasteboard (it is not Sendable). Access the global accessor per call;
    // the empty struct is then trivially Sendable for the actor to hold.
    var changeCount: Int { NSPasteboard.general.changeCount }
    func string() -> String? { NSPasteboard.general.string(forType: .string) }
    func image() -> NSImage? {
        let pb = NSPasteboard.general
        guard pb.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.tiff.rawValue,
                                                          NSPasteboard.PasteboardType.png.rawValue]) else { return nil }
        return NSImage(pasteboard: pb)
    }
    func fileURL() -> URL? {
        (NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL])?.first { $0.isFileURL }
    }
}
```

- [ ] **Step 4: Implement `ClipboardMonitor.swift`**

```swift
import AppKit

actor ClipboardMonitor {
    private let store: ClipboardStore
    private let cache: ThumbnailCache
    private let pasteboard: PasteboardReading
    private let now: @Sendable () -> Int64
    private let makeID: @Sendable () -> String

    private var lastSeenChangeCount: Int?
    private var ignoreChangeCount: Int?
    private var loop: Task<Void, Never>?

    init(store: ClipboardStore, cache: ThumbnailCache, pasteboard: PasteboardReading,
         now: @Sendable @escaping () -> Int64, makeID: @Sendable @escaping () -> String) {
        self.store = store
        self.cache = cache
        self.pasteboard = pasteboard
        self.now = now
        self.makeID = makeID
    }

    func noteSelfCopy(changeCount: Int) { ignoreChangeCount = changeCount }

    @discardableResult
    func capture(frontApp: String?) async -> Bool {
        let cc = pasteboard.changeCount
        if cc == lastSeenChangeCount { return false }
        lastSeenChangeCount = cc
        if cc == ignoreChangeCount { ignoreChangeCount = nil; return false }
        guard let content = ClipClassifier.classify(pasteboard) else { return false }

        let id = makeID()
        var item = ClipItem(id: id, kind: .text, text: nil, app: frontApp,
                            pinned: false, createdAt: now(), title: nil, previewPath: nil)
        switch content {
        case let .text(s):
            item.kind = .text; item.text = s
            item.title = String(s.split(separator: "\n").first ?? "").prefix(120).description
        case let .link(url):
            item.kind = .link; item.text = url.absoluteString; item.title = url.host
        case let .image(img, name):
            item.kind = .image; item.text = name
            item.title = name ?? "Image"
            if let img, let paths = try? cache.store(img, id: id) {
                item.previewPath = paths.thumbPath
            }
        }
        do { try await store.insert(item); return true } catch { return false }
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let app = await MainActor.run { NSWorkspace.shared.frontmostApplication?.localizedName }
                await self?.capture(frontApp: app)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() { loop?.cancel(); loop = nil }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/SystemPasteboard.swift
git add StashApp/Sources/StashApp/Clipboard/ClipboardMonitor.swift
git add StashApp/Tests/StashAppTests/ClipboardMonitorTests.swift
git commit -m "feat(app): add clipboard monitor with self-copy guard"
```

---

### Task 9: ClipboardViewModel (live observation + actions + search filter)

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/ClipboardViewModel.swift`
- Test: `StashApp/Tests/StashAppTests/ClipboardViewModelTests.swift`

**Interfaces:**
- Consumes: `StashDatabase`, `ClipboardStore`, `ClipboardMonitor`, `ClipItem`.
- Produces:
  - `@MainActor @Observable final class ClipboardViewModel` with `var items: [ClipItem] = []`, `var query: String = ""`.
  - `var pinned: [ClipItem]` and `var recent: [ClipItem]` computed, both filtered by `query` (case-insensitive over `title`+`text`).
  - `init(db: StashDatabase, store: ClipboardStore, monitor: ClipboardMonitor)`.
  - `func startObserving()` — GRDB `ValueObservation` updating `items` on the main actor.
  - `func togglePin(_ item: ClipItem) async`
  - `func copyBack(_ item: ClipItem) async` — writes `item.text` to `NSPasteboard.general`, then `monitor.noteSelfCopy(changeCount:)`.
  - `static func matches(_ item: ClipItem, query: String) -> Bool` (pure, testable).

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `ClipboardViewModel` not found.

- [ ] **Step 3: Implement `ClipboardViewModel.swift`**

```swift
import SwiftUI
import GRDB
import AppKit

@MainActor
@Observable
final class ClipboardViewModel {
    var items: [ClipItem] = []
    var query: String = ""

    private let db: StashDatabase
    private let store: ClipboardStore
    private let monitor: ClipboardMonitor
    private var observationTask: Task<Void, Never>?

    init(db: StashDatabase, store: ClipboardStore, monitor: ClipboardMonitor) {
        self.db = db
        self.store = store
        self.monitor = monitor
    }

    var pinned: [ClipItem] { items.filter { $0.pinned && Self.matches($0, query: query) } }
    var recent: [ClipItem] { items.filter { !$0.pinned && Self.matches($0, query: query) } }

    static func matches(_ item: ClipItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return (item.title?.lowercased().contains(q) ?? false)
            || (item.text?.lowercased().contains(q) ?? false)
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let observation = ValueObservation.tracking { db in
            try ClipItem.order(Column("pinned").desc, Column("created_at").desc).fetchAll(db)
        }
        observationTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await rows in observation.values(in: self.db.pool) {
                    self.items = rows
                }
            } catch { /* observation ended */ }
        }
    }

    func togglePin(_ item: ClipItem) async {
        try? await store.setPinned(id: item.id, pinned: !item.pinned)
    }

    func copyBack(_ item: ClipItem) async {
        let pb = NSPasteboard.general
        pb.clearContents()
        if item.kind == .image, let path = item.previewPath,
           let img = NSImage(contentsOfFile: path) {
            pb.writeObjects([img])
        } else if let text = item.text {
            pb.setString(text, forType: .string)
        }
        await monitor.noteSelfCopy(changeCount: pb.changeCount)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/ClipboardViewModel.swift
git add StashApp/Tests/StashAppTests/ClipboardViewModelTests.swift
git commit -m "feat(app): add clipboard view model with live observation"
```

---

### Task 10: Hub shell UI (panel, tab bar, placeholders, footer)

**Files:**
- Create: `StashApp/Sources/StashApp/Hub/HubTab.swift`
- Create: `StashApp/Sources/StashApp/Hub/HubView.swift`
- Create: `StashApp/Sources/StashApp/Placeholders/ComingSoonView.swift`
- Test: `StashApp/Tests/StashAppTests/HubTabTests.swift`

**Interfaces:**
- Consumes: `Tokens` (Task 2).
- Produces:
  - `enum HubTab: String, CaseIterable, Identifiable { case clipboard, notes, todos, snippets, windows, ai; var id: String { rawValue }; var label: String }`
  - `struct HubView: View` — takes `@Binding var selection: HubTab`, `@Binding var query: String`, and a `@ViewBuilder content:` closure for the active tab body. Renders search field, tab bar, scroll area (`maxHeight: Tokens.contentMaxHeight`), footer.
  - `struct ComingSoonView: View { let tab: HubTab }`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import StashApp

@Test func hubTabHasSixOrderedTabs() {
    #expect(HubTab.allCases.map(\.label) == ["Clipboard","Notes","To-dos","Snippets","Windows","AI"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
Expected: FAIL — `HubTab` not found.

- [ ] **Step 3: Implement `HubTab.swift`**

```swift
enum HubTab: String, CaseIterable, Identifiable {
    case clipboard, notes, todos, snippets, windows, ai
    var id: String { rawValue }
    var label: String {
        switch self {
        case .clipboard: "Clipboard"
        case .notes: "Notes"
        case .todos: "To-dos"
        case .snippets: "Snippets"
        case .windows: "Windows"
        case .ai: "AI"
        }
    }
}
```

- [ ] **Step 4: Implement `ComingSoonView.swift`**

```swift
import SwiftUI

struct ComingSoonView: View {
    let tab: HubTab
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 26))
                .foregroundStyle(Tokens.accent.opacity(0.7))
            Text("\(tab.label) coming soon")
                .font(.system(.callout, design: .rounded).weight(.medium))
                .foregroundStyle(Tokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
```

- [ ] **Step 5: Implement `HubView.swift`**

```swift
import SwiftUI

struct HubView<Content: View>: View {
    @Binding var selection: HubTab
    @Binding var query: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            searchField
            tabBar
            ScrollView { content() }
                .frame(maxHeight: Tokens.contentMaxHeight)
            footer
        }
        .padding(12)
        .frame(width: Tokens.panelWidth)
        .background(Tokens.panelFill)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Tokens.textTertiary)
            TextField("Search", text: $query).textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(HubTab.allCases) { tab in
                Button { selection = tab } label: {
                    Text(tab.label)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.vertical, 5).padding(.horizontal, 9)
                        .foregroundStyle(selection == tab ? Color.white : Tokens.textSecondary)
                        .background(selection == tab ? Tokens.accent : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Preferences…") {}.buttonStyle(.plain)
                .font(.caption).foregroundStyle(Tokens.textTertiary)
        }
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: same as Step 2.
Expected: PASS (1 test).

- [ ] **Step 7: Commit**

```bash
git add StashApp/Sources/StashApp/Hub StashApp/Sources/StashApp/Placeholders
git add StashApp/Tests/StashAppTests/HubTabTests.swift
git commit -m "feat(app): add hub shell with tab bar and placeholders"
```

---

### Task 11: Clipboard tab UI (rows, sections, pin, copy, toast)

**Files:**
- Create: `StashApp/Sources/StashApp/Clipboard/ClipRowView.swift`
- Create: `StashApp/Sources/StashApp/Clipboard/ClipboardTab.swift`

**Interfaces:**
- Consumes: `ClipboardViewModel` (Task 9), `ClipItem`, `Tokens`.
- Produces:
  - `struct ClipRowView: View { let item: ClipItem; let onCopy: () -> Void; let onTogglePin: () -> Void }` — type tile or `58×38` preview, `title` + `relativeTime · app` sub, pin dot (filled `Tokens.accent` when pinned), type badge.
  - `struct ClipboardTab: View { @Bindable var model: ClipboardViewModel }` — `PINNED` section (if any) then `RECENT`; shows a transient "Copied" toast overlay on copy.

(No new unit test — this is view code; verified by running in Task 12. Keep logic in the view model.)

- [ ] **Step 1: Implement `ClipRowView.swift`**

```swift
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.text ?? "Untitled")
                    .lineLimit(1)
                    .font(.system(.callout).weight(.medium))
                    .foregroundStyle(Tokens.textPrimary)
                Text(sub).font(.caption).foregroundStyle(Tokens.textTertiary).lineLimit(1)
            }
            Spacer()
            Button(action: onTogglePin) {
                Circle()
                    .fill(item.pinned ? Tokens.accent : Color.black.opacity(0.18))
                    .frame(width: 8, height: 8)
            }.buttonStyle(.plain)
            Text(item.kind.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Tokens.textTertiary)
        }
        .padding(8)
        .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: Tokens.rowRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
    }

    @ViewBuilder private var preview: some View {
        if item.kind == .image, let path = item.previewPath, let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                .frame(width: Tokens.thumbSize.width, height: Tokens.thumbSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Tokens.accent.opacity(0.12))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: icon).foregroundStyle(Tokens.accent).font(.system(size: 13)))
        }
    }

    private var icon: String {
        switch item.kind { case .text: "doc.text"; case .link: "link"; case .image: "photo" }
    }

    private var sub: String {
        let t = Date(timeIntervalSince1970: TimeInterval(item.createdAt) / 1000)
        let rel = RelativeDateTimeFormatter().localizedString(for: t, relativeTo: Date())
        return [rel, item.app].compactMap { $0 }.joined(separator: " · ")
    }
}
```

- [ ] **Step 2: Implement `ClipboardTab.swift`**

```swift
import SwiftUI

struct ClipboardTab: View {
    @Bindable var model: ClipboardViewModel
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.pinned.isEmpty {
                section("PINNED", model.pinned)
            }
            section("RECENT", model.recent)
            if model.items.isEmpty {
                Text("Nothing copied yet").font(.callout)
                    .foregroundStyle(Tokens.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("Copied to clipboard")
                    .font(.caption).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Tokens.accent, in: Capsule()).foregroundStyle(.white)
                    .padding(.bottom, 8).transition(.opacity)
            }
        }
    }

    private func section(_ title: String, _ rows: [ClipItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(Tokens.textTertiary)
            ForEach(rows) { item in
                ClipRowView(item: item,
                            onCopy: { copy(item) },
                            onTogglePin: { Task { await model.togglePin(item) } })
            }
        }
    }

    private func copy(_ item: ClipItem) {
        Task { await model.copyBack(item) }
        withAnimation { showCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { showCopied = false }
        }
    }
}
```

- [ ] **Step 3: Build to confirm it compiles**

Run: `cd StashApp && xcodebuild -scheme StashApp -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add StashApp/Sources/StashApp/Clipboard/ClipRowView.swift
git add StashApp/Sources/StashApp/Clipboard/ClipboardTab.swift
git commit -m "feat(app): add clipboard tab UI with rows, pin and copy toast"
```

---

### Task 12: Wire it together (AppEnvironment + MenuBarExtra) and run

**Files:**
- Create: `StashApp/Sources/StashApp/App/AppEnvironment.swift`
- Modify: `StashApp/Sources/StashApp/StashApp.swift`

**Interfaces:**
- Consumes: everything above.
- Produces: a running app where copying text/links/images shows them live in the Clipboard tab.

- [ ] **Step 1: Implement `AppEnvironment.swift`**

```swift
import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    let viewModel: ClipboardViewModel
    private let monitor: ClipboardMonitor

    init() {
        let db = (try? StashDatabase(path: AppPaths.dbURL().path))
            ?? (try! StashDatabase(path: ":memory:"))   // non-fatal fallback
        let store = ClipboardStore(pool: db.pool)
        let monitor = ClipboardMonitor(
            store: store,
            cache: ThumbnailCache(dir: AppPaths.cacheDir()),
            pasteboard: SystemPasteboard(),
            now: { Int64(Date().timeIntervalSince1970 * 1000) },
            makeID: { UUID().uuidString })
        self.monitor = monitor
        self.viewModel = ClipboardViewModel(db: db, store: store, monitor: monitor)
    }

    func start() {
        viewModel.startObserving()
        Task { await monitor.start() }
    }
}
```

- [ ] **Step 2: Rewrite `StashApp.swift`**

```swift
import SwiftUI

@main
struct StashApp: App {
    @State private var env = AppEnvironment()
    @State private var selection: HubTab = .clipboard

    var body: some Scene {
        MenuBarExtra("Stash", systemImage: "tray.full") {
            HubView(selection: $selection, query: $env.viewModel.query) {
                switch selection {
                case .clipboard: ClipboardTab(model: env.viewModel)
                default: ComingSoonView(tab: selection)
                }
            }
            .task { env.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Full test suite + build**

Run: `cd StashApp && xcodebuild test -scheme StashApp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
Expected: all tests PASS, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Manual run verification**

Run: `cd StashApp && xcodebuild -scheme StashApp -configuration Debug -derivedDataPath .build build CODE_SIGNING_ALLOWED=NO && open .build/Build/Products/Debug/StashApp.app`
Then: click the menu-bar tray icon → hub opens. Copy some text, a URL, and an image from another app. Verify each appears in RECENT with the right tile/preview, `time · app` sub, and type badge. Click a row → "Copied" toast; paste elsewhere to confirm. Click a pin dot → row moves to PINNED and survives quitting/reopening. Switch tabs → other five show "coming soon".

- [ ] **Step 5: Commit**

```bash
git add StashApp/Sources/StashApp/App StashApp/Sources/StashApp/StashApp.swift
git commit -m "feat(app): wire clipboard pipeline into MenuBarExtra hub"
```

---

## Notes for the implementer

- **GRDB `:memory:` databases:** `DatabasePool(path: ":memory:")` gives a private in-memory DB; each connection in the pool shares it for the process. Used throughout tests for isolation.
- **First launch needs no special permission** — pasteboard reading does not require Accessibility. (Text expansion in a later slice will.)
- **Self-copy guard ordering:** `noteSelfCopy` must be called after writing to the pasteboard (so the recorded `changeCount` matches what the next poll sees).
- **If `xcodebuild test` can't find a destination**, list them with `xcodebuild -showdestinations -scheme StashApp` and use the exact `platform=macOS,arch=arm64` string.
- **Verify the shared DB contract** at the end: run `cd mcp-server && npm run build && node dist/server.js` is not interactive-testable here, but `sqlite3 ~/Library/Application\ Support/Stash/stash.db '.schema clipboard'` should show `title` and `preview_path`.
```
