import SwiftUI
import Shared

struct LinkedTopicSubTopicsView: View {
    let title: String
    let subjects: [SubjectTopic]
    let onPickLinkedSubject: (SubjectTopic) -> Void

    private var isEnglish: Bool {
        UserDefaults.standard.string(forKey: "kmi_app_language")?.lowercased() == "en" ||
        UserDefaults.standard.string(forKey: "app_language")?.lowercased() == "english" ||
        UserDefaults.standard.string(forKey: "initial_language_code")?.lowercased() == "english"
    }

    private var displayTitle: String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func displaySubjectTitle(_ subject: SubjectTopic) -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        if let titleFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
            return titleFromId
        }

        return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                WhiteCard {
                    VStack(spacing: 12) {
                        Text(displayTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            ForEach(subjects, id: \.id) { subject in
                                SubjectPill(
                                    title: displaySubjectTitle(subject),
                                    subtitle: nil,
                                    fill: KmiBeltPalette.color(for: .orange),
                                    isEnglish: isEnglish,
                                    onTap: {
                                        onPickLinkedSubject(subject)
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
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
