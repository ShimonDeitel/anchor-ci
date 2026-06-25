import SwiftUI

/// Write or edit one day's intention — a single full sentence plus an optional tag.
struct EditorView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let day: Date

    @State private var text = ""
    @State private var tag: String?
    @FocusState private var focused: Bool

    private let limit = 200

    private var dayString: String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: day)
    }
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnchorBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(dayString)
                            .font(.subheadline).foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("e.g. Finish the first draft before I check any messages.")
                                    .font(.system(size: 22, weight: .regular, design: .serif))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 10).padding(.leading, 6)
                            }
                            TextEditor(text: $text)
                                .font(.system(size: 22, weight: .regular, design: .serif))
                                .frame(minHeight: 140)
                                .scrollContentBackground(.hidden)
                                .focused($focused)
                                .accessibilityIdentifier("intention-field")
                                .onChange(of: text) { _, newValue in
                                    if newValue.count > limit { text = String(newValue.prefix(limit)) }
                                }
                        }
                        .anchorCard()

                        HStack {
                            Text("\(text.count)/\(limit)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }

                        Text("Tag (optional)").font(.subheadline.weight(.semibold))
                        FlowTags(selected: tag) { picked in
                            tag = (tag == picked) ? nil : picked
                            Haptics.tap()
                        }

                        Spacer(minLength: 8)

                        Button {
                            appModel.setIntention(text: text, tag: tag, for: day)
                            Haptics.success()
                            dismiss()
                        } label: {
                            Text("Save").frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .prominentButton()
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                        .accessibilityIdentifier("save-intention")
                    }
                    .padding()
                }
            }
            .navigationTitle("Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .tint(Color.anchorAccent)
            .onAppear {
                if let existing = appModel.intention(on: day) {
                    text = existing.text
                    tag = existing.tag
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
    }
}

/// A simple wrapping row of tag chips.
private struct FlowTags: View {
    let selected: String?
    let onPick: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(IntentionTag.allCases) { t in
                TagChip(title: t.label, selected: selected == t.rawValue) {
                    onPick(t.rawValue)
                }
            }
        }
    }
}
