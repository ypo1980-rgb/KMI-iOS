import SwiftUI
import Shared

struct BeltTopicExercisesView: View {
    let belt: Belt
    let topicTitle: String
    let forcedSubTopicTitle: String?

    private var isEnglish: Bool {
        UserDefaults.standard.string(forKey: "kmi_app_language")?.lowercased() == "en" ||
        UserDefaults.standard.string(forKey: "app_language")?.lowercased() == "english" ||
        UserDefaults.standard.string(forKey: "initial_language_code")?.lowercased() == "english"
    }

    private func uiTopicTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func uiExerciseTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    @State private var marksCache: [String: KmiExerciseMark?] = [:]

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [String]
    }

    private var sections: [UiSection] {
        let cleanTopic = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let details = TopicsEngine.shared.topicDetailsFor(
            belt: belt,
            topicTitle: cleanTopic
        )

        let cleanSubs = details.subTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != cleanTopic }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }

        if let forcedSubTopicTitle, !forcedSubTopicTitle.isEmpty {
            let items = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanTopic,
                subTopicTitle: forcedSubTopicTitle
            )

            guard !items.isEmpty else { return [] }

            return [
                UiSection(
                    id: "\(cleanTopic)::\(forcedSubTopicTitle)",
                    title: forcedSubTopicTitle,
                    items: items
                )
            ]
        }

        if cleanSubs.isEmpty {
            let items = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanTopic,
                subTopicTitle: nil
            )

            guard !items.isEmpty else { return [] }

            return [
                UiSection(
                    id: "\(cleanTopic)::__all__",
                    title: cleanTopic,
                    items: items
                )
            ]
        }

        return cleanSubs.map { subTitle in
            let items = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanTopic,
                subTopicTitle: subTitle
            )

            return UiSection(
                id: "\(cleanTopic)::\(subTitle)",
                title: subTitle,
                items: items
            )
        }
    }

    private func markKey(sectionTitle: String, item: String) -> String {
        let b = belt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.mark.\(b).\(t).\(s).\(i)"
    }

    private func loadMark(sectionTitle: String, item: String) -> KmiExerciseMark? {
        let key = markKey(sectionTitle: sectionTitle, item: item)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return KmiExerciseMark(rawValue: raw)
    }

    private func setMark(_ mark: KmiExerciseMark?, sectionTitle: String, item: String) {
        let key = markKey(sectionTitle: sectionTitle, item: item)
        if let mark {
            UserDefaults.standard.set(mark.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func currentMark(sectionTitle: String, item: String) -> KmiExerciseMark? {
        let cacheKey = "\(sectionTitle)::\(item)"
        if let cached = marksCache[cacheKey] { return cached }
        return loadMark(sectionTitle: sectionTitle, item: item)
    }

    private func toggleMark(_ mark: KmiExerciseMark, sectionTitle: String, item: String) {
        let cacheKey = "\(sectionTitle)::\(item)"
        let cur = currentMark(sectionTitle: sectionTitle, item: item)
        let next: KmiExerciseMark? = (cur == mark) ? nil : mark
        setMark(next, sectionTitle: sectionTitle, item: item)
        marksCache[cacheKey] = next
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sections) { sec in
                        WhiteCard {
                            VStack(
                                alignment: isEnglish ? .leading : .trailing,
                                spacing: 12
                            ) {
                                Text(uiTopicTitle(sec.title))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: isEnglish ? .leading : .trailing
                                    )
                                    .multilineTextAlignment(isEnglish ? .leading : .trailing)

                                VStack(spacing: 0) {
                                    ForEach(Array(sec.items.enumerated()), id: \.offset) { idx, item in
                                        KmiExerciseMarkRow(
                                            title: uiExerciseTitle(item),
                                            mark: currentMark(sectionTitle: sec.title, item: item),
                                            isEnglish: isEnglish,
                                            onMarkDone: {
                                                toggleMark(.done, sectionTitle: sec.title, item: item)
                                            },
                                            onMarkNotDone: {
                                                toggleMark(.notDone, sectionTitle: sec.title, item: item)
                                            }
                                        )

                                        if idx != sec.items.count - 1 {
                                            Divider().opacity(0.25)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle(uiTopicTitle(topicTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
