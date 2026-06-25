import SwiftUI

/// The shareable card: the centered intention text + "Day N". Fixed colors per the chosen
/// theme (not the app's light/dark mode), with a subtle "Anchor" wordmark for organic growth.
struct ShareCard: View {
    let text: String
    let dayNumber: Int
    let theme: CardTheme

    var body: some View {
        ZStack {
            theme.background
            VStack(spacing: 22) {
                Image(systemName: "scope")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(theme.accent)

                Text(text.isEmpty ? "One line a day, kept." : "\u{201C}\(text)\u{201D}")
                    .font(.system(size: 26, weight: .semibold, design: theme.font))
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if dayNumber > 0 {
                    Text("Day \(dayNumber)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                }

                Spacer().frame(height: 4)

                Text("Anchor")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.accent)
                Text("One line a day · on the App Store")
                    .font(.caption)
                    .foregroundStyle(theme.ink.opacity(0.55))
            }
            .padding(40)
        }
        .frame(width: 360, height: 480)
    }

    @MainActor func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Sheet that previews the card, lets Pro users pick a theme, and shares the rendered image.
struct ShareCardSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let text: String
    let day: Int

    @AppStorage("anchor.cardTheme") private var themeID = CardTheme.classic.id
    @State private var showShare = false
    @State private var rendered: UIImage?
    @State private var showPaywall = false

    private var theme: CardTheme {
        let t = CardTheme.theme(id: themeID)
        // Defense-in-depth: a free user can never end up on a Pro theme.
        return (t.isPro && !store.isPro) ? .classic : t
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnchorBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        ShareCard(text: text, dayNumber: day, theme: theme)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                            .padding(.top, 12)

                        themePicker

                        Button {
                            Haptics.tap()
                            rendered = ShareCard(text: text, dayNumber: day, theme: theme).render()
                            if rendered != nil { showShare = true }
                        } label: {
                            Label("Share card", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .prominentButton()
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.anchorAccent)
            .sheet(isPresented: $showShare) {
                if let rendered { ShareSheet(items: [rendered]) }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Theme").font(.subheadline.weight(.semibold))
                if !store.isPro {
                    Spacer()
                    Label("Pro", systemImage: "lock.fill")
                        .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CardTheme.all) { t in
                        Button {
                            if t.isPro && !store.isPro {
                                Haptics.warning(); showPaywall = true
                            } else {
                                Haptics.tap(); themeID = t.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(t.background)
                                        .frame(width: 56, height: 56)
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(themeID == t.id ? Color.anchorAccent : Color.anchorHair,
                                                      lineWidth: themeID == t.id ? 2 : 1)
                                        .frame(width: 56, height: 56)
                                    if t.isPro && !store.isPro {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(t.ink.opacity(0.6))
                                    }
                                }
                                Text(t.name).font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
