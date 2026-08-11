import Foundation

enum DailyWorkPriorityTier: Int, CaseIterable, Comparable {
    case overdue
    case dueToday
    case highPriority
    case waiting
    case normal

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
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
    let pendingInboxCount: Int
    let suggestions: [NextActionCandidate]
}

struct WaitingItem: Identifiable, Equatable {
    let task: GASTaskDigest.Task
    let waitingTarget: String
    let waitingSince: Date?
    let waitingDays: Int
    let isHeuristic: Bool

    var id: String { task.taskId }
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
    let dailyWrap: DailyWrap
    let weeklyReview: WeeklyReview
    let petWorkState: PetWorkState
}
