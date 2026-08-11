import Foundation

enum GASTaskMutationKind: String, CaseIterable, Identifiable {
    case complete
    case receivedReply
    case postpone
    case updateProgress
    case followUp
    case changeWaiting
    case clearWaiting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .complete: return "完成"
        case .receivedReply: return "收到回覆"
        case .postpone: return "延期"
        case .updateProgress: return "更新進度"
        case .followUp: return "記錄催辦"
        case .changeWaiting: return "修改等待"
        case .clearWaiting: return "解除等待"
        }
    }

    var systemImage: String {
        switch self {
        case .complete: return "checkmark.circle"
        case .receivedReply: return "arrow.turn.down.left"
        case .postpone: return "calendar.badge.clock"
        case .updateProgress: return "arrow.forward.circle"
        case .followUp: return "bell.badge"
        case .changeWaiting: return "person.crop.circle.badge.clock"
        case .clearWaiting: return "hourglass.badge.minus"
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
    let nextActionBefore: String
    let nextActionAfter: String?
}
