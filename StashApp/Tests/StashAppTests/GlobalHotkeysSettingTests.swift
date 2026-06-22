import Testing
import Foundation
@testable import StashApp

@Test func globalHotkeysDefaultsToTrue() {
    let suite = UserDefaults(suiteName: "GlobalHotkeysSettingTests-\(UUID().uuidString)")!
    let value = suite.object(forKey: "globalHotkeysEnabled") as? Bool ?? true
    #expect(value == true)
}

@Test func globalHotkeysPersistedFalseIsReadBack() {
    let suiteName = "GlobalHotkeysSettingTests-\(UUID().uuidString)"
    let suite = UserDefaults(suiteName: suiteName)!
    suite.set(false, forKey: "globalHotkeysEnabled")
    let value = suite.object(forKey: "globalHotkeysEnabled") as? Bool ?? true
    #expect(value == false)
}
