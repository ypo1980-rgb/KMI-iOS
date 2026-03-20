import SwiftUI
import Shared

struct BeltFinalExamView: View {

    let belt: Belt

    var body: some View {
        KmiExamRunnerView(
            title: "מבחן מסכם",
            subtitle: "חגורה \(belt.heb)",
            items: ExamDataSource.itemsForBelt(belt),
            accent: beltAccentColor(for: belt)
        )
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
