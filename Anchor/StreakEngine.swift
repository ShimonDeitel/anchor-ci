import Foundation

/// Pure streak math, isolated so it can be unit-tested without SwiftData.
///
/// The streak is the run of consecutive calendar days ending today (or yesterday, if today
/// isn't kept yet). PRO users get ONE "streak freeze" per calendar month: a single missed day
/// inside the run is forgiven and does not break the streak. Free users get no freeze.
enum StreakEngine {

    /// Current streak as of `today`, optionally allowing one freeze.
    /// - Parameters:
    ///   - days: the set of start-of-day dates that have a kept intention.
    ///   - allowFreeze: whether a single-day gap may be bridged (Pro).
    ///   - cal: the calendar to use.
    ///   - today: the reference day (defaults to now).
    static func currentStreak(days: Set<Date>, allowFreeze: Bool,
                              cal: Calendar = .current, today: Date = .now) -> Int {
        guard !days.isEmpty else { return 0 }
        let start = cal.startOfDay(for: today)
        // Today is "in progress": if it isn't kept yet the streak still stands as of yesterday,
        // so anchor the walk at yesterday in that case (today's emptiness never costs the freeze).
        let anchor = days.contains(start)
            ? start
            : (cal.date(byAdding: .day, value: -1, to: start) ?? start)
        // `countFrom` itself handles an empty anchor: with a freeze available it bridges that one
        // missing day (which then counts); otherwise it returns 0 immediately.
        return countFrom(anchor, days: days, freezeUsed: false, cal: cal, allowFreeze: allowFreeze)
    }

    /// Walk backwards from `day`, counting kept days. With `allowFreeze`, the first single-day
    /// gap is bridged once (and the bridged day counts); a second gap ends the run.
    private static func countFrom(_ day: Date, days: Set<Date>, freezeUsed: Bool,
                                  cal: Calendar, allowFreeze: Bool = false) -> Int {
        var cursor = day
        var streak = 0
        var usedFreeze = freezeUsed
        while true {
            if days.contains(cursor) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else if allowFreeze && !usedFreeze,
                      let prev = cal.date(byAdding: .day, value: -1, to: cursor),
                      days.contains(prev) {
                // Bridge exactly one missing day: the freeze "saves" it, so it counts toward
                // the streak. Then require the next day to be kept.
                usedFreeze = true
                streak += 1
                cursor = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Longest run ever, no freeze (an honest all-time best).
    static func longestStreak(days: Set<Date>, cal: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: sorted[i - 1]), prev == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }
}
