import EventKit
import Foundation

@MainActor
final class CalendarQueryService {
    enum QueryError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "DeskPet 尚未取得完整行事曆讀取權限"
            }
        }
    }

    private let eventStore: EKEventStore
    private let parser: CalendarQueryParser
    private let matcher: CalendarQueryMatcher

    init(
        eventStore: EKEventStore = EKEventStore(),
        parser: CalendarQueryParser = CalendarQueryParser(),
        matcher: CalendarQueryMatcher = CalendarQueryMatcher()
    ) {
        self.eventStore = eventStore
        self.parser = parser
        self.matcher = matcher
    }

    func requestFullAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            return false
        }
    }

    func query(_ text: String, referenceDate: Date = Date()) async throws -> CalendarQueryResult {
        guard await ensureReadableAccess() else {
            throw QueryError.permissionDenied
        }

        let query = parser.parse(text, referenceDate: referenceDate)
        let predicate = eventStore.predicateForEvents(
            withStart: query.interval.start,
            end: query.interval.end,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)
            .map(summary(from:))
            .filter { matcher.matches($0, query: query) }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }

        return CalendarQueryResult(query: query, events: events)
    }

    private func ensureReadableAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess, .authorized:
                return true
            case .notDetermined, .writeOnly:
                return await requestFullAccess()
            default:
                return false
            }
        } else {
            if status == .authorized { return true }
            if status == .notDetermined { return await requestFullAccess() }
            return false
        }
    }

    private func summary(from event: EKEvent) -> CalendarEventSummary {
        CalendarEventSummary(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "未命名行程",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            notes: event.notes,
            calendarName: event.calendar?.title ?? "行事曆",
            isAllDay: event.isAllDay
        )
    }
}
