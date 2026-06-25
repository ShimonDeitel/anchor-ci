import XCTest
@testable import Anchor

final class AnchorTests: XCTestCase {

    private let cal = Calendar.current

    private func days(_ offsets: [Int]) -> Set<Date> {
        let today = cal.startOfDay(for: Date())
        return Set(offsets.compactMap { cal.date(byAdding: .day, value: -$0, to: today) })
    }

    // MARK: Current streak (no freeze)

    func testCurrentStreakCountsTodayBackwards() {
        XCTAssertEqual(StreakEngine.currentStreak(days: days([0, 1, 2]), allowFreeze: false), 3)
    }

    func testCurrentStreakHoldsWhenTodayNotYetLogged() {
        // Logged yesterday & the day before, not today → streak still 2 (today still possible).
        XCTAssertEqual(StreakEngine.currentStreak(days: days([1, 2]), allowFreeze: false), 2)
    }

    func testCurrentStreakBreaksWithGap() {
        // Today logged, gap at day 1, then 2 & 3 → current streak is just 1.
        XCTAssertEqual(StreakEngine.currentStreak(days: days([0, 2, 3]), allowFreeze: false), 1)
        XCTAssertEqual(StreakEngine.currentStreak(days: [], allowFreeze: false), 0)
    }

    // MARK: Current streak (Pro freeze bridges exactly one gap)

    func testFreezeBridgesSingleGap() {
        // Today + day 2 + day 3, missing day 1. Free → 1. Pro freeze → 4 (bridges day 1).
        XCTAssertEqual(StreakEngine.currentStreak(days: days([0, 2, 3]), allowFreeze: false), 1)
        XCTAssertEqual(StreakEngine.currentStreak(days: days([0, 2, 3]), allowFreeze: true), 4)
    }

    func testFreezeOnlyBridgesOneGap() {
        // Today + day2 + day4 + day5; gaps at day1 AND day3. The freeze bridges the first gap
        // (day1, which then counts) and reaches day2; the day3 gap ends it.
        // Run = today + bridged day1 + day2 = 3.
        XCTAssertEqual(StreakEngine.currentStreak(days: days([0, 2, 4, 5]), allowFreeze: true), 3)
    }

    func testFreezeBridgesYesterdayWhenTodayEmpty() {
        // Today empty (a free in-progress pass), yesterday empty, then day2 & day3 kept. The
        // freeze bridges yesterday (counts) → bridged day1 + day2 + day3 = 3. Free users: 0.
        XCTAssertEqual(StreakEngine.currentStreak(days: days([2, 3]), allowFreeze: true), 3)
        XCTAssertEqual(StreakEngine.currentStreak(days: days([2, 3]), allowFreeze: false), 0)
    }

    // MARK: Longest streak (honest, no freeze)

    func testLongestStreak() {
        // Runs: {0,1,2} length 3, and {5,6} length 2 → longest 3.
        XCTAssertEqual(StreakEngine.longestStreak(days: days([0, 1, 2, 5, 6])), 3)
        XCTAssertEqual(StreakEngine.longestStreak(days: []), 0)
    }

    // MARK: Card-theme Pro split

    func testCardThemeProSplit() {
        XCTAssertFalse(CardTheme.classic.isPro, "the default theme is free")
        XCTAssertTrue(CardTheme.all.filter { $0.id != "classic" }.allSatisfy { $0.isPro })
        XCTAssertEqual(CardTheme.theme(id: "ink").id, "ink")
        XCTAssertEqual(CardTheme.theme(id: "nonsense").id, "classic", "unknown id falls back to classic")
    }

    // MARK: Store

    @MainActor
    func testProductIDAndPrice() async {
        let store = Store()
        try? await Task.sleep(for: .seconds(0.2))
        XCTAssertEqual(Store.productID, "anchor_pro_unlock")
        XCTAssertEqual(store.displayPrice, "$0.99")
        XCTAssertFalse(store.isPro, "Pro must start locked")
    }
}
