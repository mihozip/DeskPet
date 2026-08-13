import Foundation
import XCTest
@testable import DeskPet

final class CalendarQueryTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return value
    }

    func testLecturerQueryUsesCurrentYearAndClassifiesRole() {
        let parser = CalendarQueryParser(calendar: calendar)
        let query = parser.parse("告訴我今年所有研習講師的行程", referenceDate: date("2026-08-13 10:00:00"))
        XCTAssertEqual(query.category, .lecturer)
        XCTAssertEqual(format(query.interval.start), "2026-01-01 00:00:00")
        XCTAssertEqual(format(query.interval.end), "2027-01-01 00:00:00")
        XCTAssertTrue(query.keywords.isEmpty)
    }

    func testExplicitMonthAndLocationAreParsed() {
        let parser = CalendarQueryParser(calendar: calendar)
        let query = parser.parse("九月在台中的研習", referenceDate: date("2026-08-13 10:00:00"))
        XCTAssertEqual(query.category, .training)
        XCTAssertEqual(query.locationKeyword, "台中")
        XCTAssertEqual(format(query.interval.start), "2026-09-01 00:00:00")
        XCTAssertEqual(format(query.interval.end), "2026-10-01 00:00:00")
    }

    func testLecturerMatcherRequiresRoleSignalAndExcludesAttendee() {
        let query = CalendarQueryParser(calendar: calendar).parse("今年所有研習講師的行程", referenceDate: date("2026-08-13 10:00:00"))
        let matcher = CalendarQueryMatcher()

        XCTAssertTrue(matcher.matches(event("AI 命題研習｜講師", notes: "主講：生成式 AI 輔助命題"), query: query))
        XCTAssertFalse(matcher.matches(event("AI 命題研習", notes: "參加教師增能研習"), query: query))
        XCTAssertFalse(matcher.matches(event("行政會議"), query: query))
    }

    func testGeneralKeywordSearchMatchesTitleLocationOrNotes() {
        let query = CalendarQueryParser(calendar: calendar).parse("今年 AI 行程", referenceDate: date("2026-08-13 10:00:00"))
        let matcher = CalendarQueryMatcher()
        XCTAssertTrue(matcher.matches(event("生成式 AI 分享"), query: query))
        XCTAssertFalse(matcher.matches(event("校務會議"), query: query))
    }

    private func event(_ title: String, location: String? = nil, notes: String? = nil) -> CalendarEventSummary {
        CalendarEventSummary(
            id: UUID().uuidString,
            title: title,
            startDate: date("2026-09-01 09:00:00"),
            endDate: date("2026-09-01 12:00:00"),
            location: location,
            notes: notes,
            calendarName: "工作",
            isAllDay: false
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)!
    }

    private func format(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: value)
    }
}
