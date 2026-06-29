import Testing
import Foundation
@testable import StashApp

private let fixedNow: Date = {
    var comps = DateComponents()
    comps.year = 2024
    comps.month = 1
    comps.day = 10
    comps.hour = 12
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

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = 0
    comps.timeZone = TimeZone(identifier: "UTC")
    return utcCalendar.date(from: comps)!
}

@Test func testPayRentFriHighPriority() {
    let r = TaskQuickParse.parse("pay rent fri 9am !high", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "pay rent")
    #expect(r.priority == .high)
    #expect(r.repeatRule == nil)
    let expected = makeDate(year: 2024, month: 1, day: 12, hour: 9)
    #expect(r.dueAt == expected)
}

@Test func testCallMomTomorrow3pm() {
    let r = TaskQuickParse.parse("call mom tomorrow 3pm", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "call mom")
    #expect(r.repeatRule == nil)
    let expected = makeDate(year: 2024, month: 1, day: 11, hour: 15)
    #expect(r.dueAt == expected)
}

@Test func testStandupEveryWeekday9am() {
    let r = TaskQuickParse.parse("standup every weekday 9am", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "standup")
    #expect(r.repeatRule == "weekdays")
    let expected = makeDate(year: 2024, month: 1, day: 11, hour: 9)
    #expect(r.dueAt == expected)
}

@Test func testReviewDoubleBangMedPriority() {
    let r = TaskQuickParse.parse("review !!", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "review")
    #expect(r.priority == .med)
    #expect(r.dueAt == nil)
}

@Test func testShipIn3Days() {
    let r = TaskQuickParse.parse("ship in 3 days", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "ship")
    let expected = makeDate(year: 2024, month: 1, day: 13, hour: 9)
    #expect(r.dueAt == expected)
}

@Test func testGroceriesNoMetadata() {
    let r = TaskQuickParse.parse("groceries", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "groceries")
    #expect(r.dueAt == nil)
    #expect(r.priority == nil)
    #expect(r.repeatRule == nil)
}

@Test func testTagsAreExtractedAndStrippedFromTitle() {
    let r = TaskQuickParse.parse("pay rent fri 9am !high #home #finance", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "pay rent")
    #expect(r.priority == .high)
    #expect(r.tags == ["home", "finance"])
    let expected = makeDate(year: 2024, month: 1, day: 12, hour: 9)
    #expect(r.dueAt == expected)
}

@Test func testTagsDeduplicateCaseInsensitively() {
    let r = TaskQuickParse.parse("buy milk #Home #home", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "buy milk")
    #expect(r.tags == ["Home"])
}

@Test func testBareHashIsNotATag() {
    let r = TaskQuickParse.parse("review PR #", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "review PR #")
    #expect(r.tags.isEmpty)
}

@Test func testTeamSyncEveryMonday10am() {
    let r = TaskQuickParse.parse("team sync every monday 10am", now: fixedNow, calendar: utcCalendar)
    #expect(r.title == "team sync")
    #expect(r.repeatRule == "weekly:mon")
    let expected = makeDate(year: 2024, month: 1, day: 15, hour: 10)
    #expect(r.dueAt == expected)
}
