import Foundation

enum WorkContextBucket: String, CaseIterable, Equatable {
    case now
    case next
    case later
}

enum WorkContextItemSource: Equatable {
    case task(GASTaskDigest.Task)
    case calendar(CalendarEventSummary)
    case inbox(CaptureItem)
}

struct WorkContextItem: Identifiable, Equatable {
    let id: String
    let bucket: WorkContextBucket
    let title: String
    let detail: String?
    let source: WorkContextItemSource

    var task: GASTaskDigest.Task? {
        guard case .task(let task) = source else { return nil }
        return task
    }

    var calendarEvent: CalendarEventSummary? {
        guard case .calendar(let event) = source else { return nil }
        return event
    }

    var inboxItem: CaptureItem? {
        guard case .inbox(let item) = source else { return nil }
        return item
    }
}

struct WorkContextSnapshot: Equatable {
    let generatedAt: Date
    let headline: String
    let currentEvent: CalendarEventSummary?
    let nextEvent: CalendarEventSummary?
    let recentActivity: WorkEvent?
    let nowItems: [WorkContextItem]
    let nextItems: [WorkContextItem]
    let laterItems: [WorkContextItem]
}
