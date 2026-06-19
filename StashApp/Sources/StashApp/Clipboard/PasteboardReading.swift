import AppKit

protocol PasteboardReading: Sendable {
    var changeCount: Int { get }
    func string() -> String?
    func image() -> NSImage?
    func fileURL() -> URL?
    func isConcealed() -> Bool
}
