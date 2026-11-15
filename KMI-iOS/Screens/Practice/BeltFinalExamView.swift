import SwiftUI
import Shared

struct BeltFinalExamView: View {

    let belt: Belt
    @EnvironmentObject private var nav: AppNavModel
    @AppStorage("kmi_app_language") private var languageCode = "he"

    private var isEnglish: Bool {
        let code = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return code == "en" || code == "english"
    }

    private var beltSubtitle: String {
        guard isEnglish else { return "חגורה \(belt.heb)" }

        switch belt {
        case .white: return "White Belt"
        case .yellow: return "Yellow Belt"
        case .orange: return "Orange Belt"
        case .green: return "Green Belt"
        case .blue: return "Blue Belt"
        case .brown: return "Brown Belt"
        case .black: return "Black Belt"
        default: return belt.heb
        }
    }

    var body: some View {
        KmiExamRunnerView(
            belt: belt,
            title: isEnglish ? "Final Exam" : "מבחן מסכם",
            subtitle: beltSubtitle,
            items: ExamDataSource.itemsForBelt(belt),
            accent: KmiBeltPalette.color(for: belt),
            onFinish: {
                nav.pop()
            }
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(
            .hidden,
            for: .navigationBar
        )
    }
}
