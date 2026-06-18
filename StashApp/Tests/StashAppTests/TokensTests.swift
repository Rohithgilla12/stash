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
