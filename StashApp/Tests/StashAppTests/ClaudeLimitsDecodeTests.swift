import Testing
import Foundation
@testable import StashApp

@Suite struct ClaudeLimitsDecodeTests {

    private let syntheticJSON = """
    {
      "five_hour":        { "utilization": 26.0, "resets_at": "2026-06-25T07:59:59.575993+00:00" },
      "seven_day":        { "utilization": 25.0, "resets_at": "2026-06-29T12:59:59.576015+00:00" },
      "seven_day_sonnet": { "utilization": 8.0,  "resets_at": "2026-06-29T12:59:59.576015+00:00" },
      "seven_day_opus":   null,
      "limits": [],
      "extra_usage": { "is_enabled": false },
      "spend": { "percent": 0 }
    }
    """

    private var now: Date { Date(timeIntervalSince1970: 1_750_000_000) }

    @Test func sessionPercentLeft() throws {
        let data = try #require(syntheticJSON.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        #expect(limits.session?.percentLeft == 74)
    }

    @Test func weeklyPercentLeft() throws {
        let data = try #require(syntheticJSON.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        #expect(limits.weekly?.percentLeft == 75)
    }

    @Test func sonnetPercentLeft() throws {
        let data = try #require(syntheticJSON.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        #expect(limits.sonnet?.percentLeft == 92)
    }

    @Test func opusIsNil() throws {
        let data = try #require(syntheticJSON.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        #expect(limits.opus == nil)
    }

    @Test func sessionResetsAtParsed() throws {
        let data = try #require(syntheticJSON.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)

        #expect(limits.session?.resetsAt != nil)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expected = formatter.date(from: "2026-06-25T07:59:59.575993+00:00")
        #expect(limits.session?.resetsAt == expected)
    }

    @Test func nullUtilizationWindowDecodesToNil() throws {
        let json = """
        {
          "five_hour": { "utilization": null, "resets_at": "2026-06-25T07:59:59+00:00" },
          "seven_day": null,
          "seven_day_sonnet": null,
          "seven_day_opus": null
        }
        """
        let data = try #require(json.data(using: .utf8))
        let limits = try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        #expect(limits.session == nil)
    }

    @Test func malformedJSONThrows() {
        let bad = "not valid json {{{"
        let data = bad.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try ClaudeLimitsClient.decodeLimits(from: data, now: now)
        }
    }
}
