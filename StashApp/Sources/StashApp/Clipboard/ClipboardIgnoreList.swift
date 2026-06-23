import Foundation

enum ClipboardIgnoreList {
    private static let defaultsKey = "clipboardIgnoredBundleIDs"

    static var bundleIDs: [String] {
        UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    static func add(_ id: String) {
        var list = bundleIDs
        guard !list.contains(where: { $0.caseInsensitiveCompare(id) == .orderedSame }) else { return }
        list.append(id)
        UserDefaults.standard.set(list, forKey: defaultsKey)
    }

    static func remove(_ id: String) {
        let list = bundleIDs.filter { $0.caseInsensitiveCompare(id) != .orderedSame }
        UserDefaults.standard.set(list, forKey: defaultsKey)
    }

    static func isIgnored(_ bundleID: String?, in list: [String]) -> Bool {
        guard let bundleID else { return false }
        return list.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
    }
}
