import Foundation

enum GASTaskMutationKind: String, CaseIterable, Identifiable {
    case complete
    case receivedReply
    case postpone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .complete: return "完成"
        case .receivedReply: return "收到回覆"
        case .postpone: return "延期"
        }
    }

    var systemImage: String {
        switch self {
        case .complete: return "checkmark.circle"
        case .receivedReply: return "arrow.turn.down.left"
        case .postpone: return "calendar.badge.clock"
        }
    }
}

struct GASTaskMutationPreview: Equatable {
    let taskId: String
    let action: GASTaskMutationKind
    let statusBefore: String
    let statusAfter: String?
    let dueDateBefore: String
    let dueDateAfter: String?
    let dueTimeBefore: String
    let dueTimeAfter: String?
    let waitingForBefore: String
    let waitingForAfter: String?
    let progressBefore: String
    let progressAfter: String?
}
