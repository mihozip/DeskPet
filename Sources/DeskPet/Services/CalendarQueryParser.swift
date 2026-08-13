import Foundation

struct CalendarQueryParser {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func parse(_ text: String, referenceDate: Date = Date()) -> CalendarQuery {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let interval = detectInterval(in: normalized, referenceDate: referenceDate)
        let category = detectCategory(in: normalized)
        let location = detectLocation(in: normalized)
        let keywords = extractKeywords(from: normalized, category: category, location: location)
        return CalendarQuery(
            originalText: normalized,
            interval: interval,
            category: category,
            keywords: keywords,
            locationKeyword: location
        )
    }

    private func detectCategory(in text: String) -> CalendarQueryCategory {
        if ["講師", "主講", "授課", "演講", "分享者"].contains(where: text.contains) {
            return .lecturer
        }
        if ["研習", "課程", "工作坊", "增能", "研修"].contains(where: text.contains) {
            return .training
        }
        if ["會議", "開會", "會報"].contains(where: text.contains) {
            return .meeting
        }
        return .general
    }

    private func detectInterval(in text: String, referenceDate: Date) -> DateInterval {
        if text.contains("下個月") || text.contains("下月") {
            let next = calendar.date(byAdding: .month, value: 1, to: referenceDate) ?? referenceDate
            return monthInterval(containing: next)
        }
        if text.contains("本月") || text.contains("這個月") || text.contains("這月") {
            return monthInterval(containing: referenceDate)
        }
        if text.contains("明年") {
            let next = calendar.date(byAdding: .year, value: 1, to: referenceDate) ?? referenceDate
            return yearInterval(containing: next)
        }
        if text.contains("今年") {
            return yearInterval(containing: referenceDate)
        }

        if let month = explicitMonth(in: text) {
            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = month
            components.day = 1
            if let date = calendar.date(from: components) {
                return monthInterval(containing: date)
            }
        }

        return yearInterval(containing: referenceDate)
    }

    private func explicitMonth(in text: String) -> Int? {
        if let regex = try? NSRegularExpression(pattern: #"(?<!\d)(1[0-2]|[1-9])\s*月"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text),
           let month = Int(text[range]) {
            return month
        }

        let chineseMonths: [(String, Int)] = [
            ("十二月", 12), ("十一月", 11), ("十月", 10),
            ("九月", 9), ("八月", 8), ("七月", 7), ("六月", 6),
            ("五月", 5), ("四月", 4), ("三月", 3), ("二月", 2), ("一月", 1)
        ]
        return chineseMonths.first(where: { text.contains($0.0) })?.1
    }

    private func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 31 * 86_400)
    }

    private func yearInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .year, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 366 * 86_400)
    }

    private func detectLocation(in text: String) -> String? {
        let pattern = #"(?:在|位於)\s*([^，,。！？!?\s的]{2,12})(?:的)?(?:行程|研習|課程|會議|活動)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func extractKeywords(from text: String, category: CalendarQueryCategory, location: String?) -> [String] {
        var result = text
        let phrases = [
            "白帥帥", "告訴我", "幫我", "找出", "列出", "查一下", "查詢", "有哪些", "所有", "全部",
            "今年", "明年", "本月", "這個月", "這月", "下個月", "下月", "行程", "活動"
        ]
        for phrase in phrases { result = result.replacingOccurrences(of: phrase, with: " ") }
        result = result.replacingOccurrences(of: #"(?<!\d)(1[0-2]|[1-9])\s*月"#, with: " ", options: .regularExpression)
        for token in ["十二月", "十一月", "十月", "九月", "八月", "七月", "六月", "五月", "四月", "三月", "二月", "一月"] {
            result = result.replacingOccurrences(of: token, with: " ")
        }
        if let location {
            result = result.replacingOccurrences(of: location, with: " ")
            result = result.replacingOccurrences(of: "在", with: " ")
            result = result.replacingOccurrences(of: "的", with: " ")
        }

        let categoryWords: [String]
        switch category {
        case .lecturer:
            categoryWords = ["研習", "講師", "主講", "授課", "演講", "分享者"]
        case .training:
            categoryWords = ["研習", "課程", "工作坊", "增能", "研修"]
        case .meeting:
            categoryWords = ["會議", "開會", "會報"]
        case .general:
            categoryWords = []
        }
        for word in categoryWords { result = result.replacingOccurrences(of: word, with: " ") }

        return result
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }
}
