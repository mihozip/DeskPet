import Combine
import Foundation

@MainActor
final class WaitingAIContextStore: ObservableObject {
    @Published private(set) var assessments: [String: WaitingAIContextAssessment] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var inFlightTaskIDs: Set<String> = []
    @Published private(set) var isBatchAnalyzing = false

    private let analyzer: GeminiWaitingContextAnalyzer

    init(configuration: AIConfigurationStore, session: URLSession = .shared) {
        analyzer = GeminiWaitingContextAnalyzer(configuration: configuration, session: session)
    }

    func assessment(for item: WaitingItem) -> WaitingAIContextAssessment? {
        guard let value = assessments[item.task.taskId],
              value.sourceFingerprint == WaitingAIContextAssessment.fingerprint(for: item) else {
            return nil
        }
        return value
    }

    func error(for taskID: String) -> String? {
        errors[taskID]
    }

    func isAnalyzing(taskID: String) -> Bool {
        inFlightTaskIDs.contains(taskID)
    }

    func analyze(item: WaitingItem, peerTasks: [GASTaskDigest.Task]) async {
        let taskID = item.task.taskId
        guard !inFlightTaskIDs.contains(taskID) else { return }
        inFlightTaskIDs.insert(taskID)
        errors[taskID] = nil
        defer { inFlightTaskIDs.remove(taskID) }

        do {
            let result = try await analyzer.analyze(item: item, peerTasks: peerTasks)
            assessments[taskID] = result
        } catch {
            errors[taskID] = error.localizedDescription
        }
    }

    func analyzePriority(
        items: [WaitingItem],
        peerTasks: [GASTaskDigest.Task],
        limit: Int = 3
    ) async {
        guard !isBatchAnalyzing else { return }
        isBatchAnalyzing = true
        defer { isBatchAnalyzing = false }

        let candidates = items
            .filter { !$0.isAlertSuppressed }
            .sorted {
                if $0.interventionRequired != $1.interventionRequired { return $0.interventionRequired && !$1.interventionRequired }
                if $0.riskScore != $1.riskScore { return $0.riskScore > $1.riskScore }
                if $0.waitingDays != $1.waitingDays { return $0.waitingDays > $1.waitingDays }
                return $0.task.taskId < $1.task.taskId
            }
            .prefix(max(1, limit))

        for item in candidates {
            await analyze(item: item, peerTasks: peerTasks)
        }
    }

    func clear(taskID: String) {
        assessments.removeValue(forKey: taskID)
        errors.removeValue(forKey: taskID)
    }

    func clearAll() {
        assessments.removeAll()
        errors.removeAll()
    }
}
