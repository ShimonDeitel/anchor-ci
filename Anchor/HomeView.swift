import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showEditor = false
    @State private var showArchive = false
    @State private var showSettings = false
    @State private var showShare = false

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnchorBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        streakCard
                        todayCard
                        archiveButton
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Anchor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settings-button")
                }
            }
            .tint(Color.anchorAccent)
            .sheet(isPresented: $showEditor, onDismiss: { appModel.refresh() }) {
                EditorView(day: .now)
            }
            .sheet(isPresented: $showArchive) { ArchiveView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showShare) {
                ShareCardSheet(text: appModel.today?.text ?? "", day: appModel.currentStreak)
            }
            .onAppear { appModel.refresh() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayString).font(.title3.weight(.semibold))
                Text("Today's intention").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            StreakPill(streak: appModel.currentStreak, doneToday: appModel.didKeepToday)
            VStack(alignment: .leading, spacing: 2) {
                Text(appModel.didKeepToday ? "Kept today" : "Not kept yet")
                    .font(.subheadline.weight(.semibold))
                Text("Best: \(appModel.longestStreak) · \(appModel.totalKept) total")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .anchorCard()
    }

    @ViewBuilder
    private var todayCard: some View {
        if let today = appModel.today {
            VStack(alignment: .leading, spacing: 16) {
                if let tag = today.tag, let t = IntentionTag(rawValue: tag) {
                    Label(t.label, systemImage: t.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.anchorAccent)
                }
                Text(today.text)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("today-text")
                HStack(spacing: 10) {
                    Button { Haptics.tap(); showEditor = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .softButton()
                    Button { Haptics.tap(); showShare = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .softButton()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .anchorCard()
        } else {
            VStack(spacing: 16) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.anchorAccent)
                Text("Add today's intention")
                    .font(.title3.weight(.semibold))
                Text("One full sentence. What matters most today?")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { Haptics.tap(); showEditor = true } label: {
                    Text("Write it").frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .prominentButton()
                .accessibilityIdentifier("add-today")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .anchorCard()
        }
    }

    private var archiveButton: some View {
        Button { Haptics.tap(); showArchive = true } label: {
            HStack {
                Label("Archive", systemImage: "calendar")
                Spacer()
                Text("\(appModel.totalKept)").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .anchorCard()
        .accessibilityIdentifier("archive-button")
    }
}
