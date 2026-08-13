import Foundation

struct CalendarEventSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarName: String
    let isAllDay: Bool
}

enum CalendarQueryCategory: String, Equatable {
    case lecturer
    case training
    case meeting
    case general
}

struct CalendarQuery: Equatable {
    let originalText: String
    let interval: DateInterval
    let category: CalendarQueryCategory
    let keywords: [String]
    let locationKeyword: String?
}

struct CalendarQueryResult: Equatable {
    let query: CalendarQuery
    let events: [CalendarEventSummary]
}
