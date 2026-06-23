import Testing
import Foundation
@testable import StashApp

private let fixedNow: Date = {
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 1
    comps.day = 10
    comps.hour = 9
    comps.minute = 0
    comps.second = 0
    comps.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: comps)!
}()

private let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = second
    comps.timeZone = TimeZone(identifier: "UTC")
    return utcCalendar.date(from: comps)!
}

// MARK: - next()

@Test func testNextDaily() {
    // Wed 2024-01-10 09:00 + daily → Thu 2024-01-11 09:00
    let result = TaskRecurrence.next(after: fixedNow, rule: "daily", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 11, hour: 9)
    #expect(result == expected)
}

@Test func testNextWeekly() {
    // Wed 2024-01-10 09:00 + weekly → Wed 2024-01-17 09:00
    let result = TaskRecurrence.next(after: fixedNow, rule: "weekly", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 17, hour: 9)
    #expect(result == expected)
}

@Test func testNextWeekdaysFromWed() {
    // Wed 2024-01-10 09:00 + weekdays → Thu 2024-01-11 09:00
    let result = TaskRecurrence.next(after: fixedNow, rule: "weekdays", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 11, hour: 9)
    #expect(result == expected)
}

@Test func testNextWeekdaysFromFri() {
    // Fri 2024-01-12 09:00 + weekdays → Mon 2024-01-15 09:00
    let friday = makeUTCDate(year: 2024, month: 1, day: 12, hour: 9)
    let result = TaskRecurrence.next(after: friday, rule: "weekdays", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 15, hour: 9)
    #expect(result == expected)
}

@Test func testNextMonthly() {
    // Jan 31 2024 09:00 + monthly → Feb 29 2024 09:00 (2024 is a leap year)
    let jan31 = makeUTCDate(year: 2024, month: 1, day: 31, hour: 9)
    let result = TaskRecurrence.next(after: jan31, rule: "monthly", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 2, day: 29, hour: 9)
    #expect(result == expected)
}

@Test func testNextWeeklyMon() {
    // Mon 2024-01-08 09:00 + weekly:mon → Mon 2024-01-15 09:00
    let monday = makeUTCDate(year: 2024, month: 1, day: 8, hour: 9)
    let result = TaskRecurrence.next(after: monday, rule: "weekly:mon", calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 15, hour: 9)
    #expect(result == expected)
}

@Test func testNextUnknownRule() {
    let result = TaskRecurrence.next(after: fixedNow, rule: "bogus", calendar: utcCalendar)
    #expect(result == nil)
}

// MARK: - firstAnchor()

@Test func testFirstAnchorWeekdaysFromSaturday() {
    // Saturday 2024-01-13 12:00 → Monday 2024-01-15 09:00
    let saturday = makeUTCDate(year: 2024, month: 1, day: 13, hour: 12)
    let result = TaskRecurrence.firstAnchor(rule: "weekdays", from: saturday, calendar: utcCalendar)
    let expected = makeUTCDate(year: 2024, month: 1, day: 15, hour: 9)
    #expect(result == expected)
}

// MARK: - humanLabel()

@Test func testHumanLabelDaily() {
    #expect(TaskRecurrence.humanLabel("daily") == "Daily")
}

@Test func testHumanLabelWeekdays() {
    #expect(TaskRecurrence.humanLabel("weekdays") == "Weekdays")
}

@Test func testHumanLabelWeeklyMon() {
    #expect(TaskRecurrence.humanLabel("weekly:mon") == "Mondays")
}

@Test func testHumanLabelMonthly() {
    #expect(TaskRecurrence.humanLabel("monthly") == "Monthly")
}

@Test func testHumanLabelUnknown() {
    #expect(TaskRecurrence.humanLabel("bogus") == "bogus")
}

// MARK: - spawnNext integration

@Test func testSpawnNextProducesAdvancedDueAt() {
    // Wed 2024-01-10 09:00 UTC as epoch-ms
    let wedMs = Int64(fixedNow.timeIntervalSince1970 * 1000)
    let original = TaskItem(
        id: "orig-id",
        title: "Take vitamins",
        done: true,
        priority: .high,
        due: .Today,
        dueAt: wedMs,
        project: "Health",
        tags: ["daily"],
        repeatRule: "daily",
        subs: [],
        source: .you,
        createdAt: wedMs,
        updatedAt: wedMs
    )

    let result = TaskRecurrence.spawnNext(from: original, now: fixedNow, calendar: utcCalendar)

    #expect(result != nil)
    guard let next = result else { return }

    // New id
    #expect(next.id != original.id)

    // Not done
    #expect(next.done == false)

    // dueAt advanced by 1 day = Thu 2024-01-11 09:00
    let thuMs = Int64(makeUTCDate(year: 2024, month: 1, day: 11, hour: 9).timeIntervalSince1970 * 1000)
    #expect(next.dueAt == thuMs)

    // Copied fields
    #expect(next.title == original.title)
    #expect(next.priority == original.priority)
    #expect(next.repeatRule == original.repeatRule)
    #expect(next.project == original.project)
    #expect(next.tags == original.tags)
    #expect(next.source == original.source)

    // Fresh checklist
    #expect(next.subs.isEmpty)
}
