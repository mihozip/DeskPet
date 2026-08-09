import Foundation

enum WorkEventKind: String, Codable, CaseIterable {
    case noteCreated
    case taskCreated
    case taskCompleted
    case taskUpdated
    case taskLinked
    case receivedReply
    case postponed
    case calendarCreated
    case reminderCreated
    case manualDiaryNote

    var displayName: String {
        switch self {
        case .noteCreated: return "快速記事"
        case .taskCreated: return "建立任務"
        case .taskCompleted: return "完成任務"
        case .taskUpdated: return "更新任務"
        case .taskLinked: return "合併既有任務"
        case .receivedReply: return "收到回覆"
        case .postponed: return "延期"
        case .calendarCreated: return "建立行程"
        case .reminderCreated: return "建立提醒"
        case .manualDiaryNote: return "日誌補充"
        }
    }

    var systemImage: String {
        switch self {
        case .noteCreated: return "note.text"
        case .taskCreated: return "plus.circle"
        case .taskCompleted: return "checkmark.circle.fill"
        case .taskUpdated: return "arrow.triangle.2.circlepath"
        case .taskLinked: return "link.circle.fill"
        case .receivedReply: return "arrow.turn.down.left"
        case .postponed: return "calendar.badge.clock"
        case .calendarCreated: return "calendar.badge.checkmark"
        case .reminderCreated: return "checklist"
        case .manualDiaryNote: return "book.closed"
        }
    }

    var diarySection: WorkDiarySection {
        switch self {
        case .taskCompleted:
            return .completed
        case .taskCreated, .taskUpdated, .taskLinked, .receivedReply, .postponed, .calendarCreated, .reminderCreated:
            return .progress
        case .noteCreated, .manualDiaryNote:
            return .notes
        }
    }
}

enum WorkEventSource: String, Codable {
    case deskPet
    case gas
    case calendar
    case reminders
    case manual

    var displayName: String {
        switch self {
        case .deskPet: return "DeskPet"
        case .gas: return "總務工作台"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .manual: return "手動補充"
        }
    }
}

enum WorkDiarySection: String, CaseIterable {
    case completed
    case progress
    case notes

    var title: String {
        switch self {
        case .completed: return "今日完成"
        case .progress: return "今日進展"
        case .notes: return "今日紀錄"
        }
    }
}

struct WorkEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var timestamp: Date
    var kind: WorkEventKind
    var title: String
    var detail: String?
    var source: WorkEventSource
    var referenceID: String?
    var category: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: WorkEventKind,
        title: String,
        detail: String? = nil,
        source: WorkEventSource = .deskPet,
        referenceID: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.title = title
        self.detail = detail
        self.source = source
        self.referenceID = referenceID
        self.category = category
    }
}
