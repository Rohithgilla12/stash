import Foundation

enum TaskRecurrence {

    static func next(after date: Date, rule: String, calendar: Calendar = .current) -> Date? {
        switch rule {
        case "daily":
            return calendar.date(byAdding: .day, value: 1, to: date)

        case "weekly":
            return calendar.date(byAdding: .day, value: 7, to: date)

        case "monthly":
            return calendar.date(byAdding: .month, value: 1, to: date)

        case "weekdays":
            let weekday = calendar.component(.weekday, from: date)
            let daysAhead: Int
            switch weekday {
            case 6: daysAhead = 3  // Friday → Monday
            case 7: daysAhead = 2  // Saturday → Monday
            default: daysAhead = 1 // Mon–Thu → next day
            }
            return calendar.date(byAdding: .day, value: daysAhead, to: date)

        default:
            if rule.hasPrefix("weekly:") {
                let suffix = String(rule.dropFirst(7))
                let wdMap: [String: Int] = [
                    "sun": 1, "mon": 2, "tue": 3, "wed": 4,
                    "thu": 5, "fri": 6, "sat": 7
                ]
                guard let targetWD = wdMap[suffix] else { return nil }
                let currentWD = calendar.component(.weekday, from: date)
                var daysAhead = targetWD - currentWD
                if daysAhead <= 0 { daysAhead += 7 }
                return calendar.date(byAdding: .day, value: daysAhead, to: date)
            }
            return nil
        }
    }

    static func firstAnchor(rule: String, from now: Date, calendar: Calendar = .current) -> Date? {
        func at9(_ base: Date) -> Date? {
            var comps = calendar.dateComponents([.year, .month, .day], from: base)
            comps.hour = 9
            comps.minute = 0
            comps.second = 0
            return calendar.date(from: comps)
        }

        switch rule {
        case "daily":
            if let today9 = at9(now), today9 > now {
                return today9
            }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return at9(tomorrow)

        case "weekly":
            let future = calendar.date(byAdding: .day, value: 7, to: now)!
            return at9(future)

        case "monthly":
            let future = calendar.date(byAdding: .month, value: 1, to: now)!
            return at9(future)

        case "weekdays":
            let weekday = calendar.component(.weekday, from: now)
            let isWorkday = weekday >= 2 && weekday <= 6
            if isWorkday, let today9 = at9(now), today9 > now {
                return today9
            }
            let daysAhead: Int
            switch weekday {
            case 6: daysAhead = 3  // Friday → Monday
            case 7: daysAhead = 2  // Saturday → Monday
            default: daysAhead = 1 // Mon–Thu passed 9am, or Sunday → next workday
            }
            let next = calendar.date(byAdding: .day, value: daysAhead, to: now)!
            return at9(next)

        default:
            if rule.hasPrefix("weekly:") {
                let suffix = String(rule.dropFirst(7))
                let wdMap: [String: Int] = [
                    "sun": 1, "mon": 2, "tue": 3, "wed": 4,
                    "thu": 5, "fri": 6, "sat": 7
                ]
                guard let targetWD = wdMap[suffix] else { return nil }
                let currentWD = calendar.component(.weekday, from: now)
                if currentWD == targetWD, let today9 = at9(now), today9 > now {
                    return today9
                }
                var daysAhead = targetWD - currentWD
                if daysAhead <= 0 { daysAhead += 7 }
                let next = calendar.date(byAdding: .day, value: daysAhead, to: now)!
                return at9(next)
            }
            return nil
        }
    }

    static func humanLabel(_ rule: String) -> String {
        switch rule {
        case "daily":    return "Daily"
        case "weekly":   return "Weekly"
        case "monthly":  return "Monthly"
        case "weekdays": return "Weekdays"
        default:
            if rule.hasPrefix("weekly:") {
                let suffix = String(rule.dropFirst(7))
                let names: [String: String] = [
                    "mon": "Mondays", "tue": "Tuesdays", "wed": "Wednesdays",
                    "thu": "Thursdays", "fri": "Fridays", "sat": "Saturdays", "sun": "Sundays"
                ]
                return names[suffix] ?? rule
            }
            return rule
        }
    }

    static func spawnNext(from task: TaskItem, now: Date, calendar: Calendar = .current) -> TaskItem? {
        guard let repeatRule = task.repeatRule, let dueAtMs = task.dueAt else { return nil }
        let dueDate = Date(timeIntervalSince1970: Double(dueAtMs) / 1000)
        guard let nextDue = next(after: dueDate, rule: repeatRule, calendar: calendar) else { return nil }

        let nextDueMs = Int64(nextDue.timeIntervalSince1970 * 1000)
        let nowMs = Int64(now.timeIntervalSince1970 * 1000)
        let due = derivedue(nextDue, now: now, calendar: calendar)

        return TaskItem(
            id: UUID().uuidString,
            title: task.title,
            done: false,
            priority: task.priority,
            due: due,
            dueAt: nextDueMs,
            project: task.project,
            tags: task.tags,
            repeatRule: repeatRule,
            subs: [],
            source: task.source,
            createdAt: nowMs,
            updatedAt: nowMs
        )
    }

    private static func derivedue(_ date: Date, now: Date, calendar: Calendar) -> TaskDue {
        if calendar.isDate(date, inSameDayAs: now) { return .Today }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        if calendar.isDate(date, inSameDayAs: tomorrow) { return .Tomorrow }
        return .Upcoming
    }
}
