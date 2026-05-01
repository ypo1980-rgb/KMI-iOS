import SwiftUI
import Shared

struct BeltTopicSubTopicsView: View {
    let belt: Belt
    let topicTitle: String
    let linkedSubjects: [SubjectTopic]
    let onPickAllTopic: () -> Void
    let onPickSubTopic: (String) -> Void
    let onPickLinkedSubject: (SubjectTopic) -> Void

    private struct UiSubTopic: Identifiable, Hashable {
        let id: String
        let title: String
        let itemsCount: Int
    }

    private var isEnglish: Bool {
        UserDefaults.standard.string(forKey: "kmi_app_language")?.lowercased() == "en" ||
        UserDefaults.standard.string(forKey: "app_language")?.lowercased() == "english" ||
        UserDefaults.standard.string(forKey: "initial_language_code")?.lowercased() == "english"
    }

    private func displayTitle(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let cleanTopicTitle = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let details = TopicsEngine.shared.topicDetailsFor(
            belt: belt,
            topicTitle: cleanTopicTitle
        )

        let uiSubTopics = details.subTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter {
                !$0.isEmpty &&
                $0 != cleanTopicTitle
            }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
            .map { subTitle in
                UiSubTopic(
                    id: "\(belt.id)::\(cleanTopicTitle)::\(subTitle)",
                    title: subTitle,
                    itemsCount: ContentRepo.shared.getAllItemsFor(
                        belt: belt,
                        topicTitle: cleanTopicTitle,
                        subTopicTitle: subTitle
                    ).count
                )
            }

        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                WhiteCard {
                    VStack(spacing: 12) {
                        Text(displayTitle(topicTitle))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            ForEach(linkedSubjects, id: \.id) { subject in
                                SubjectPill(
                                    title: displaySubjectTitle(subject),
                                    subtitle: nil,
                                    fill: KmiBeltPalette.color(for: belt),
                                    isEnglish: isEnglish,
                                    onTap: {
                                        onPickLinkedSubject(subject)
                                    }
                                )
                            }

                            ForEach(uiSubTopics) { subTopic in
                                SubjectPill(
                                    title: displayTitle(subTopic.title),
                                    subtitle: isEnglish
                                        ? (subTopic.itemsCount == 1 ? "1 exercise" : "\(subTopic.itemsCount) exercises")
                                        : "\(subTopic.itemsCount) תרגילים",
                                    fill: KmiBeltPalette.color(for: belt),
                                    isEnglish: isEnglish,
                                    onTap: {
                                        onPickSubTopic(subTopic.title)
                                    }
                                )
                            }

                            let directItems = ContentRepo.shared.getAllItemsFor(
                                belt: belt,
                                topicTitle: topicTitle,
                                subTopicTitle: nil
                            )

                            if !directItems.isEmpty {
                                SubjectPill(
                                    title: isEnglish ? "Full topic" : "כל התרגילים בנושא",
                                    subtitle: isEnglish
                                        ? (directItems.count == 1 ? "1 exercise" : "\(directItems.count) exercises")
                                        : "\(directItems.count) תרגילים",
                                    fill: KmiBeltPalette.color(for: belt),
                                    isEnglish: isEnglish,
                                    onTap: onPickAllTopic
                                )
                            } else if linkedSubjects.isEmpty && uiSubTopics.isEmpty && details.itemCount > 0 {
                                SubjectPill(
                                    title: isEnglish ? "Full topic" : "כל התרגילים בנושא",
                                    subtitle: isEnglish
                                        ? (Int(details.itemCount) == 1 ? "1 exercise" : "\(Int(details.itemCount)) exercises")
                                        : "\(Int(details.itemCount)) תרגילים",
                                    fill: KmiBeltPalette.color(for: belt),
                                    isEnglish: isEnglish,
                                    onTap: onPickAllTopic
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
        .navigationTitle(displayTitle(topicTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
