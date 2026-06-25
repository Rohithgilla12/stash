import Testing
@testable import StashApp

@Suite struct UsagePricingTests {
    @Test func opusCostMatchesRates() {
        // opus-4.x rates: in $15, out $75, cacheWrite $18.75, cacheRead $1.50 per 1M
        let c = UsagePricing.cost(input: 1_000_000, output: 1_000_000, cacheWrite: 1_000_000, cacheRead: 1_000_000, model: "claude-opus-4-8")
        #expect(abs(c - (15 + 75 + 18.75 + 1.50)) < 0.001)
    }
    @Test func sonnetCheaperThanOpus() {
        let o = UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "claude-opus-4-8")
        let s = UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "claude-sonnet-4-6")
        #expect(s < o)
    }
    @Test func unknownModelUsesFallbackNotZero() {
        #expect(UsagePricing.cost(input: 1_000_000, output: 0, cacheWrite: 0, cacheRead: 0, model: "mystery") > 0)
    }
}
