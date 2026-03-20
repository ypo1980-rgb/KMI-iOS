import SwiftUI
import Shared

struct InternalExamView: View {

    let belt: Belt
    @StateObject private var coach = CoachService.shared

    var body: some View {
        Group {
            if coach.isLoading {
                ProgressView("בודק הרשאות…")
            } else if coach.isCoach {
                KmiExamRunnerView(
                    title: "מבחן פנימי",
                    subtitle: "חגורה \(belt.heb)",
                    items: ExamDataSource.itemsForBelt(belt),
                    accent: beltAccentColor(for: belt)
                )
            } else {
                VStack(spacing: 10) {
                    Text("גישה למאמנים בלבד")
                        .font(.title3.weight(.heavy))
                    Text("ההרשאה נקבעת בשרת לפי מספר טלפון")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await coach.checkCoach()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func beltAccentColor(for belt: Belt) -> Color {
    switch belt {
    case .white: return Color.gray.opacity(0.55)
    case .yellow: return Color.orange.opacity(0.85)
    case .orange: return Color.orange.opacity(0.95)
    case .green: return Color.green.opacity(0.75)
    case .blue: return Color.blue.opacity(0.70)
    case .brown: return Color(red: 0.55, green: 0.35, blue: 0.20).opacity(0.85)
    case .black: return Color.black.opacity(0.75)
    default: return Color.black.opacity(0.25)
    }
}
