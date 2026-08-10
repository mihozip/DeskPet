import Foundation
import XCTest
@testable import DeskPet

@MainActor
private final class FakeTaskUpdater: GASTaskUpdating {
    struct Call: Equatable {
        let taskId: String
        let nextAction: String?
        let progress: String?
    }
    var calls: [Call] = []
    var error: Error?
    var result: GASTaskDigest.Task

    init(result: GASTaskDigest.Task) { self.result = result }

    func updateTask(taskId: String, status: String?, dueDate: String?, dueTime: String?, nextAction: String?, waitingFor: String?, progress: String?, reason: String) async throws -> GASTaskDigest.Task {
        calls.append(Call(taskId: taskId, nextAction: nextAction, progress: progress))
        if let error { throw error }
        return result
    }
}

private enum FakeUpdateError: Error { case failed }

final class NextActionConfirmationTests: XCTestCase {
    func testLocalNaturalLanguageProducesProgressAndNextActionDraft() throws {
        let task = GASTaskDigest.Task(taskId: "T1", name: "冷氣工程", status: "進行中")
        let proposal = try NaturalTaskActionInterpreter().interpret(
            command: "冷氣工程報價拿到了，下一步請校長確認預算。",
            tasks: [task]
        )
        XCTAssertEqual(proposal.action, .updateProgress)
        XCTAssertEqual(proposal.note, "冷氣工程報價拿到了")
        XCTAssertEqual(proposal.nextAction, "校長確認預算。")
    }

    @MainActor func testDraftDoesNotWriteUntilSubmit() {
        let task = makeTask()
        let updater = FakeTaskUpdater(result: task)
        let diary = makeDiary()
        let model = TaskInteractionViewModel(task: task, connector: updater, gasConfiguration: GASTaskConfigurationStore(), workEventStore: diary, onUpdated: {})
        model.choose(.updateProgress)
        model.note = "已取得廠商報價"
        model.nextAction = "請校長確認預算"
        XCTAssertEqual(model.preview?.nextActionAfter, "請校長確認預算")
        XCTAssertTrue(updater.calls.isEmpty)
        XCTAssertTrue(diary.events.isEmpty)
    }

    @MainActor func testConfirmationWritesThenRecordsWorkEvent() async {
        let updated = GASTaskDigest.Task(taskId: "T1", name: "冷氣工程", status: "進行中", nextAction: "請校長確認預算", progress: "已取得廠商報價")
        let updater = FakeTaskUpdater(result: updated)
        let diary = makeDiary()
        let model = TaskInteractionViewModel(task: makeTask(), connector: updater, gasConfiguration: GASTaskConfigurationStore(), workEventStore: diary, onUpdated: {})
        model.choose(.updateProgress)
        model.note = "已取得廠商報價"
        model.nextAction = "請校長確認預算"
        await model.submit()
        XCTAssertEqual(updater.calls, [.init(taskId: "T1", nextAction: "請校長確認預算", progress: "已取得廠商報價")])
        XCTAssertEqual(diary.events.count, 1)
        XCTAssertEqual(diary.events.first?.kind, .taskUpdated)
        XCTAssertTrue(model.didSucceed)
    }

    @MainActor func testFailedUpdateDoesNotLeaveSuccessEvent() async {
        let task = makeTask()
        let updater = FakeTaskUpdater(result: task)
        updater.error = FakeUpdateError.failed
        let diary = makeDiary()
        let model = TaskInteractionViewModel(task: task, connector: updater, gasConfiguration: GASTaskConfigurationStore(), workEventStore: diary, onUpdated: {})
        model.choose(.updateProgress)
        model.nextAction = "請校長確認預算"
        await model.submit()
        XCTAssertTrue(diary.events.isEmpty)
        XCTAssertFalse(model.didSucceed)
    }

    @MainActor private func makeTask() -> GASTaskDigest.Task {
        GASTaskDigest.Task(taskId: "T1", name: "冷氣工程", status: "進行中", nextAction: "取得報價", progress: "詢價中")
    }

    @MainActor private func makeDiary() -> WorkEventStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DeskPetTests-\(UUID().uuidString)", isDirectory: true)
        return WorkEventStore(storageDirectory: directory)
    }
}
