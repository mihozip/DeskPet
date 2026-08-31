import Foundation

enum DailyWorkPriorityTier: Int, CaseIterable, Comparable {
    case overdue
    case dueToday
    case highPriority
    case waiting
    case normal

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum WaitingRiskLevel: Int, CaseIterable, Comparable {
    case normal
    case watch
    case followUp
    case critical

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .normal: return "正常等待"
        case .watch: return "建議注意"
        case .followUp: return "建議追蹤"
        case .critical: return "應立即介入"
        }
    }
}

struct NextActionCandidate: Identifiable, Equatable {
    let task: GASTaskDigest.Task
    let tier: DailyWorkPriorityTier

    var id: String { task.taskId }
}

struct TodayBrief: Equatable {
    let date: Date
    let overdueCount: Int
    let dueTodayCount: Int
    let highPriorityCount: Int
    let waitingCount: Int
    let followUpDueCount: Int
    let pendingInboxCount: Int
    let suggestions: [NextActionCandidate]
}

struct WaitingItem: Identifiable, Equatable {
    let task: GASTaskDigest.Task
    let waitingTarget: String
    let waitingSince: Date?
    let waitingDays: Int
    let isHeuristic: Bool
    let lastFollowUpAt: Date?
    let followUpCount: Int
    let recommendedFollowUpAt: Date?
    let riskScore: Int
    let riskLevel: WaitingRiskLevel
    let interventionRequired: Bool
    let alertSuppressedUntil: Date?

    var id: String { task.taskId }
    var isAlertSuppressed: Bool { alertSuppressedUntil != nil }
}

enum DailyWorkEventCategory: String, CaseIterable {
    case completed
    case progressed
    case waiting
    case created
    case captured
}

struct DailyWrap: Equatable {
    let date: Date
    let events: [WorkEvent]
    let counts: [DailyWorkEventCategory: Int]
    let mainResults: [String]
    let unfinishedTasks: [GASTaskDigest.Task]
    let tomorrowPriorities: [NextActionCandidate]

    func count(_ category: DailyWorkEventCategory) -> Int { counts[category, default: 0] }
}

struct WeeklyReview: Equatable {
    let interval: DateInterval
    let events: [WorkEvent]
    let counts: [DailyWorkEventCategory: Int]
    let achievements: [String]
    let inProgress: [GASTaskDigest.Task]
    let waitingTooLong: [WaitingItem]
    let waitingAverageDays: Double
    let waitingCriticalCount: Int
    let followUpCount: Int
    let nextWeekPriorities: [NextActionCandidate]

    func count(_ category: DailyWorkEventCategory) -> Int { counts[category, default: 0] }
}

enum PetWorkState: String, Equatable {
    case idle
    case normal
    case attention
    case waiting
    case success
    case sleep
}

struct DailyWorkSnapshot: Equatable {
    let generatedAt: Date
    let todayBrief: TodayBrief
    let waitingItems: [WaitingItem]
    let followUpQueue: [WaitingItem]
    let dailyWrap: DailyWrap
    let weeklyReview: WeeklyReview
    let petWorkState: PetWorkState
}
