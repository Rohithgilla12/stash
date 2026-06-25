import Foundation

struct ModelRate: Sendable {
    let input: Double, output: Double, cacheWrite: Double, cacheRead: Double  // USD per 1M tokens
}

enum UsagePricing {
    // Published API rates (USD / 1M tokens). NOTE: update when Anthropic changes pricing.
    static let opus   = ModelRate(input: 15,  output: 75,  cacheWrite: 18.75, cacheRead: 1.50)
    static let sonnet = ModelRate(input: 3,   output: 15,  cacheWrite: 3.75,  cacheRead: 0.30)
    static let haiku  = ModelRate(input: 0.80, output: 4,  cacheWrite: 1.0,   cacheRead: 0.08)

    static func rate(for model: String) -> ModelRate {
        let m = model.lowercased()
        if m.contains("opus")   { return opus }
        if m.contains("haiku")  { return haiku }
        if m.contains("sonnet") { return sonnet }
        return sonnet // sensible fallback for unknown/new models
    }

    static func cost(input: Int, output: Int, cacheWrite: Int, cacheRead: Int, model: String) -> Double {
        let r = rate(for: model)
        let m = 1_000_000.0
        return Double(input)/m*r.input + Double(output)/m*r.output
             + Double(cacheWrite)/m*r.cacheWrite + Double(cacheRead)/m*r.cacheRead
    }
}
