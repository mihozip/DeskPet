import Foundation

enum DuplicateCandidateSource: String {
    case inbox
    case gas

    var displayName: String {
        switch self {
        case .inbox: return "DeskPet Inbox"
        case .gas: return "總務工作台"
        }
    }
}

struct DuplicateCandidate: Identifiable {
    let id: String
    let source: DuplicateCandidateSource
    let title: String
    let detail: String?
    let similarity: Double
    let inboxItemID: UUID?
    let task: GASTaskDigest.Task?

    var similarityLabel: String {
        "\(Int((similarity * 100).rounded()))%"
    }

    var taskID: String? { task?.taskId }

    var statusText: String? {
        switch source {
        case .inbox:
            return "尚在 Inbox"
        case .gas:
            return task?.status
        }
    }
}
