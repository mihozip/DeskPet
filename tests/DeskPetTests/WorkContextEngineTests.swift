import Foundation
import XCTest
@testable import DeskPet

final class WorkContextEngineTests: XCTestCase {
    private let engine = WorkContextEngine()

    func testUrgentTaskGoesNowAndWaitingTaskGoesLater() {
        let now = date("2026-08-18 10:00:00")
        let tasks = [
            task("urgent", name: "處理採購公告", priority: "高"),
            task("waiting", name: "等廠商估價", status: "等待他人", waitingFor: "廠商")
        ]

        let snapshot = engine.snapshot(
            tasks: tasks,
            inboxItems: [],
            workEvents: [],
            calendarEvents: [],
            now: now
        )

        XCTAssertEqual(snapshot.nowItems.compactMap { $0.task?.taskId }, ["urgent"])
        XCTAssertTrue(snapshot.laterItems.compactMap { $0.task?.taskId }.contains("waiting"))
        XCTAssertEqual(snapshot.headline, "現在最值得處理：處理採購公告")
    }

    func testCurrentAndUpcomingCalendarEventsJoinContext() {
        let now = date("2026-08-18 10:00:00")
        let current = event("current", "行政會議", "2026-08-18 09:30:00", "2026-08-18 10:30:00")
        let upcoming = event("next", "工程會勘", "2026-08-18 11:00:00", "2026-08-18 12:00:00")

        let snapshot = engine.snapshot(
            tasks: [],
            inboxItems: [],
            workEvents: [],
            calendarEvents: [upcoming, current],
            now: now
        )

        XCTAssertEqual(snapshot.currentEvent?.id, "current")
        XCTAssertEqual(snapshot.nextEvent?.id, "next")
        XCTAssertEqual(snapshot.nowItems.compactMap { $0.calendarEvent?.id }, ["current"])
        XCTAssertEqual(snapshot.nextItems.compactMap { $0.calendarEvent?.id }, ["next"])
        XCTAssertEqual(snapshot.headline, "現在正在進行：行政會議")
    }

    func testUpcomingEventWithinNinetyMinutesShapesHeadline() {
        let now = date("2026-08-18 10:00:00")
        let upcoming = event("next", "行政會議", "2026-08-18 11:00:00", "2026-08-18 12:00:00")
        let urgent = task("urgent", name: "確認採購公告", priority: "高")

        let snapshot = engine.snapshot(
            tasks: [urgent],
            inboxItems: [],
            workEvents: [],
            calendarEvents: [upcoming],
            now: now
        )

        XCTAssertEqual(snapshot.headline, "11:00 有「行政會議」，先處理「確認採購公告」")
    }

    func testSnoozedTaskIsExcludedFromEveryBucket() {
        let now = date("2026-08-18 10:00:00")
        let task = task("snoozed", name: "稍後處理", priority: "高")

        let snapshot = engine.snapshot(
            tasks: [task],
            inboxItems: [],
            workEvents: [],
            calendarEvents: [],
            snoozedUntil: ["snoozed": date("2026-08-18 11:00:00")],
            now: now
        )

        let allIDs = (snapshot.nowItems + snapshot.nextItems + snapshot.laterItems).compactMap { $0.task?.taskId }
        XCTAssertFalse(allIDs.contains("snoozed"))
        XCTAssertEqual(snapshot.headline, "目前沒有急迫工作")
    }

    func testContextItemsAreNotDuplicatedAcrossBuckets() {
        let now = date("2026-08-18 10:00:00")
        let tasks = [
            task("high", name: "高優先工作", priority: "高"),
            task("normal", name: "一般工作")
        ]
        let inbox = [
            CaptureItem(text: "第一則 Inbox", createdAt: date("2026-08-16 09:00:00")),
            CaptureItem(text: "第二則 Inbox", createdAt: date("2026-08-17 09:00:00"))
        ]

        let snapshot = engine.snapshot(
            tasks: tasks,
            inboxItems: inbox,
            workEvents: [],
            calendarEvents: [],
            now: now
        )

        let ids = (snapshot.nowItems + snapshot.nextItems + snapshot.laterItems).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testRecentActivityUsesLatestEventFromToday() {
        let now = date("2026-08-18 16:00:00")
        let events = [
            WorkEvent(timestamp: date("2026-08-17 18:00:00"), kind: .taskUpdated, title: "昨天"),
            WorkEvent(timestamp: date("2026-08-18 09:00:00"), kind: .taskUpdated, title: "早上"),
            WorkEvent(timestamp: date("2026-08-18 15:30:00"), kind: .taskCompleted, title: "剛完成")
        ]

        let snapshot = engine.snapshot(
            tasks: [],
            inboxItems: [],
            workEvents: events,
            calendarEvents: [],
            now: now
        )

        XCTAssertEqual(snapshot.recentActivity?.title, "剛完成")
    }

    private func task(
        _ id: String,
        name: String,
        status: String = "進行中",
        priority: String = "中",
        waitingFor: String? = nil
    ) -> GASTaskDigest.Task {
        GASTaskDigest.Task(
            taskId: id,
            name: name,
            status: status,
            priority: priority,
            waitingFor: waitingFor
        )
    }

    private func event(_ id: String, _ title: String, _ start: String, _ end: String) -> CalendarEventSummary {
        CalendarEventSummary(
            id: id,
            title: title,
            startDate: date(start),
            endDate: date(end),
            location: nil,
            notes: nil,
            calendarName: "測試",
            isAllDay: false
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)!
    }
}
