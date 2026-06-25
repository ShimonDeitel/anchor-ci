import SwiftUI

/// The streak pill shown on Home. Green when today's intention is kept, neutral otherwise.
struct StreakPill: View {
    let streak: Int
    let doneToday: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: doneToday ? "flame.fill" : "flame")
                .font(.system(size: 14, weight: .bold))
            Text(streak == 1 ? "1 day" : "\(streak) days")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(doneToday ? .white : Color.anchorAccent)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(
            doneToday ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.anchorCard),
            in: Capsule()
        )
        .accessibilityIdentifier("streak-pill")
    }
}

/// A small selectable tag chip used on the editor.
struct TagChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    selected ? Color.anchorAccent : Color.anchorCard,
                    in: Capsule()
                )
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tag-\(title)")
    }
}

/// A small labelled metric tile used on Home / Archive headers.
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.anchorAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.anchorCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Wraps UIActivityViewController so we can share a rendered share card image / exported file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
