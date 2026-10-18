import XCTest
@testable import MillaCore

final class DailyNewsTests: XCTestCase {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - 时段

    func testSlotBoundaries() throws {
        let formatter = ISO8601DateFormatter()

        // 6:59 → nil（凌晨无时段）
        let earlyMorning = formatter.date(from: "2026-10-17T06:59:00Z")!
        XCTAssertNil(DailyNews.currentSlot(now: earlyMorning, calendar: utcCalendar))

        // 7:00 → 上午版
        let seven = formatter.date(from: "2026-10-17T07:00:00Z")!
        let am = DailyNews.currentSlot(now: seven, calendar: utcCalendar)
        XCTAssertEqual(am?.key, "2026-10-17-am")
        XCTAssertEqual(am?.name, "上午版")

        // 11:59 仍是上午版
        let beforeNoon = formatter.date(from: "2026-10-17T11:59:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: beforeNoon, calendar: utcCalendar)?.key,
            "2026-10-17-am"
        )

        // 12:00 → 午后版
        let noon = formatter.date(from: "2026-10-17T12:00:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: noon, calendar: utcCalendar)?.key,
            "2026-10-17-pm"
        )

        // 23:59 仍是午后版
        let lateNight = formatter.date(from: "2026-10-17T23:59:00Z")!
        XCTAssertEqual(
            DailyNews.currentSlot(now: lateNight, calendar: utcCalendar)?.key,
            "2026-10-17-pm"
        )
    }
}
