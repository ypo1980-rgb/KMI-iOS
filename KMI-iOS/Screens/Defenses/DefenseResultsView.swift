//
//  DefenseResultsView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 28/02/2026.
//
import SwiftUI
import Shared

struct DefenseResultsView: View {
    let belt: Belt
    let topic: CatalogData.Topic
    let defenseKindLabel: String
    let attackTypeLabel: String

    // פונקציות התאמה זהות למה שיש ב-BeltQuestionsByTopicView (Swift-side זמני)
    private func isPunchText(_ text: String?) -> Bool {
        let s = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        return s.contains("אגרוף") || s.contains("אגרופים")
    }

    private func isKickText(_ text: String?) -> Bool {
        let s = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        return s.contains("בעיטה") || s.contains("בעיטות")
    }

    private func matchesAttack(subTopicTitle: String?, item: String) -> Bool {
        switch attackTypeLabel {
        case "אגרופים":
            return isPunchText(subTopicTitle) || isPunchText(item)
        case "בעיטות":
            return isKickText(subTopicTitle) || isKickText(item)
        default:
            return true
        }
    }

    private var matchedItems: [String] {
        var out: [String] = []

        for st in topic.subTopics {
            for it in st.items where matchesAttack(subTopicTitle: st.title, item: it) {
                out.append(it)
            }
        }

        for it in topic.items where matchesAttack(subTopicTitle: topic.title, item: it) {
            out.append(it)
        }

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ZStack {
            DefenseResultsGradientBackground()

            ScrollView {
                VStack(spacing: 12) {

                    WhiteCard {
                        VStack(spacing: 8) {
                            Text(topic.title)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("חגורה: \(belt.heb) • \(defenseKindLabel) / \(attackTypeLabel)")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("נמצאו \(matchedItems.count) תרגילים מתאימים")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    WhiteCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(matchedItems.enumerated()), id: \.offset) { _, s in
                                Text("• \(s)")
                                    .foregroundStyle(Color.black.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if matchedItems.isEmpty {
                                Text("אין תרגילים מתאימים למסנן הזה")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 14)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
        }
        .navigationTitle("תוצאות")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DefenseResultsGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.06, blue: 0.25),
                Color(red: 0.20, green: 0.12, blue: 0.55),
                Color(red: 0.08, green: 0.44, blue: 0.86),
                Color(red: 0.10, green: 0.80, blue: 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
