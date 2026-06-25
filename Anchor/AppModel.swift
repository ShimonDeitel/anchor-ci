import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store, derives the streak (with the Pro monthly freeze),
/// enforces one-intention-per-day, and builds the searchable archive. Stats are always derived
/// from the stored intentions — never stored as truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var totalKept = 0
    @Published private(set) var keptThisMonth = 0
    @Published private(set) var didKeepToday = false
    @Published private(set) var today: Intention?

    private let cal = Calendar.current

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only; no CloudKit)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Intention.self])
        // Plain local persistence — no CloudKit. Stays fully on-device.
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Writing intentions (one per calendar day)

    /// Set or edit a day's intention. Empty text is treated as a delete of that day.
    func setIntention(text: String, tag: String?, for day: Date = .now) {
        let key = cal.startOfDay(for: day)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ctx = container.mainContext

        let existing = intention(on: key)
        if trimmed.isEmpty {
            if let existing { ctx.delete(existing) }
        } else if let existing {
            existing.text = trimmed
            existing.tag = tag
            existing.updatedAt = .now
        } else {
            ctx.insert(Intention(day: key, text: trimmed, tag: tag))
        }
        try? ctx.save()
        refresh()
    }

    func intention(on day: Date) -> Intention? {
        let key = cal.startOfDay(for: day)
        var d = FetchDescriptor<Intention>(predicate: #Predicate { $0.day == key })
        d.fetchLimit = 1
        return (try? container.mainContext.fetch(d))?.first
    }

    // MARK: Archive / search

    func allIntentions() -> [Intention] {
        let d = FetchDescriptor<Intention>(sortBy: [SortDescriptor(\.day, order: .reverse)])
        return (try? container.mainContext.fetch(d)) ?? []
    }

    /// Searchable archive: case-insensitive match over text, tag and the formatted date.
    func search(_ query: String) -> [Intention] {
        let all = allIntentions()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        return all.filter { item in
            if item.text.lowercased().contains(q) { return true }
            if let tag = item.tag?.lowercased(), tag.contains(q) { return true }
            return fmt.string(from: item.day).lowercased().contains(q)
        }
    }

    // MARK: Streak / stats

    func refresh() {
        let all = allIntentions()
        totalKept = all.count
        today = all.first { cal.isDateInToday($0.day) }
        didKeepToday = today != nil

        let days = Set(all.map { cal.startOfDay(for: $0.day) })
        // The freeze only bridges a gap AFTER it has been explicitly consumed for the month.
        // An unconsumed freeze must NOT silently raise the streak, otherwise consuming it would
        // appear to *drop* the streak. (See consumeFreezeThisMonth.)
        let allowFreeze = (store?.isPro == true) && freezeWasConsumedThisMonth()
        currentStreak = StreakEngine.currentStreak(days: days, allowFreeze: allowFreeze, cal: cal)
        longestStreak = StreakEngine.longestStreak(days: days, cal: cal)
        keptThisMonth = all.filter { cal.isDate($0.day, equalTo: .now, toGranularity: .month) }.count
    }

    // MARK: Pro — monthly streak freeze
    // The freeze is "available" until it has been consumed for the current month. We track the
    // month a freeze was applied so it only bridges one gap per calendar month — and, crucially,
    // the bridge is enabled ONLY by an explicit consume. An unconsumed freeze never changes the
    // streak, so pressing "Streak freeze" can only ever protect (raise/hold) the streak, never
    // drop it.

    private let kFreezeMonth = "anchor.freeze.month"

    private func monthKey(_ date: Date = .now) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    /// True until this month's freeze has been consumed (drives the Settings "Available/Used" label).
    func hasFreezeAvailableThisMonth() -> Bool {
        let used = UserDefaults.standard.string(forKey: kFreezeMonth)
        return used != monthKey()
    }

    /// True once this month's freeze has been consumed — this is what actually enables the
    /// single-gap bridge in `refresh()`.
    func freezeWasConsumedThisMonth() -> Bool {
        UserDefaults.standard.string(forKey: kFreezeMonth) == monthKey()
    }

    /// Mark this month's freeze as spent (Pro action from the streak card). This is the action that
    /// *enables* the one-gap bridge for the month. No-op for free users.
    func consumeFreezeThisMonth() {
        guard store?.isPro == true else { return }
        UserDefaults.standard.set(monthKey(), forKey: kFreezeMonth)
        Haptics.success()
        refresh()
    }

    // MARK: Pro — 1-year export

    /// Plain-text export of the last 365 days of intentions, newest first.
    func exportText() -> String {
        let cutoff = cal.date(byAdding: .day, value: -365, to: cal.startOfDay(for: .now)) ?? .distantPast
        let fmt = DateFormatter(); fmt.dateStyle = .medium
        let rows = allIntentions()
            .filter { $0.day >= cutoff }
            .map { item -> String in
                let tag = item.tag.map { " [\($0)]" } ?? ""
                return "\(fmt.string(from: item.day))\(tag)\n\(item.text)"
            }
        let header = "Anchor — Daily Intentions\nLast 365 days\n\n"
        return header + rows.joined(separator: "\n\n")
    }

    // MARK: Account deletion

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: Intention.self)
        try? ctx.save()
        UserDefaults.standard.removeObject(forKey: kFreezeMonth)
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let n = env["ANCHOR_SEED"].flatMap(Int.init), n > 0 else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<Intention>()))?.isEmpty ?? true) {
            let samples = [
                "Write one honest paragraph before I open any app.",
                "Walk twenty minutes and leave my phone at home.",
                "Say the kind thing out loud instead of just thinking it.",
                "Do the hardest task first, no negotiating.",
                "Drink water before coffee and breathe before replying."
            ]
            let tags = IntentionTag.allCases.map { $0.rawValue }
            for offset in 0..<n {
                if let day = cal.date(byAdding: .day, value: -offset, to: .now) {
                    ctx.insert(Intention(day: cal.startOfDay(for: day),
                                         text: samples[offset % samples.count],
                                         tag: tags[offset % tags.count]))
                }
            }
            try? ctx.save()
        }
    }
    #endif
}
