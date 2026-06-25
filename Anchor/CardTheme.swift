import SwiftUI

/// Card color/font themes for the shareable card (a Pro feature). The first theme is free;
/// the rest unlock with Anchor Pro. Colors are fixed (not theme-dependent) so the exported
/// image always looks the same.
struct CardTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let background: Color
    let ink: Color
    let accent: Color
    let rounded: Bool          // SF Rounded vs the default system serif-free face
    let isPro: Bool

    var font: Font.Design { rounded ? .rounded : .serif }

    static let classic = CardTheme(id: "classic", name: "Classic",
                                   background: .white, ink: Color(white: 0.08),
                                   accent: Color(hex: "#007AFF"), rounded: true, isPro: false)

    static let ink = CardTheme(id: "ink", name: "Ink",
                               background: Color(hex: "#0B0B0E"), ink: .white,
                               accent: Color(hex: "#5AC8FA"), rounded: true, isPro: true)

    static let paper = CardTheme(id: "paper", name: "Paper",
                                 background: Color(hex: "#F6F1E7"), ink: Color(hex: "#2B2622"),
                                 accent: Color(hex: "#B07A3C"), rounded: false, isPro: true)

    static let sky = CardTheme(id: "sky", name: "Sky",
                               background: Color(hex: "#EAF3FF"), ink: Color(hex: "#0B2A4A"),
                               accent: Color(hex: "#007AFF"), rounded: false, isPro: true)

    static let all: [CardTheme] = [classic, ink, paper, sky]

    static func theme(id: String) -> CardTheme { all.first { $0.id == id } ?? classic }
}
