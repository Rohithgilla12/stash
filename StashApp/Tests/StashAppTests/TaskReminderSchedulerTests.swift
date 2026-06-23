import Testing
import Foundation
@testable import StashApp

private let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
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

private func makeTask(done: Bool = false, dueAt: Int64? = nil) -> TaskItem {
    TaskItem(
        id: UUID().uuidString,
        title: "Test task",
        done: done,
        priority: nil,
        due: nil,
        dueAt: dueAt,
        project: "",
        tags: [],
        repeatRule: nil,
        subs: [],
        source: .you,
        createdAt: 0,
        updatedAt: 0
    )
}

@Suite("TaskReminderScheduler pure helpers")
struct TaskReminderSchedulerTests {

    @Test func shouldSchedule_doneTask_returnsFalse() {
        let now = makeUTCDate(year: 2024, month: 6, day: 1, hour: 9)
        let future = Int64(makeUTCDate(year: 2024, month: 6, day: 2, hour: 9).timeIntervalSince1970 * 1000)
        let task = makeTask(done: true, dueAt: future)
        #expect(TaskReminderScheduler.shouldSchedule(task, now: now) == false)
    }

    @Test func shouldSchedule_noDueAt_returnsFalse() {
        let now = makeUTCDate(year: 2024, month: 6, day: 1, hour: 9)
        let task = makeTask(done: false, dueAt: nil)
        #expect(TaskReminderScheduler.shouldSchedule(task, now: now) == false)
    }

    @Test func shouldSchedule_pastDueAt_returnsFalse() {
        let now = makeUTCDate(year: 2024, month: 6, day: 2, hour: 9)
        let past = Int64(makeUTCDate(year: 2024, month: 6, day: 1, hour: 9).timeIntervalSince1970 * 1000)
        let task = makeTask(done: false, dueAt: past)
        #expect(TaskReminderScheduler.shouldSchedule(task, now: now) == false)
    }

    @Test func shouldSchedule_futureDueAt_returnsTrue() {
        let now = makeUTCDate(year: 2024, month: 6, day: 1, hour: 9)
        let future = Int64(makeUTCDate(year: 2024, month: 6, day: 2, hour: 15).timeIntervalSince1970 * 1000)
        let task = makeTask(done: false, dueAt: future)
        #expect(TaskReminderScheduler.shouldSchedule(task, now: now) == true)
    }

    @Test func dueComponents_picksCorrectYearMonthDayHourMinute() {
        let date = makeUTCDate(year: 2025, month: 3, day: 14, hour: 10, minute: 30)
        let dueAt = Int64(date.timeIntervalSince1970 * 1000)
        let comps = TaskReminderScheduler.dueComponents(for: dueAt, calendar: utcCalendar)
        #expect(comps.year == 2025)
        #expect(comps.month == 3)
        #expect(comps.day == 14)
        #expect(comps.hour == 10)
        #expect(comps.minute == 30)
    }

    @Test func dueComponents_doesNotIncludeSeconds() {
        let date = makeUTCDate(year: 2025, month: 1, day: 1, hour: 8, minute: 0)
        let dueAt = Int64(date.timeIntervalSince1970 * 1000)
        let comps = TaskReminderScheduler.dueComponents(for: dueAt, calendar: utcCalendar)
        #expect(comps.second == nil)
    }
}
