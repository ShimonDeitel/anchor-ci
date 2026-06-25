import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("anchor.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var freezeMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Anchor \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                if store.isPro { proToolsSection }
                appearanceSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.anchorAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showExportShare) {
                if let exportURL { ShareSheet(items: [exportURL]) }
            }
            .alert("Erase All Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases all of your intentions on this device. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Anchor Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock Anchor Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("One-time purchase. Card themes, a monthly streak freeze and a 1-year export.")
            }
        }
    }

    private var proToolsSection: some View {
        Section("Pro tools") {
            // Streak freeze — once a month.
            Button {
                if appModel.hasFreezeAvailableThisMonth() {
                    appModel.consumeFreezeThisMonth()
                    freezeMessage = "Freeze used for this month. One missed day is forgiven."
                } else {
                    freezeMessage = "You've already used this month's freeze."
                }
            } label: {
                HStack {
                    Label("Streak freeze", systemImage: "snowflake")
                    Spacer()
                    Text(appModel.hasFreezeAvailableThisMonth() ? "Available" : "Used")
                        .foregroundStyle(.secondary)
                }
            }
            if let freezeMessage {
                Text(freezeMessage).font(.footnote).foregroundStyle(.secondary)
            }

            // Exports — re-check the verified StoreKit entitlement at the point of access, never
            // UI-visibility only.
            Button {
                guard store.isPro else { showPaywall = true; return }
                exportURL = Export.writeText(appModel.exportText())
                if exportURL != nil { showExportShare = true }
            } label: {
                Label("Export last year (text)", systemImage: "doc.text")
            }
            Button {
                guard store.isPro else { showPaywall = true; return }
                exportURL = Export.writePDF(appModel.exportText())
                if exportURL != nil { showExportShare = true }
            } label: {
                Label("Export last year (PDF)", systemImage: "doc.richtext")
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    /// Local data management. Everything stays on this device.
    private var dataSection: some View {
        Section {
            Button("Erase All Data", role: .destructive) { showDeleteConfirm = true }
        } header: {
            Text("Data")
        } footer: {
            Text("Your intentions are stored only on this device.")
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/anchor-site/privacy.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
