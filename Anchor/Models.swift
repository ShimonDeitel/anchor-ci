import Foundation
import SwiftData

/// One daily intention — a single full sentence, optionally tagged. Exactly one per calendar day.
/// All properties have defaults and there are no SwiftData unique constraints (CloudKit mirroring
/// forbids them), so day-uniqueness is enforced in `AppModel.setIntention` instead.
@Model
final class Intention {
    var id: UUID = UUID()
    /// Start-of-day (local) the intention belongs to — the de-facto unique key.
    var day: Date = Calendar.current.startOfDay(for: .now)
    var text: String = ""
    var tag: String?
    /// When the row was first written (kept distinct from `day` for ordering / display).
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(id: UUID = UUID(), day: Date = Calendar.current.startOfDay(for: .now),
         text: String = "", tag: String? = nil,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.day = day
        self.text = text
        self.tag = tag
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// The five built-in tags. Free; a small piece of structure without device permissions.
enum IntentionTag: String, CaseIterable, Identifiable {
    case focus, health, growth, calm, connect
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .focus: return "scope"
        case .health: return "heart"
        case .growth: return "leaf"
        case .calm: return "moon"
        case .connect: return "person.2"
        }
    }
}
