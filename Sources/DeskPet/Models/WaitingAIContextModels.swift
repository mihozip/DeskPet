import Foundation

enum WaitingBlockingImpact: String, Codable, CaseIterable, Equatable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: return "低阻塞"
        case .medium: return "中阻塞"
        case .high: return "高阻塞"
        }
    }
}

struct WaitingAIContextAssessment: Identifiable, Equatable {
    let taskID: String
    let sourceFingerprint: String
    let contextualRiskDelta: Int
    let blockingImpact: WaitingBlockingImpact
    let dependencySummary: String
    let riskSignals: [String]
    let rationale: String
    let recommendedAction: String
    let confidence: Double
    let assessedAt: Date

    var id: String { taskID }

    func combinedRiskScore(baseRiskScore: Int) -> Int {
        min(100, max(0, baseRiskScore + contextualRiskDelta))
    }

    func combinedRiskLevel(baseRiskScore: Int) -> WaitingRiskLevel {
        WaitingRiskLevel.scoreLevel(combinedRiskScore(baseRiskScore: baseRiskScore))
    }

    static func fingerprint(for item: WaitingItem) -> String {
        let task = item.task
        return [
            task.taskId,
            task.name,
            task.category ?? "",
            task.status ?? "",
            task.priority ?? "",
            task.dueDate ?? "",
            task.dueTime ?? "",
            task.nextAction ?? "",
            task.waitingFor ?? "",
            task.progress ?? "",
            task.updatedAt ?? "",
            String(item.waitingDays),
            String(item.followUpCount),
            String(item.riskScore)
        ].joined(separator: "|")
    }
}

extension WaitingRiskLevel {
    static func scoreLevel(_ score: Int) -> WaitingRiskLevel {
        switch min(100, max(0, score)) {
        case 75...: return .critical
        case 50..<75: return .followUp
        case 25..<50: return .watch
        default: return .normal
        }
    }
}
