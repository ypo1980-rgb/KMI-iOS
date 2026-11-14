import SwiftUI
import Shared

struct BeltFinalExamView: View {

    let belt: Belt
    @EnvironmentObject private var nav: AppNavModel

    var body: some View {
        KmiExamRunnerView(
            belt: belt,
            title: "מבחן מסכם",
            subtitle: "חגורה \(belt.heb)",
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
