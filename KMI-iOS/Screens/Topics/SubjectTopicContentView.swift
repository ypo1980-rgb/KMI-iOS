//
//  SubjectTopicContentView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 28/02/2026.
//
import SwiftUI
import Shared

struct SubjectTopicContentView: View {

    let belt: Belt
    let subject: SubjectTopic

    private let catalog = CatalogData.shared.data

    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.contains { t.contains(norm($0)) }
    }

    private func containsAll(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.allSatisfy { t.contains(norm($0)) }
    }

    private func containsNone(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return !keywords.contains { t.contains(norm($0)) }
    }

    private func itemPasses(_ item: String, subTopicTitle: String?) -> Bool {
        // בסיס
        let combined = (subTopicTitle ?? "") + " " + item

        // subTopicHint – אם יש, נדרוש התאמה בכותרת תת־נושא או בפריט
        if let hint = subject.subTopicHint, !hint.isEmpty {
            let ok = norm(subTopicTitle ?? "").contains(norm(hint)) || norm(item).contains(norm(hint))
            if !ok { return false }
        }

        // include OR
        if !subject.includeItemKeywords.isEmpty {
            if !containsAny(combined, keywords: subject.includeItemKeywords) { return false }
        }

        // requireAll AND
        if !containsAll(combined, keywords: subject.requireAllItemKeywords) { return false }

        // exclude
        if !containsNone(combined, keywords: subject.excludeItemKeywords) { return false }

        return true
    }

    private struct SectionPack: Identifiable {
        let id: String
        let title: String
        let items: [String]
    }

    private var sections: [SectionPack] {
        guard let beltContent = catalog[belt] else { return [] }

        let allowedTopics = subject.topicsByBelt[belt] ?? []
        let allowedKeys = Set(allowedTopics.map(norm))

        let candidateTopics: [CatalogData.Topic] =
            allowedTopics.isEmpty
            ? beltContent.topics
            : beltContent.topics.filter { topic in
                if allowedKeys.contains(norm(topic.title)) {
                    return true
                }

                return topic.subTopics.contains { subTopic in
                    allowedKeys.contains(norm(subTopic.title))
                }
            }

        var out: [SectionPack] = []

        for t in candidateTopics {
            // items ברמת topic
            let topItems = t.items.filter { itemPasses($0, subTopicTitle: t.title) }
            if !topItems.isEmpty {
                out.append(SectionPack(
                    id: "\(t.title)::items",
                    title: t.title,
                    items: topItems
                ))
            }

            // items ברמת subTopic
            for st in t.subTopics {
                let items = st.items.filter { itemPasses($0, subTopicTitle: st.title) }
                if !items.isEmpty {
                    out.append(SectionPack(
                        id: "\(t.title)::\(st.title)",
                        title: st.title,
                        items: items
                    ))
                }
            }
        }

        return out
    }

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 8) {
                            Text(subject.titleHeb)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("חגורה: \(belt.heb)")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)

                            // NOTE: description ב-Shared לפעמים נקרא description_.
                            // כרגע מורידים כדי לא להיתקע על שם שונה בין builds.
                            // נחזיר אחרי שנראה ב-autocomplete מה השם אצלך.
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    if sections.isEmpty {
                        WhiteCard {
                            Text("לא נמצאו תרגילים לנושא הזה בחגורה הזו")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 14)
                        }
                    } else {
                        ForEach(sections) { sec in
                            WhiteCard {
                                VStack(alignment: .leading, spacing: 10) {

                                    HStack {
                                        Text(sec.title)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.82))
                                        Spacer()
                                        Text("\(sec.items.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.55))
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(Array(sec.items.enumerated()), id: \.offset) { _, s in
                                            Text("• \(s)")
                                                .foregroundStyle(Color.black.opacity(0.82))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                        }
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("נושא")
        .navigationBarTitleDisplayMode(.inline)
    }
}
