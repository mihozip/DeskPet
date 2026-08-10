import Foundation
import XCTest
@testable import DeskPet

final class DailyWorkServiceTests: XCTestCase {
    private let service = DailyWorkService()

    func testTodayBriefPriorityOrderAndDeterministicTieBreakers() {
        let now = date("2026-08-10 10:00:00")
        let tasks = [
            task("normal", updatedAt: "2026-08-01 09:00:00"),
            task("waiting", status: "等待他人", updatedAt: "2026-08-02 09:00:00"),
            task("high-b", priority: "高", updatedAt: "2026-08-04 09:00:00"),
            task("today", dueDate: "2026-08-10", updatedAt: "2026-08-05 09:00:00"),
            task("overdue", dueDate: "2026-08-09", updatedAt: "2026-08-06 09:00:00"),
            task("high-a", priority: "高", updatedAt: "2026-08-03 09:00:00")
        ]
        let sorted = service.sortedCandidates(from: tasks, now: now)
        XCTAssertEqual(sorted.map(\.task.taskId), ["overdue", "today", "high-a", "high-b", "waiting", "normal"])
        XCTAssertEqual(service.sortedCandidates(from: Array(tasks.reversed()), now: now), sorted)
    }

    func testTodayBriefCapsSuggestionsAndCountsPendingInbox() {
        let now = date("2026-08-10 10:00:00")
        let tasks = (1...7).map { task("T\($0)") }
        let inbox = [CaptureItem(text: "待整理"), CaptureItem(text: "已完成", status: .done)]
        let brief = service.snapshot(tasks: tasks, inboxItems: inbox, events: [], now: now).todayBrief
        XCTAssertEqual(brief.suggestions.count, 5)
        XCTAssertEqual(brief.pendingInboxCount, 1)
    }

    func testWaitingRadarRejectsEmptyNonWaitingAndCalculatesAge() {
        let now = date("2026-08-10 12:00:00")
        let tasks = [
            task("ignored", status: "進行中", waitingFor: "", updatedAt: "2026-08-01 09:00:00"),
            task("target", waitingFor: "校長", updatedAt: "2026-08-06 23:00:00"),
            task("status", status: "等待他人", waitingFor: "", updatedAt: "2026-08-08 09:00:00")
        ]
        let items = service.waitingItems(from: tasks, events: [], now: now)
        XCTAssertEqual(items.map(\.task.taskId), ["target", "status"])
        XCTAssertEqual(items.map(\.waitingDays), [4, 2])
        XCTAssertTrue(items.allSatisfy(\.isHeuristic))
    }

    func testWaitingRadarUsesExplicitWaitingEventBeforeUpdatedAtFallback() {
        let now = date("2026-08-10 12:00:00")
        let waiting = task("T1", waitingFor: "校長", updatedAt: "2026-08-09 09:00:00")
        let enteredWaiting = WorkEvent(timestamp: date("2026-08-04 09:00:00"), kind: .taskUpdated, title: "冷氣工程", detail: "等待 校長", referenceID: "T1")
        let item = service.waitingItems(from: [waiting], events: [enteredWaiting], now: now).first
        XCTAssertEqual(item?.waitingDays, 6)
        XCTAssertEqual(item?.isHeuristic, false)
    }

    func testSnoozeHidesThenExpiryRestoresItem() {
        let now = date("2026-08-10 10:00:00")
        let waiting = task("waiting", waitingFor: "廠商", updatedAt: "2026-08-01 09:00:00")
        let hidden = service.snapshot(tasks: [waiting], inboxItems: [], events: [], snoozedUntil: ["waiting": date("2026-08-10 11:00:00")], now: now)
        XCTAssertTrue(hidden.waitingItems.isEmpty)
        XCTAssertTrue(hidden.todayBrief.suggestions.isEmpty)
        let restored = service.snapshot(tasks: [waiting], inboxItems: [], events: [], snoozedUntil: ["waiting": date("2026-08-10 09:00:00")], now: now)
        XCTAssertEqual(restored.waitingItems.map(\.task.taskId), ["waiting"])
    }

    func testDailyWrapClassifiesEventsAndHonorsTaipeiDateBoundary() {
        let now = date("2026-08-10 09:00:00")
        let events = [
            event(.taskCompleted, "完成", "2026-08-10 00:00:00"),
            event(.taskUpdated, "推進", "2026-08-10 08:00:00"),
            event(.taskUpdated, "轉入等待", "2026-08-10 08:30:00", detail: "等待校長"),
            event(.taskCreated, "新增", "2026-08-10 08:40:00"),
            event(.noteCreated, "捕捉", "2026-08-10 08:50:00"),
            event(.taskCompleted, "昨天", "2026-08-09 23:59:59")
        ]
        let wrap = service.snapshot(tasks: [], inboxItems: [], events: events, now: now).dailyWrap
        XCTAssertEqual(wrap.events.count, 5)
        XCTAssertEqual(wrap.count(.completed), 1)
        XCTAssertEqual(wrap.count(.progressed), 1)
        XCTAssertEqual(wrap.count(.waiting), 1)
        XCTAssertEqual(wrap.count(.created), 1)
        XCTAssertEqual(wrap.count(.captured), 1)
    }

    func testDailyWrapEmptyDayIsStable() {
        let wrap = service.snapshot(tasks: [], inboxItems: [], events: [], now: date("2026-08-10 09:00:00")).dailyWrap
        XCTAssertTrue(wrap.events.isEmpty)
        XCTAssertEqual(wrap.count(.completed), 0)
        XCTAssertTrue(wrap.mainResults.isEmpty)
    }

    func testWeeklyReviewEmptyWeekIsStable() {
        let review = service.snapshot(tasks: [], inboxItems: [], events: [], now: date("2026-08-12 09:00:00")).weeklyReview
        XCTAssertTrue(review.events.isEmpty)
        XCTAssertEqual(review.count(.completed), 0)
        XCTAssertTrue(review.achievements.isEmpty)
    }

    func testWeeklyReviewStartsMondayInTaipeiAndExcludesPreviousSunday() {
        let now = date("2026-08-12 09:00:00")
        let events = [
            event(.taskCompleted, "週日", "2026-08-09 23:59:59"),
            event(.taskCreated, "週一", "2026-08-10 00:00:00"),
            event(.taskUpdated, "週三", "2026-08-12 08:00:00")
        ]
        let review = service.snapshot(tasks: [], inboxItems: [], events: events, now: now).weeklyReview
        XCTAssertEqual(review.events.map(\.title), ["週一", "週三"])
        XCTAssertEqual(review.count(.created), 1)
        XCTAssertEqual(review.count(.progressed), 1)
        XCTAssertEqual(format(review.interval.start), "2026-08-10 00:00:00")
    }

    func testPetWorkStateRules() {
        let now = date("2026-08-10 10:00:00")
        XCTAssertEqual(service.snapshot(tasks: [task("o", dueDate: "2026-08-09")], inboxItems: [], events: [], now: now).petWorkState, .attention)
        XCTAssertEqual(service.snapshot(tasks: [task("d", dueDate: "2026-08-10")], inboxItems: [], events: [], now: now).petWorkState, .attention)
        XCTAssertEqual(service.snapshot(tasks: [task("w", waitingFor: "廠商", updatedAt: "2026-08-01 09:00:00")], inboxItems: [], events: [], now: now).petWorkState, .waiting)
        let completed = [event(.taskCompleted, "完成", "2026-08-10 09:00:00")]
        XCTAssertEqual(service.snapshot(tasks: [task("n")], inboxItems: [], events: completed, now: now).petWorkState, .success)
        XCTAssertEqual(service.snapshot(tasks: [task("n")], inboxItems: [], events: [], now: now).petWorkState, .normal)
        XCTAssertEqual(service.snapshot(tasks: [], inboxItems: [], events: [], now: now).petWorkState, .idle)
        XCTAssertEqual(service.snapshot(tasks: [], inboxItems: [], events: [], now: date("2026-08-10 22:00:00")).petWorkState, .sleep)
    }

    private func task(_ id: String, status: String = "進行中", priority: String = "中", dueDate: String? = nil, waitingFor: String? = nil, updatedAt: String? = nil) -> GASTaskDigest.Task {
        GASTaskDigest.Task(taskId: id, name: id, status: status, priority: priority, dueDate: dueDate, waitingFor: waitingFor, updatedAt: updatedAt)
    }

    private func event(_ kind: WorkEventKind, _ title: String, _ timestamp: String, detail: String? = nil) -> WorkEvent {
        WorkEvent(timestamp: date(timestamp), kind: kind, title: title, detail: detail)
    }

    private func date(_ value: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: value)!
    }

    private func format(_ value: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: value)
    }
}
