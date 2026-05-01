import SwiftUI
import Shared

struct SubjectExercisesView: View {
    let route: BeltQuestionsByBeltView.SubjectSectionExerciseRoute

    @EnvironmentObject private var nav: AppNavModel

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

    private func beltTitle(_ belt: Belt) -> String {
        if !isEnglish {
            return belt.heb
        }

        switch belt {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .green: return "Green"
        case .blue: return "Blue"
        case .brown: return "Brown"
        case .black: return "Black"
        default: return belt.heb
        }
    }

    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return count == 1 ? "1 exercise" : "\(count) exercises"
        } else {
            return count == 1 ? "תרגיל 1" : "\(count) תרגילים"
        }
    }

    private var screenTitleText: String {
        let sectionClean = route.sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectIdClean = route.subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectTitleClean = route.subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else {
            return sectionClean.isEmpty ? subjectTitleClean : sectionClean
        }

        if let sectionTitle = KmiEnglishTitleResolver.englishTitle(for: sectionClean) {
            return sectionTitle
        }

        if let subjectIdTitle = KmiEnglishTitleResolver.englishTitle(for: subjectIdClean) {
            return subjectIdTitle
        }

        return KmiEnglishTitleResolver.title(for: subjectTitleClean, isEnglish: true)
    }

    private typealias Mark = KmiExerciseMark

    @State private var marksCache: [String: Mark?] = [:]

    private func markKey(item: String) -> String {
        let b = route.belt.id
        let t = route.subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = route.sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.mark.\(b).\(t).\(s).\(i)"
    }

    private func loadMark(item: String) -> Mark? {
        let key = markKey(item: item)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return Mark(rawValue: raw)
    }

    private func setMark(_ mark: Mark?, item: String) {
        let key = markKey(item: item)
        if let mark {
            UserDefaults.standard.set(mark.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func currentMark(for item: String) -> Mark? {
        if let cached = marksCache[item] { return cached }
        return loadMark(item: item)
    }

    private func toggleMark(_ mark: Mark, item: String) {
        let cur = currentMark(for: item)
        let next: Mark? = (cur == mark) ? nil : mark
        setMark(next, item: item)
        marksCache[item] = next
    }

    private func extractDisplayName(from value: Any) -> String? {
        let mirror = Mirror(reflecting: value)

        if let display = mirror.children.first(where: { $0.label == "displayName" })?.value as? String {
            let trimmed = display.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let text = String(describing: value)
        guard let r = text.range(of: "displayName=") else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let tail = text[r.upperBound...]
        let end = tail.firstIndex(of: ",") ?? tail.endIndex
        let name = String(tail[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private var allItems: [String] {
        let section = SubjectItemsResolver.shared.resolveBySubject(
            belt: route.belt,
            subject: Shared.SubjectTopic(
                id: route.subject.id,
                titleHeb: route.subject.titleHeb,
                topicsByBelt: route.subject.topicsByBelt,
                subTopicHint: route.subject.subTopicHint,
                includeItemKeywords: route.subject.includeItemKeywords,
                requireAllItemKeywords: route.subject.requireAllItemKeywords,
                excludeItemKeywords: route.subject.excludeItemKeywords
            )
        )
        .first(where: { $0.title == route.sectionTitle })

        var seen = Set<String>()

        return (section?.items ?? [])
            .compactMap { extractDisplayName(from: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    var body: some View {
        KmiRootLayout(
            title: screenTitleText,
            nav: nav,
            roleLabel: isEnglish ? "Trainee\nMode" : "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: isEnglish
                ? "\(beltTitle(route.belt)) Belt • \(allItems.count)"
                : "חגורה \(route.belt.heb) • \(allItems.count)",
            titleColor: KmiBeltPalette.color(for: route.belt)
        ) {
            ZStack {
                KmiGradientBackground(forceTraineeStyle: false)

                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(spacing: 6) {
                                Text(
                                    isEnglish
                                    ? "Belt: \(beltTitle(route.belt)) • \(exercisesCountText(allItems.count))"
                                    : "חגורה: \(route.belt.heb) • \(exercisesCountText(allItems.count))"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        WhiteCard {
                            VStack(spacing: 0) {
                                ForEach(Array(allItems.enumerated()), id: \.offset) { idx, item in
                                    KmiExerciseMarkRow(
                                        title: uiExerciseTitle(item),
                                        mark: currentMark(for: item),
                                        isEnglish: isEnglish,
                                        onMarkDone: { toggleMark(.done, item: item) },
                                        onMarkNotDone: { toggleMark(.notDone, item: item) }
                                    )

                                    if idx != allItems.count - 1 {
                                        Divider().opacity(0.25)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 18)
                    }
                    .padding(.bottom, 120)
                }
            }
        }
    }
}
