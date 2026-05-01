import SwiftUI
import Shared

struct SubjectSubTopicsView: View {
    let belt: Belt
    let subject: SubjectTopic
    let onPickSection: (String) -> Void

    private var isEnglish: Bool {
        UserDefaults.standard.string(forKey: "kmi_app_language")?.lowercased() == "en" ||
        UserDefaults.standard.string(forKey: "app_language")?.lowercased() == "english" ||
        UserDefaults.standard.string(forKey: "initial_language_code")?.lowercased() == "english"
    }

    private var subjectTitleText: String {
        let clean = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func sectionTitleText(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    var body: some View {
        let rawSections = SubjectItemsResolver.shared.resolveBySubject(
            belt: belt,
            subject: Shared.SubjectTopic(
                id: subject.id,
                titleHeb: subject.titleHeb,
                topicsByBelt: subject.topicsByBelt,
                subTopicHint: subject.subTopicHint,
                includeItemKeywords: subject.includeItemKeywords,
                requireAllItemKeywords: subject.requireAllItemKeywords,
                excludeItemKeywords: subject.excludeItemKeywords
            )
        )
        .filter { !$0.items.isEmpty }

        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                WhiteCard {
                    VStack(spacing: 12) {
                        Text(subjectTitleText)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            ForEach(rawSections, id: \.title) { sec in
                                SubjectPill(
                                    title: sectionTitleText(sec.title),
                                    subtitle: isEnglish
                                        ? (sec.items.count == 1 ? "1 exercise" : "\(sec.items.count) exercises")
                                        : "\(sec.items.count) תרגילים",
                                    fill: KmiBeltPalette.color(for: belt),
                                    isEnglish: isEnglish,
                                    onTap: {
                                        onPickSection(sec.title)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .navigationTitle(subjectTitleText)
        .navigationBarTitleDisplayMode(.inline)
    }
}
