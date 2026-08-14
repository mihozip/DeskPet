import EventKit
import Foundation

@MainActor
final class CalendarQueryService {
    enum QueryError: LocalizedError {
        case permissionNotDetermined
        case permissionDenied
        case permissionRestricted
        case writeOnlyAccess

        var errorDescription: String? {
            switch self {
            case .permissionNotDetermined:
                return "請先到「設定 → 整合」授權行事曆完整存取，再進行查詢。"
            case .permissionDenied:
                return "行事曆權限已被拒絕，請到「系統設定 → 隱私權與安全性 → 行事曆」開啟 DeskPet。"
            case .permissionRestricted:
                return "此 Mac 目前限制行事曆存取，DeskPet 無法讀取行程。"
            case .writeOnlyAccess:
                return "DeskPet 目前只有新增行程權限；查詢既有行程需要完整存取。請到「設定 → 整合」升級權限。"
            }
        }
    }

    private let parser: CalendarQueryParser
    private let matcher: CalendarQueryMatcher

    init(
        parser: CalendarQueryParser = CalendarQueryParser(),
        matcher: CalendarQueryMatcher = CalendarQueryMatcher()
    ) {
        self.parser = parser
        self.matcher = matcher
    }

    func query(_ text: String, referenceDate: Date = Date()) async throws -> CalendarQueryResult {
        try requireReadableAccess()

        // Create the store only after authorization is known to be readable.
        // This avoids keeping a pre-authorization EKEventStore around with stale
        // source/cache state and keeps permission prompting in one place: Settings.
        let eventStore = EKEventStore()
        let query = parser.parse(text, referenceDate: referenceDate)
        let predicate = eventStore.predicateForEvents(
            withStart: query.interval.start,
            end: query.interval.end,
            calendars: nil
        )
        let events = eventStore.events(matching: predicate)
            .map { summary(from: $0) }
            .filter { matcher.matches($0, query: query) }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }

        return CalendarQueryResult(query: query, events: events)
    }

    private func requireReadableAccess() throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess:
                return
            case .notDetermined:
                throw QueryError.permissionNotDetermined
            case .writeOnly:
                throw QueryError.writeOnlyAccess
            case .denied:
                throw QueryError.permissionDenied
            case .restricted:
                throw QueryError.permissionRestricted
            case .authorized:
                // Defensive compatibility only. New SDKs report fullAccess or
                // writeOnly on macOS 14+.
                return
            @unknown default:
                throw QueryError.permissionDenied
            }
        }

        switch status {
        case .authorized:
            return
        case .notDetermined:
            throw QueryError.permissionNotDetermined
        case .denied:
            throw QueryError.permissionDenied
        case .restricted:
            throw QueryError.permissionRestricted
        default:
            throw QueryError.permissionDenied
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
