import SwiftUI

/// The searchable archive of every past intention, newest first.
struct ArchiveView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var editingDay: Date?

    private var results: [Intention] { appModel.search(query) }

    var body: some View {
        NavigationStack {
            Group {
                if appModel.totalKept == 0 {
                    emptyState
                } else if results.isEmpty {
                    noResults
                } else {
                    List {
                        ForEach(results) { item in
                            Button {
                                Haptics.tap(); editingDay = item.day
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .searchable(text: $query, prompt: "Search by date or text")
            .tint(Color.anchorAccent)
            .sheet(item: Binding(
                get: { editingDay.map { DayBox(day: $0) } },
                set: { editingDay = $0?.day }
            )) { box in
                EditorView(day: box.day)
            }
        }
    }

    private func row(_ item: Intention) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.day, format: .dateTime.weekday().month().day().year())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.anchorAccent)
                Spacer()
                if let tag = item.tag, let t = IntentionTag(rawValue: tag) {
                    Label(t.label, systemImage: t.symbol)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(item.text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No intentions yet",
            systemImage: "calendar",
            description: Text("Your daily intentions will appear here.")
        )
    }

    private var noResults: some View {
        ContentUnavailableView.search(text: query)
    }
}

/// Identifiable wrapper so a `Date` can drive a `.sheet(item:)`.
private struct DayBox: Identifiable {
    let day: Date
    var id: TimeInterval { day.timeIntervalSince1970 }
}
