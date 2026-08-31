import Foundation
import XCTest
@testable import DeskPet

final class WaitingAIContextTests: XCTestCase {
    func testCombinedRiskScoreClampsAndUsesContextDelta() {
        let positive = assessment(delta: 25)
        XCTAssertEqual(positive.combinedRiskScore(baseRiskScore: 60), 85)
        XCTAssertEqual(positive.combinedRiskLevel(baseRiskScore: 60), .critical)

        let upperClamp = assessment(delta: 25)
        XCTAssertEqual(upperClamp.combinedRiskScore(baseRiskScore: 95), 100)

        let negative = assessment(delta: -15)
        XCTAssertEqual(negative.combinedRiskScore(baseRiskScore: 10), 0)
        XCTAssertEqual(negative.combinedRiskLevel(baseRiskScore: 10), .normal)
    }

    func testRuleRiskThresholdsRemainStableForCombinedRecommendation() {
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(24), .normal)
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(25), .watch)
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(49), .watch)
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(50), .followUp)
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(74), .followUp)
        XCTAssertEqual(WaitingRiskLevel.scoreLevel(75), .critical)
    }

    func testGeminiRiskDeltaIsBounded() {
        XCTAssertEqual(GeminiWaitingContextAnalyzer.normalizedRiskDelta(-99), -15)
        XCTAssertEqual(GeminiWaitingContextAnalyzer.normalizedRiskDelta(-4), -4)
        XCTAssertEqual(GeminiWaitingContextAnalyzer.normalizedRiskDelta(12), 12)
        XCTAssertEqual(GeminiWaitingContextAnalyzer.normalizedRiskDelta(99), 25)
    }

    func testFingerprintChangesWhenTaskContextChanges() {
        let first = item(progress: "已送出估價需求", riskScore: 55)
        let second = item(progress: "廠商表示明天回覆", riskScore: 55)
        XCTAssertNotEqual(
            WaitingAIContextAssessment.fingerprint(for: first),
            WaitingAIContextAssessment.fingerprint(for: second)
        )
    }

    private func assessment(delta: Int) -> WaitingAIContextAssessment {
        WaitingAIContextAssessment(
            taskID: "T1",
            sourceFingerprint: "fp",
            contextualRiskDelta: delta,
            blockingImpact: .medium,
            dependencySummary: "測試",
            riskSignals: [],
            rationale: "測試",
            recommendedAction: "測試",
            confidence: 0.8,
            assessedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func item(progress: String, riskScore: Int) -> WaitingItem {
        let task = GASTaskDigest.Task(
            taskId: "T1",
            name: "電梯工程修正估價",
            category: "工程",
            status: "等待他人",
            priority: "高",
            dueDate: "2026-09-10",
            nextAction: "收到估價後簽辦",
            waitingFor: "廠商",
            progress: progress,
            updatedAt: "2026-08-28 09:00:00"
        )
        return WaitingItem(
            task: task,
            waitingTarget: "廠商",
            waitingSince: Date(timeIntervalSince1970: 0),
            waitingDays: 4,
            isHeuristic: false,
            lastFollowUpAt: nil,
            followUpCount: 0,
            recommendedFollowUpAt: nil,
            riskScore: riskScore,
            riskLevel: .followUp,
            interventionRequired: true,
            alertSuppressedUntil: nil
        )
    }
}
