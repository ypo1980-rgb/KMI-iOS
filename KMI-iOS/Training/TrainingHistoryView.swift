import SwiftUI

struct TrainingHistoryView: View {

    @State private var sessions: [[String: Any]] = []
    @AppStorage("kmi_app_language") private var languageCode = "he"

    private var isEnglish: Bool {
        let language = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return language == "en" || language == "english"
    }

    private func tr(_ hebrew: String, _ english: String) -> String {
        isEnglish ? english : hebrew
    }

    var body: some View {
        ZStack {

            KmiAppBackground()

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Text(tr("אין היסטוריית אימונים", "No training history"))
                        .kmiTypography(.sectionTitle)
                        .fontWeight(.heavy)

                    Text(tr(
                        "האימונים שתשמור יופיעו כאן",
                        "Your saved sessions will appear here"
                    ))
                    .kmiTypography(.secondary)
                    .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            } else {

                ScrollView {

                    VStack(spacing: 14) {

                        ForEach(sessions.indices, id: \.self) { index in
                            sessionCard(session: sessions[index])
                        }

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                }

            }

        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .onAppear {
            loadSessions()
        }
    }

    private func loadSessions() {

        sessions =
            UserDefaults.standard.array(forKey: "practice_sessions") as? [[String: Any]] ?? []

        sessions = sessions.sorted {
            ($0["date"] as? Double ?? 0) > ($1["date"] as? Double ?? 0)
        }
    }

    private func sessionCard(session: [String: Any]) -> some View {

        let duration = Int((session["duration"] as? Double ?? 0) / 60)
        let total = session["totalExercises"] as? Int ?? 0
        let completed = session["completedExercises"] as? Int ?? 0
        let rate = session["completionRate"] as? Int ?? 0
        let feedback = session["coachFeedback"] as? String ?? ""

        return WhiteCard {

            VStack(spacing: 10) {

                Text(tr("אימון", "Training session"))
                    .kmiTypography(.cardTitle)
                    .fontWeight(.heavy)

                Text(tr("משך: \(duration) דקות", "Duration: \(duration) min"))
                    .kmiTypography(.body)

                Text(tr("תרגילים: \(completed) / \(total)", "Exercises: \(completed) / \(total)"))
                    .kmiTypography(.body)

                Text(tr("השלמה: \(rate)%", "Completion: \(rate)%"))
                    .kmiTypography(.action)
                    .fontWeight(.bold)

                if !feedback.isEmpty {
                    Text(tr("הערה:", "Note:"))
                        .kmiTypography(.secondary)
                        .fontWeight(.bold)

                    Text(feedback)
                        .kmiTypography(.secondary)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)

        }
    }
}
