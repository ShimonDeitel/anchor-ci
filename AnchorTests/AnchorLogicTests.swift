import XCTest
import SwiftData
@testable import Anchor

/// Integration tests against a real in-memory SwiftData store: day-uniqueness, edit, delete,
/// search, stats and the export body.
@MainActor
final class AnchorLogicTests: XCTestCase {

    private func memoryModel() -> ModelContainer {
        try! ModelContainer(for: Intention.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testSetIntentionCreatesAndCountsStreak() {
        let model = AppModel(container: memoryModel())
        XCTAssertEqual(model.totalKept, 0)
        XCTAssertFalse(model.didKeepToday)
        XCTAssertEqual(model.currentStreak, 0)

        model.setIntention(text: "Do the hard thing first.", tag: "focus")

        XCTAssertEqual(model.totalKept, 1)
        XCTAssertTrue(model.didKeepToday)
        XCTAssertEqual(model.currentStreak, 1)
        XCTAssertEqual(model.today?.text, "Do the hard thing first.")
        XCTAssertEqual(model.today?.tag, "focus")
    }

    func testSecondWriteSameDayEditsInPlace() {
        let model = AppModel(container: memoryModel())
        model.setIntention(text: "First version.", tag: nil)
        model.setIntention(text: "Edited version.", tag: "calm")

        XCTAssertEqual(model.totalKept, 1, "one calendar day yields exactly one intention")
        XCTAssertEqual(model.today?.text, "Edited version.")
        XCTAssertEqual(model.today?.tag, "calm")
        XCTAssertEqual(model.currentStreak, 1)
    }

    func testEmptyTextDeletesTheDay() {
        let model = AppModel(container: memoryModel())
        model.setIntention(text: "Something.", tag: nil)
        XCTAssertEqual(model.totalKept, 1)
        model.setIntention(text: "   ", tag: nil)
        XCTAssertEqual(model.totalKept, 0, "blank text removes the day's intention")
        XCTAssertFalse(model.didKeepToday)
    }

    func testSearchMatchesTextAndTag() {
        let model = AppModel(container: memoryModel())
        let cal = Calendar.current
        model.setIntention(text: "Walk twenty minutes outside.", tag: "health")
        model.setIntention(text: "Read one chapter tonight.", tag: "growth",
                           for: cal.date(byAdding: .day, value: -1, to: .now)!)

        XCTAssertEqual(model.search("").count, 2, "empty query returns everything")
        XCTAssertEqual(model.search("walk").count, 1)
        XCTAssertEqual(model.search("HEALTH").count, 1, "search is case-insensitive over tags")
        XCTAssertEqual(model.search("chapter").count, 1)
        XCTAssertEqual(model.search("zzz").count, 0)
    }

    func testExportTextIncludesEntries() {
        let model = AppModel(container: memoryModel())
        model.setIntention(text: "Ship the build today.", tag: "focus")
        let body = model.exportText()
        XCTAssertTrue(body.contains("Ship the build today."))
        XCTAssertTrue(body.contains("[focus]"))
        XCTAssertTrue(body.contains("Anchor"))
    }

    // MARK: Streak-freeze regression (consuming the freeze must never DROP the streak)

    /// Pro user with a single gap (days {today, day2, day3}, missing day1). Pressing "Streak
    /// freeze" must protect — never break — the streak. Before consuming, the streak is the
    /// honest run ending today (1). After consuming, the freeze bridges the day1 gap and the
    /// streak rises to 4. It must never decrease as a result of consuming.
    func testConsumingFreezeNeverDropsStreak() async {
        // Force a verified Pro entitlement for the duration of this test.
        setenv("ANCHOR_FORCE_PRO", "1", 1)
        defer { unsetenv("ANCHOR_FORCE_PRO") }

        let store = Store()
        await store.refreshEntitlements()
        XCTAssertTrue(store.isPro, "test requires a Pro store")

        let model = AppModel(container: memoryModel())
        model.store = store

        // Fresh month: make sure no freeze is recorded as consumed.
        UserDefaults.standard.removeObject(forKey: "anchor.freeze.month")

        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: .now)! }
        model.setIntention(text: "Today.", tag: nil, for: day(0))
        model.setIntention(text: "Two days ago.", tag: nil, for: day(2))
        model.setIntention(text: "Three days ago.", tag: nil, for: day(3))

        // Unconsumed freeze does NOT silently bridge: the streak is the honest run ending today.
        XCTAssertFalse(model.freezeWasConsumedThisMonth())
        let before = model.currentStreak
        XCTAssertEqual(before, 1, "an unconsumed freeze must not raise the streak")

        // Consuming the freeze is the action that enables the bridge — the streak must not drop.
        model.consumeFreezeThisMonth()
        let after = model.currentStreak
        XCTAssertGreaterThanOrEqual(after, before, "consuming the freeze must never drop the streak")
        XCTAssertEqual(after, 4, "the freeze bridges the single day-1 gap (today+day1+day2+day3)")

        UserDefaults.standard.removeObject(forKey: "anchor.freeze.month")
    }
}
