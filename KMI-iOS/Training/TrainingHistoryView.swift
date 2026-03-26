import SwiftUI

struct TrainingHistoryView: View {

    @State private var sessions: [[String: Any]] = []

    var body: some View {
        ZStack {

            KmiGradientBackground()

            if sessions.isEmpty {

                VStack(spacing: 12) {
                    Text("אין היסטוריית אימונים")
                        .font(.system(size: 22, weight: .heavy))

                    Text("האימונים שתשמור יופיעו כאן")
                        .foregroundStyle(.secondary)
                }

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
        .navigationTitle("היסטוריית אימונים")
        .navigationBarTitleDisplayMode(.inline)
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

                Text("אימון")
                    .font(.system(size: 18, weight: .heavy))

                Text("משך: \(duration) דקות")

                Text("תרגילים: \(completed) / \(total)")

                Text("השלמה: \(rate)%")
                    .font(.system(size: 16, weight: .bold))

                if !feedback.isEmpty {
                    Text("הערה:")
                        .font(.system(size: 15, weight: .bold))

                    Text(feedback)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)

        }
    }
}
