import Foundation

struct CalendarQueryMatcher {
    func matches(_ event: CalendarEventSummary, query: CalendarQuery) -> Bool {
        let searchable = [event.title, event.location ?? "", event.notes ?? "", event.calendarName]
            .joined(separator: " ")
            .lowercased()

        if let location = query.locationKeyword?.lowercased(), !searchable.contains(location) {
            return false
        }

        if !query.keywords.isEmpty {
            let keywordMatch = query.keywords.allSatisfy { searchable.contains($0.lowercased()) }
            if !keywordMatch { return false }
        }

        switch query.category {
        case .lecturer:
            return lecturerScore(for: searchable) >= 2 && !containsAny(searchable, ["參加", "報名", "學員", "受訓"])
        case .training:
            return containsAny(searchable, ["研習", "課程", "工作坊", "增能", "研修"])
        case .meeting:
            return containsAny(searchable, ["會議", "開會", "會報"])
        case .general:
            return query.keywords.isEmpty || query.keywords.allSatisfy { searchable.contains($0.lowercased()) }
        }
    }

    private func lecturerScore(for searchable: String) -> Int {
        var score = 0
        if containsAny(searchable, ["講師", "主講", "授課", "演講", "分享者"]) { score += 2 }
        if containsAny(searchable, ["研習", "課程", "工作坊", "講座", "增能", "研修"]) { score += 1 }
        return score
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains(where: text.contains)
    }
}
