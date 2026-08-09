import Foundation

/// DeskPet 0.3 deliberately starts with an on-device interpreter.
/// The UI talks to this small service boundary, so a later LLM-backed
/// interpreter can replace it without rewriting Inbox or review windows.
struct LocalIntentInterpreter {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func interpret(text: String, referenceDate: Date = Date()) -> SmartInterpretation {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let detectedDate = detectDate(in: normalized, referenceDate: referenceDate)
        let kind = detectKind(in: normalized, hasDate: detectedDate != nil)
        let title = cleanTitle(normalized)
        let confidence = confidenceFor(kind: kind, text: normalized, hasDate: detectedDate != nil)
        let explanation = explanationFor(kind: kind, text: normalized, date: detectedDate)

        return SmartInterpretation(
            kind: kind,
            title: title.isEmpty ? normalized : title,
            targetDate: detectedDate,
            confidence: confidence,
            explanation: explanation,
            source: .local
        )
    }

    private func detectKind(in text: String, hasDate: Bool) -> CaptureKind {
        let eventKeywords = [
            "會議", "開會", "研習", "活動", "約會", "拜訪", "課程", "上課", "行程", "聚餐", "面談"
        ]
        if eventKeywords.contains(where: text.contains) {
            return .event
        }

        let taskKeywords = [
            "提醒", "記得", "要記得", "待辦", "處理", "完成", "確認", "聯絡", "詢問", "問", "回覆", "查", "繳", "送", "準備"
        ]
        if taskKeywords.contains(where: text.contains) || hasDate {
            return .task
        }

        return .note
    }

    private func detectDate(in text: String, referenceDate: Date) -> Date? {
        let dayBase = detectDayBase(in: text, referenceDate: referenceDate)
            ?? detectExplicitMonthDay(in: text, referenceDate: referenceDate)
            ?? detectWeekday(in: text, referenceDate: referenceDate)

        let time = detectTime(in: text)

        if let dayBase {
            return applying(time: time, to: dayBase)
        }

        if let time {
            let today = calendar.startOfDay(for: referenceDate)
            var candidate = applying(time: time, to: today)
            if candidate <= referenceDate,
               let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) {
                candidate = tomorrow
            }
            return candidate
        }

        return nil
    }

    private func detectDayBase(in text: String, referenceDate: Date) -> Date? {
        let start = calendar.startOfDay(for: referenceDate)
        let offsets: [(String, Int)] = [
            ("大後天", 3),
            ("後天", 2),
            ("明天", 1),
            ("今天", 0)
        ]

        for (token, offset) in offsets where text.contains(token) {
            return calendar.date(byAdding: .day, value: offset, to: start)
        }
        return nil
    }

    private func detectExplicitMonthDay(in text: String, referenceDate: Date) -> Date? {
        let patterns = [
            #"(\d{1,2})\s*月\s*(\d{1,2})\s*日?"#,
            #"(?<!\d)(\d{1,2})\s*[\-/]\s*(\d{1,2})(?!\d)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..<text.endIndex, in: text)
                  ),
                  match.numberOfRanges >= 3,
                  let monthRange = Range(match.range(at: 1), in: text),
                  let dayRange = Range(match.range(at: 2), in: text),
                  let month = Int(text[monthRange]),
                  let day = Int(text[dayRange])
            else {
                continue
            }

            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = month
            components.day = day
            components.hour = 0
            components.minute = 0

            guard var candidate = calendar.date(from: components) else { continue }
            if candidate < calendar.startOfDay(for: referenceDate),
               let nextYear = calendar.date(byAdding: .year, value: 1, to: candidate) {
                candidate = nextYear
            }
            return candidate
        }

        return nil
    }

    private func detectWeekday(in text: String, referenceDate: Date) -> Date? {
        let weekdayMap: [(String, Int)] = [
            ("一", 2), ("二", 3), ("三", 4), ("四", 5), ("五", 6), ("六", 7), ("日", 1), ("天", 1)
        ]

        let prefixes = ["星期", "週", "礼拜", "禮拜"]
        var targetWeekday: Int?
        for prefix in prefixes {
            for (token, weekday) in weekdayMap where text.contains("\(prefix)\(token)") {
                targetWeekday = weekday
                break
            }
            if targetWeekday != nil { break }
        }

        guard let targetWeekday else { return nil }

        let start = calendar.startOfDay(for: referenceDate)
        let currentWeekday = calendar.component(.weekday, from: start)
        let isNextWeek = text.contains("下週")
            || text.contains("下星期")
            || text.contains("下礼拜")
            || text.contains("下禮拜")

        if isNextWeek {
            // Convert Calendar weekday (Sun = 1 ... Sat = 7) to a Monday-first
            // index so "下週一" always means Monday of the next calendar week.
            let currentMondayIndex = (currentWeekday + 5) % 7
            let targetMondayIndex = (targetWeekday + 5) % 7
            let daysUntilNextMonday = currentMondayIndex == 0 ? 7 : 7 - currentMondayIndex
            let delta = daysUntilNextMonday + targetMondayIndex
            return calendar.date(byAdding: .day, value: delta, to: start)
        }

        var delta = (targetWeekday - currentWeekday + 7) % 7
        if delta == 0 {
            delta = 7
        }
        return calendar.date(byAdding: .day, value: delta, to: start)
    }

    private struct TimeParts {
        let hour: Int
        let minute: Int
    }

    private func detectTime(in text: String) -> TimeParts? {
        let periodOffset: Int
        if text.contains("晚上") || text.contains("晚間") || text.contains("下午") {
            periodOffset = 12
        } else {
            periodOffset = 0
        }

        if text.contains("中午") && !containsClockExpression(text) {
            return TimeParts(hour: 12, minute: 0)
        }
        if text.contains("早上") && !containsClockExpression(text) {
            return TimeParts(hour: 8, minute: 0)
        }
        if text.contains("下午") && !containsClockExpression(text) {
            return TimeParts(hour: 15, minute: 0)
        }
        if (text.contains("晚上") || text.contains("晚間")) && !containsClockExpression(text) {
            return TimeParts(hour: 19, minute: 0)
        }

        let colonPattern = #"(?<!\d)(\d{1,2})\s*[:：]\s*(\d{1,2})(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: colonPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let minuteRange = Range(match.range(at: 2), in: text),
           let rawHour = Int(text[hourRange]),
           let minute = Int(text[minuteRange]) {
            return TimeParts(hour: normalizedHour(rawHour, periodOffset: periodOffset), minute: min(max(minute, 0), 59))
        }

        let clockPattern = #"([0-9一二三四五六七八九十兩]{1,3})\s*[點时時]\s*(半|([0-9一二三四五六七八九十兩]{1,3})\s*分?)?"#
        if let regex = try? NSRegularExpression(pattern: clockPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let hourRange = Range(match.range(at: 1), in: text),
           let rawHour = parseChineseOrArabicNumber(String(text[hourRange])) {
            var minute = 0
            if match.range(at: 2).location != NSNotFound,
               let minuteTokenRange = Range(match.range(at: 2), in: text) {
                let minuteToken = String(text[minuteTokenRange])
                if minuteToken.contains("半") {
                    minute = 30
                } else {
                    let digitsOnly = minuteToken.replacingOccurrences(of: "分", with: "")
                    minute = parseChineseOrArabicNumber(digitsOnly) ?? 0
                }
            }
            return TimeParts(hour: normalizedHour(rawHour, periodOffset: periodOffset), minute: min(max(minute, 0), 59))
        }

        return nil
    }

    private func containsClockExpression(_ text: String) -> Bool {
        text.range(of: #"\d{1,2}\s*[:：]\s*\d{1,2}"#, options: .regularExpression) != nil
            || text.range(of: #"[0-9一二三四五六七八九十兩]{1,3}\s*[點时時]"#, options: .regularExpression) != nil
    }

    private func normalizedHour(_ rawHour: Int, periodOffset: Int) -> Int {
        var hour = rawHour
        if periodOffset == 12 && rawHour < 12 {
            hour += 12
        }
        if rawHour == 12 && periodOffset == 0 {
            hour = 12
        }
        return min(max(hour, 0), 23)
    }

    private func applying(time: TimeParts?, to day: Date) -> Date {
        let parts = time ?? TimeParts(hour: 9, minute: 0)
        return calendar.date(
            bySettingHour: parts.hour,
            minute: parts.minute,
            second: 0,
            of: day
        ) ?? day
    }

    private func cleanTitle(_ text: String) -> String {
        var result = text
        let removablePhrases = ["提醒我", "幫我記得", "幫我記一下", "記一下", "記得"]
        for phrase in removablePhrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }

        let patterns = [
            #"今天|明天|後天|大後天"#,
            #"(?:下)?(?:星期|週|礼拜|禮拜)[一二三四五六日天]"#,
            #"\d{1,2}\s*月\s*\d{1,2}\s*日?"#,
            #"(?<!\d)\d{1,2}\s*[\-/]\s*\d{1,2}(?!\d)"#,
            #"(?:早上|上午|中午|下午|晚上|晚間)?\s*\d{1,2}\s*[:：]\s*\d{1,2}"#,
            #"(?:早上|上午|中午|下午|晚上|晚間)?\s*[0-9一二三四五六七八九十兩]{1,3}\s*[點时時](?:\s*(?:半|[0-9一二三四五六七八九十兩]{1,3}\s*分?))?"#,
            #"早上|上午|中午|下午|晚上|晚間"#
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。.!！?？：:")))
    }

    private func confidenceFor(kind: CaptureKind, text: String, hasDate: Bool) -> Double {
        switch kind {
        case .event:
            return hasDate ? 0.92 : 0.78
        case .task:
            return hasDate ? 0.88 : 0.72
        case .note:
            return 0.60
        }
    }

    private func explanationFor(kind: CaptureKind, text: String, date: Date?) -> String {
        var parts = ["判斷為「\(kind.rawValue)」"]
        if let date {
            parts.append("偵測到時間：\(date.formatted(date: .abbreviated, time: .shortened))")
        } else {
            parts.append("未偵測到明確時間")
        }
        return parts.joined(separator: "；")
    }

    private func parseChineseOrArabicNumber(_ token: String) -> Int? {
        if let value = Int(token) {
            return value
        }

        let map: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        if token == "十" { return 10 }
        if token.hasPrefix("十"), token.count == 2,
           let last = token.last, let ones = map[last] {
            return 10 + ones
        }
        if token.hasSuffix("十"), token.count == 2,
           let first = token.first, let tens = map[first] {
            return tens * 10
        }
        if token.contains("十") {
            let pieces = token.split(separator: "十", omittingEmptySubsequences: false)
            let tens = pieces.first?.first.flatMap { map[$0] } ?? 1
            let ones = pieces.count > 1 ? (pieces[1].first.flatMap { map[$0] } ?? 0) : 0
            return tens * 10 + ones
        }
        if token.count == 1, let first = token.first {
            return map[first]
        }
        return nil
    }
}
