import Foundation

enum TaskQuickParse {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private static let weekdayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// An open task whose due day is strictly before today is overdue.
    static func isOverdue(_ date: Date, done: Bool, now: Date, calendar: Calendar = .current) -> Bool {
        guard !done else { return false }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }

    static func formatDue(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) {
            return "Today \(timeFormatter.string(from: date))"
        }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        if cal.isDate(date, inSameDayAs: tomorrow) {
            return "Tmr \(timeFormatter.string(from: date))"
        }
        let thisWeekEnd = cal.date(byAdding: .day, value: 7, to: now)!
        if date < thisWeekEnd {
            return weekdayTimeFormatter.string(from: date)
        }
        return monthDayFormatter.string(from: date)
    }

    struct Result: Equatable {
        var title: String
        var dueAt: Date?
        var priority: TaskPriority?
        var repeatRule: String?
        var tags: [String] = []
    }

    static func parse(_ raw: String, now: Date, calendar: Calendar = .current) -> Result {
        var tokens = tokenise(raw)

        let priority = extractPriority(&tokens)
        let tags = extractTags(&tokens)
        let repeatRule = extractRepeat(&tokens)
        let (dateResult, timeResult) = extractDateTime(&tokens, now: now, calendar: calendar)

        let title = tokens
            .joined(separator: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let dueAt = resolveDate(
            date: dateResult,
            time: timeResult,
            repeatRule: repeatRule,
            now: now,
            calendar: calendar
        )

        return Result(title: title, dueAt: dueAt, priority: priority, repeatRule: repeatRule, tags: tags)
    }
}

private func tokenise(_ raw: String) -> [String] {
    raw.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
}

private func extractPriority(_ tokens: inout [String]) -> TaskPriority? {
    let candidates: [(String, TaskPriority)] = [
        ("!!!", .high),
        ("!high", .high),
        ("!h", .high),
        ("!!", .med),
        ("!med", .med),
        ("!m", .med),
        ("!low", .low),
        ("!l", .low),
        ("!", .low),
    ]
    for (i, token) in tokens.enumerated() {
        let lower = token.lowercased()
        for (pattern, priority) in candidates {
            if lower == pattern {
                tokens.remove(at: i)
                return priority
            }
        }
    }
    return nil
}

/// Pulls `#tag` tokens out of the input. A bare `#` is ignored; tags are
/// de-duplicated (case-insensitively) while preserving first-seen spelling.
private func extractTags(_ tokens: inout [String]) -> [String] {
    var tags: [String] = []
    var seen = Set<String>()
    var remaining: [String] = []
    for token in tokens {
        if token.hasPrefix("#"), token.count > 1 {
            let tag = String(token.dropFirst())
            let key = tag.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                tags.append(tag)
            }
        } else {
            remaining.append(token)
        }
    }
    tokens = remaining
    return tags
}

private enum DateToken {
    case today
    case tomorrow
    case weekday(Int)
    case inNDays(Int)
    case inNWeeks(Int)
}

private enum TimeToken {
    case hm(Int, Int)
}

private func weekdayNumber(_ name: String) -> Int? {
    let map: [String: Int] = [
        "sun": 1, "sunday": 1,
        "mon": 2, "monday": 2,
        "tue": 3, "tuesday": 3,
        "wed": 4, "wednesday": 4,
        "thu": 5, "thursday": 5,
        "fri": 6, "friday": 6,
        "sat": 7, "saturday": 7,
    ]
    return map[name.lowercased()]
}

private func extractRepeat(_ tokens: inout [String]) -> String? {
    let joined = tokens.joined(separator: " ").lowercased()
    let patterns: [(String, String)] = [
        ("every weekday", "weekdays"),
        ("weekdays", "weekdays"),
        ("every day", "daily"),
        ("daily", "daily"),
        ("every week", "weekly"),
        ("weekly", "weekly"),
        ("every month", "monthly"),
        ("monthly", "monthly"),
        ("every monday", "weekly:mon"),
        ("every tuesday", "weekly:tue"),
        ("every wednesday", "weekly:wed"),
        ("every thursday", "weekly:thu"),
        ("every friday", "weekly:fri"),
        ("every saturday", "weekly:sat"),
        ("every sunday", "weekly:sun"),
    ]
    for (pattern, rule) in patterns {
        if let range = joined.range(of: pattern, options: .caseInsensitive) {
            let rawStart = joined.distance(from: joined.startIndex, to: range.lowerBound)
            let rawEnd = joined.distance(from: joined.startIndex, to: range.upperBound)
            var charCount = 0
            var removeStart: Int? = nil
            var removeEnd: Int? = nil
            for (idx, tok) in tokens.enumerated() {
                let tokEnd = charCount + tok.count
                if removeStart == nil && tokEnd > rawStart { removeStart = idx }
                if tokEnd <= rawEnd { removeEnd = idx }
                charCount += tok.count + 1
            }
            if let s = removeStart, let e = removeEnd, s <= e {
                tokens.removeSubrange(s...e)
            }
            return rule
        }
    }
    return nil
}

private func extractDateTime(_ tokens: inout [String], now: Date, calendar: Calendar) -> (DateToken?, TimeToken?) {
    var dateToken: DateToken? = nil
    var timeToken: TimeToken? = nil
    var removeIndices: [Int] = []
    var i = 0
    while i < tokens.count {
        let lower = tokens[i].lowercased()

        if dateToken == nil {
            if lower == "today" {
                dateToken = .today
                removeIndices.append(i)
                i += 1
                continue
            }
            if lower == "tomorrow" || lower == "tmr" {
                dateToken = .tomorrow
                removeIndices.append(i)
                i += 1
                continue
            }
            if let wd = weekdayNumber(lower) {
                dateToken = .weekday(wd)
                removeIndices.append(i)
                i += 1
                continue
            }
            if lower == "in" && i + 2 < tokens.count {
                let numStr = tokens[i + 1]
                let unit = tokens[i + 2].lowercased()
                if let n = Int(numStr) {
                    if unit == "days" || unit == "day" {
                        dateToken = .inNDays(n)
                        removeIndices.append(contentsOf: [i, i + 1, i + 2])
                        i += 3
                        continue
                    }
                    if unit == "weeks" || unit == "week" {
                        dateToken = .inNWeeks(n)
                        removeIndices.append(contentsOf: [i, i + 1, i + 2])
                        i += 3
                        continue
                    }
                }
            }
        }

        if timeToken == nil {
            if lower == "noon" {
                timeToken = .hm(12, 0)
                removeIndices.append(i)
                i += 1
                continue
            }
            if lower == "midnight" {
                timeToken = .hm(0, 0)
                removeIndices.append(i)
                i += 1
                continue
            }
            if lower == "at" && i + 1 < tokens.count {
                if let t = parseTimeString(tokens[i + 1]) {
                    timeToken = t
                    removeIndices.append(contentsOf: [i, i + 1])
                    i += 2
                    continue
                }
            }
            if let t = parseTimeString(lower) {
                timeToken = t
                removeIndices.append(i)
                i += 1
                continue
            }
        }

        i += 1
    }

    for idx in removeIndices.sorted().reversed() {
        if idx < tokens.count {
            tokens.remove(at: idx)
        }
    }

    return (dateToken, timeToken)
}

private func parseTimeString(_ s: String) -> TimeToken? {
    let lower = s.lowercased()
    let ampm: (String) -> (String, Bool)? = { str in
        if str.hasSuffix("am") { return (String(str.dropLast(2)), false) }
        if str.hasSuffix("pm") { return (String(str.dropLast(2)), true) }
        return nil
    }
    if let (timePart, isPM) = ampm(lower) {
        if timePart.contains(":") {
            let parts = timePart.components(separatedBy: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                var hour = h
                if isPM && hour != 12 { hour += 12 }
                if !isPM && hour == 12 { hour = 0 }
                return .hm(hour, m)
            }
        } else if let h = Int(timePart) {
            var hour = h
            if isPM && hour != 12 { hour += 12 }
            if !isPM && hour == 12 { hour = 0 }
            return .hm(hour, 0)
        }
    }
    if lower.contains(":") {
        let parts = lower.components(separatedBy: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), h >= 0, h < 24, m >= 0, m < 60 {
            return .hm(h, m)
        }
    }
    return nil
}

private func resolveDate(
    date: DateToken?,
    time: TimeToken?,
    repeatRule: String?,
    now: Date,
    calendar: Calendar
) -> Date? {
    guard date != nil || time != nil || repeatRule != nil else { return nil }

    let defaultHour = 9
    let defaultMinute = 0
    let (tHour, tMinute): (Int, Int) = {
        if case let .hm(h, m) = time { return (h, m) }
        return (defaultHour, defaultMinute)
    }()

    func startOfDay(_ d: Date) -> Date {
        calendar.startOfDay(for: d)
    }

    func withTime(_ base: Date, hour: Int, minute: Int) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps) ?? base
    }

    func nextWeekday(_ wd: Int) -> Date {
        let todayWD = calendar.component(.weekday, from: now)
        var daysAhead = wd - todayWD
        if daysAhead <= 0 { daysAhead += 7 }
        return calendar.date(byAdding: .day, value: daysAhead, to: startOfDay(now))!
    }

    if let dateToken = date {
        let baseDay: Date
        switch dateToken {
        case .today:
            baseDay = startOfDay(now)
        case .tomorrow:
            baseDay = startOfDay(calendar.date(byAdding: .day, value: 1, to: now)!)
        case .weekday(let wd):
            baseDay = nextWeekday(wd)
        case .inNDays(let n):
            baseDay = startOfDay(calendar.date(byAdding: .day, value: n, to: now)!)
        case .inNWeeks(let n):
            baseDay = startOfDay(calendar.date(byAdding: .weekOfYear, value: n, to: now)!)
        }
        return withTime(baseDay, hour: tHour, minute: tMinute)
    }

    if let repeatRule = repeatRule, repeatRule.hasPrefix("weekly:") {
        let wdName = String(repeatRule.dropFirst("weekly:".count))
        let wdMap: [String: Int] = [
            "sun": 1, "mon": 2, "tue": 3, "wed": 4,
            "thu": 5, "fri": 6, "sat": 7,
        ]
        if let wd = wdMap[wdName] {
            return withTime(nextWeekday(wd), hour: tHour, minute: tMinute)
        }
        return nil
    }

    if let repeatRule = repeatRule, repeatRule == "weekdays" {
        let todayWD = calendar.component(.weekday, from: now)
        let nextWeekdayDay: Date
        if todayWD >= 2 && todayWD <= 6 {
            let todayResult = withTime(startOfDay(now), hour: tHour, minute: tMinute)
            nextWeekdayDay = todayResult > now ? todayResult : withTime(nextWorkday(from: now, calendar: calendar), hour: tHour, minute: tMinute)
        } else {
            nextWeekdayDay = withTime(nextWorkday(from: now, calendar: calendar), hour: tHour, minute: tMinute)
        }
        return nextWeekdayDay
    }

    if time != nil {
        let todayAtTime = withTime(startOfDay(now), hour: tHour, minute: tMinute)
        if todayAtTime > now {
            return todayAtTime
        }
        return withTime(startOfDay(calendar.date(byAdding: .day, value: 1, to: now)!), hour: tHour, minute: tMinute)
    }

    return nil
}

private func nextWorkday(from date: Date, calendar: Calendar) -> Date {
    var candidate = calendar.date(byAdding: .day, value: 1, to: date)!
    while true {
        let wd = calendar.component(.weekday, from: candidate)
        if wd >= 2 && wd <= 6 { return calendar.startOfDay(for: candidate) }
        candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
    }
}
