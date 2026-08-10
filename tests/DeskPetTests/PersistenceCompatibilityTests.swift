import Foundation
import XCTest
@testable import DeskPet

final class PersistenceCompatibilityTests: XCTestCase {
    func testLegacyCaptureItemWithoutNewerFieldsDecodes() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","text":"舊記事","createdAt":"2026-08-10T01:00:00Z","status":"inbox"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(CaptureItem.self, from: json)
        XCTAssertEqual(item.text, "舊記事")
        XCTAssertTrue(item.actionReceipts.isEmpty)
        XCTAssertNil(item.linkedGASTaskID)
    }

    func testLegacyWorkEventDecodesWithoutMigration() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000002","timestamp":"2026-08-10T01:00:00Z","kind":"taskUpdated","title":"舊事件","source":"gas"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(WorkEvent.self, from: json)
        XCTAssertEqual(event.title, "舊事件")
        XCTAssertNil(event.detail)
    }

    @MainActor func testSnoozeStoreIgnoresInvalidPersistenceAndExpiresLocally() {
        let suite = "DeskPetTests.Snooze.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(Data("not-json".utf8), forKey: "test")
        let store = SnoozeStore(defaults: defaults, key: "test")
        XCTAssertTrue(store.snoozedUntil.isEmpty)
        let now = Date()
        store.snooze(taskID: "T1", until: now.addingTimeInterval(3600))
        XCTAssertTrue(store.isSnoozed(taskID: "T1", now: now))
        store.purgeExpired(now: now.addingTimeInterval(7200))
        XCTAssertFalse(store.isSnoozed(taskID: "T1", now: now.addingTimeInterval(7200)))
        defaults.removePersistentDomain(forName: suite)
    }
}
