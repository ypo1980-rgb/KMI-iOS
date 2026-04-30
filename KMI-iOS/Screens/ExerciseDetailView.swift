import SwiftUI
import Shared

struct ExerciseDetailView: View {
    let belt: Belt
    let topicTitle: String
    let item: String

    @State private var isFavorite: Bool = false
    @State private var isCompleted: Bool = false
    @State private var showShare: Bool = false
    @State private var noteText: String = ""
    @State private var didLoadNote: Bool = false

    private var storageKeyBase: String {
        // מפתח יציב מקומי (בהמשך נחליף למזהה קנוני מה-Shared)
        // שומר לפי belt + topicTitle + item
        let b = belt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.exercise.\(b).\(t).\(i)"
    }

    private var favKey: String { storageKeyBase + ".fav" }
    private var doneKey: String { storageKeyBase + ".done" }
    private var noteKey: String { storageKeyBase + ".note" }

    private var explanationText: String {
        let txt = LocalExplanations.shared.get(belt: belt, item: item)
        let clean = txt.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "לא נמצא הסבר לתרגיל זה." : clean
    }

    var shareText: String {
        "\(item)\n\(belt.heb) • \(topicTitle)\n\nKMI"
    }

    var body: some View {
        ZStack {
            ExerciseGradientBackground()

            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 8) {
                            Text(item)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("\(belt.heb)  •  \(topicTitle)")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    WhiteCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("פעולות מהירות")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.82))

                            HStack(spacing: 10) {
                                actionPill(
                                    title: isFavorite ? "מועדף" : "הוסף למועדפים",
                                    system: isFavorite ? "star.fill" : "star",
                                    accent: isFavorite ? Color.yellow.opacity(0.95) : Color.black.opacity(0.75)
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        isFavorite.toggle()
                                        saveBool(isFavorite, key: favKey)
                                    }
                                }

                                actionPill(
                                    title: "השמעה",
                                    system: "speaker.wave.2.fill",
                                    accent: Color.black.opacity(0.75)
                                ) {
                                    // TODO: בהמשך נחבר ל-TTS מה-Shared / iOS AVSpeechSynthesizer
                                    print("TTS placeholder: \(item)")
                                }

                                actionPill(
                                    title: isCompleted ? "בוצע" : "סמן כבוצע",
                                    system: isCompleted ? "checkmark.circle.fill" : "checkmark.circle",
                                    accent: isCompleted ? Color.green.opacity(0.95) : Color.black.opacity(0.75)
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        isCompleted.toggle()
                                        saveBool(isCompleted, key: doneKey)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                actionPill(
                                    title: "שתף",
                                    system: "square.and.arrow.up",
                                    accent: Color.black.opacity(0.75)
                                ) {
                                    showShare = true
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    WhiteCard {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("הסבר על התרגיל")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.82))

                            Text(explanationText)
                                .font(.body)
                                .foregroundStyle(Color.black.opacity(0.70))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .multilineTextAlignment(.trailing)

                            Divider().opacity(0.15)

                            Text("הערת המתאמן:")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.82))

                            TextEditor(text: $noteText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 130)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                )

                            HStack(spacing: 10) {
                                Button {
                                    clearNote()
                                } label: {
                                    Text("נקה")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.black.opacity(0.80))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.92))
                                        )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    saveNote()
                                } label: {
                                    Text("שמור הערה")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.black.opacity(0.80))
                                        )
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("תרגיל")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareText])
        }
        .onAppear {
            // ✅ טעינה אמיתית מהאחסון המקומי
            isFavorite = loadBool(key: favKey, defaultValue: false)
            isCompleted = loadBool(key: doneKey, defaultValue: false)
            loadNoteIfNeeded()
        }
    }

    // MARK: - Local storage (UserDefaults) – בהמשך נחליף ל-Shared

    private func loadBool(key: String, defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func saveBool(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func loadNoteIfNeeded() {
        guard !didLoadNote else { return }
        noteText = UserDefaults.standard.string(forKey: noteKey) ?? ""
        didLoadNote = true
    }

    private func saveNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: noteKey)
        noteText = trimmed
    }

    private func clearNote() {
        UserDefaults.standard.removeObject(forKey: noteKey)
        noteText = ""
    }

    // MARK: - UI helpers

    private func actionPill(
        title: String,
        system: String,
        accent: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: system)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.80))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(belt: .orange, topicTitle: "בעיטות", item: "בעיטה ישרה")
    }
}

// MARK: - Local background (no dependency on other files)
private struct ExerciseGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.25),
                Color(red: 0.20, green: 0.12, blue: 0.55),
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.10, green: 0.80, blue: 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Share sheet
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
