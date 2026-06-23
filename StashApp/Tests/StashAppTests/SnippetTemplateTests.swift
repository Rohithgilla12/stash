import Testing
import Foundation
@testable import StashApp

@Suite struct SnippetTemplateTests {
    private func fixedDate(year: Int = 2025, month: Int = 3, day: Int = 15) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 10
        comps.minute = 30
        return Calendar.current.date(from: comps)!
    }

    @Test func dateRendersNonEmpty() {
        let result = SnippetTemplate.render("{date}", values: [:], clipboard: nil, now: fixedDate())
        #expect(!result.text.isEmpty)
    }

    @Test func datePlusDaysDiffersBy3() throws {
        let now = fixedDate()
        let base = SnippetTemplate.render("{date}", values: [:], clipboard: nil, now: now)
        let shifted = SnippetTemplate.render("{date:+3d}", values: [:], clipboard: nil, now: now)

        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        let baseDate = try #require(f.date(from: base.text))
        let shiftedDate = try #require(f.date(from: shifted.text))

        let diff = shiftedDate.timeIntervalSince(baseDate)
        #expect(abs(diff - 3 * 86400) < 1)
    }

    @Test func dateCustomFormatMatchesRegex() throws {
        let result = SnippetTemplate.render("{date:yyyy-MM-dd}", values: [:], clipboard: nil, now: fixedDate())
        let regex = try Regex(#"\d{4}-\d\d-\d\d"#)
        #expect(result.text.wholeMatch(of: regex) != nil)
    }

    @Test func timeRendersNonEmpty() {
        let result = SnippetTemplate.render("{time}", values: [:], clipboard: nil, now: fixedDate())
        #expect(!result.text.isEmpty)
    }

    @Test func clipboardInterpolated() {
        let result = SnippetTemplate.render("x{clipboard}y", values: [:], clipboard: "AB", now: fixedDate())
        #expect(result.text == "xABy")
        #expect(result.cursorOffset == nil)
    }

    @Test func cursorSetsOffset() {
        let result = SnippetTemplate.render("ab{cursor}cd", values: [:], clipboard: nil, now: fixedDate())
        #expect(result.text == "abcd")
        #expect(result.cursorOffset == 2)
    }

    @Test func fieldsDeduplicatedOrdered() {
        let result = SnippetTemplate.fields(in: "Hi {name}, see {name} at {place:Where?}")
        #expect(result == [
            SnippetField(name: "name", label: "name"),
            SnippetField(name: "place", label: "Where?")
        ])
    }

    @Test func renderFillsFields() {
        let result = SnippetTemplate.render(
            "Hi {name}, see {name} at {place:Where?}",
            values: ["name": "Alice", "place": "noon"],
            clipboard: nil,
            now: fixedDate()
        )
        #expect(result.text == "Hi Alice, see Alice at noon")
        #expect(result.cursorOffset == nil)
    }

    @Test func strayBraceDoesNotCrash() {
        let result = SnippetTemplate.render("100% {x", values: [:], clipboard: nil, now: fixedDate())
        #expect(result.text.contains("100%"))
    }
}
