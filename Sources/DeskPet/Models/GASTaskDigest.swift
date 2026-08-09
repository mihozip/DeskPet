import Foundation

struct GASTaskDigest: Equatable {
    struct Summary: Decodable, Equatable {
        let active: Int
        let dueToday: Int
        let overdue: Int
        let urgent: Int
        let waiting: Int
    }

    struct Task: Decodable, Equatable, Identifiable {
        let taskId: String
        let name: String
        let category: String?
        let status: String?
        let priority: String?
        let dueDate: String?
        let dueTime: String?
        let nextAction: String?
        let waitingFor: String?
        let progress: String?
        let detailUrl: String?
        let flags: [String]?

        var id: String { taskId }

        var isOverdue: Bool { flags?.contains("overdue") == true }
        var isDueToday: Bool { flags?.contains("dueToday") == true }
        var isUrgent: Bool { flags?.contains("urgent") == true }
        var isWaiting: Bool { flags?.contains("waiting") == true }

        var deadlineText: String? {
            let date = dueDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let time = dueTime?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if date.isEmpty && time.isEmpty { return nil }
            if date.isEmpty { return time }
            if time.isEmpty { return date }
            return "\(date) \(time)"
        }
    }

    let summary: Summary
    let tasks: [Task]
    let serverTime: String?
}
