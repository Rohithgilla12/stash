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
