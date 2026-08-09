import Foundation

enum DeskPetActionKind: String, Codable, Equatable, CaseIterable {
    case calendarEvent
    case reminder
    case gasTask

    var displayName: String {
        switch self {
        case .calendarEvent:
            return "Apple Calendar"
        case .reminder:
            return "Reminders"
        case .gasTask:
            return "總務工作台"
        }
    }

    var symbolName: String {
        switch self {
        case .calendarEvent:
            return "calendar.badge.checkmark"
        case .reminder:
            return "checkmark.circle.fill"
        case .gasTask:
            return "tray.and.arrow.up.fill"
        }
    }
}

struct ActionReceipt: Codable, Equatable, Identifiable {
    var id: String { "\(kind.rawValue):\(externalIdentifier ?? title):\(createdAt.timeIntervalSince1970)" }
    var kind: DeskPetActionKind
    var externalIdentifier: String?
    var externalURL: String?
    var title: String
    var createdAt: Date

    init(
        kind: DeskPetActionKind,
        externalIdentifier: String?,
        externalURL: String? = nil,
        title: String,
        createdAt: Date
    ) {
        self.kind = kind
        self.externalIdentifier = externalIdentifier
        self.externalURL = externalURL
        self.title = title
        self.createdAt = createdAt
    }
}
