import XCTest
@testable import MillaCore

final class DailyNewsTests: XCTestCase {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - 小时时段

    func testHourlySlotKeyIsUniquePerHour() {
        let formatter = ISO8601DateFormatter()

        let t1 = formatter.date(from: "2026-10-17T14:05:00Z")!
        let t2 = formatter.date(from: "2026-10-17T14:59:00Z")!
        let t3 = formatter.date(from: "2026-10-17T15:00:00Z")!

        let slot1 = DailyNews.hourlySlot(now: t1, calendar: utcCalendar)
        let slot2 = DailyNews.hourlySlot(now: t2, calendar: utcCalendar)
        let slot3 = DailyNews.hourlySlot(now: t3, calendar: utcCalendar)

        // 同一小时内 key 相同（用于"本小时已抓不重复抓"）
        XCTAssertEqual(slot1.key, "2026-10-17-14")
        XCTAssertEqual(slot1.key, slot2.key)
        // 跨小时 key 不同
        XCTAssertEqual(slot3.key, "2026-10-17-15")
        XCTAssertNotEqual(slot1.key, slot3.key)
        // 展示名
        XCTAssertEqual(slot1.name, "14 点档")
    }

    func testHourlySlotCrossesMidnight() {
        let formatter = ISO8601DateFormatter()
        let before = formatter.date(from: "2026-10-17T23:30:00Z")!
        let after = formatter.date(from: "2026-10-18T00:10:00Z")!
        XCTAssertEqual(
            DailyNews.hourlySlot(now: before, calendar: utcCalendar).key,
            "2026-10-17-23"
        )
        XCTAssertEqual(
            DailyNews.hourlySlot(now: after, calendar: utcCalendar).key,
            "2026-10-18-00"
        )
    }
}
