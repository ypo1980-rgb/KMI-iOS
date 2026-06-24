import SwiftUI
import Combine
import Shared

// ✅ CONTENT-ONLY: אין כאן TopBar ואין כאן IconStrip ואין כאן DrawerContainer
struct BeltQuestionsByBeltView: View {
    
    let belt: Belt
    
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    
    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        
        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }
            
            if clean == "en" || clean == "english" {
                return "en"
            }
        }
        
        return "he"
    }
    
    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }
    
    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private func uiTopicTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }
    
    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return count == 1 ? "1 exercise" : "\(count) exercises"
        } else {
            return count == 1 ? "תרגיל 1" : "\(count) תרגילים"
        }
    }
    
    private func subTopicsAndExercisesText(subTopicsCount: Int, exercisesCount: Int) -> String {
        if isEnglish {
            let subText = subTopicsCount == 1 ? "1 subtopic" : "\(subTopicsCount) subtopics"
            return "\(subText)  •  \(exercisesCountText(exercisesCount))"
        } else {
            return "\(subTopicsCount) תתי נושאים  •  \(exercisesCountText(exercisesCount))"
        }
    }
    
    private func beltDisplayTitle(_ belt: Belt) -> String {
        if !isEnglish {
            return belt.heb
        }
        
        switch belt {
        case .white:
            return "White"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .brown:
            return "Brown"
        case .black:
            return "Black"
        default:
            return belt.heb
        }
    }
    
    @State private var selectedExerciseRoute: BeltTopicExerciseRoute? = nil
    @State private var selectedLinkedTopicRoute: LinkedTopicRoute? = nil
    @State private var selectedTopicSubTopicsRoute: BeltTopicSubTopicsRoute? = nil
    
    // ✅ subject-based flow כמו באנדרואיד:
    @State private var selectedSubjectForSubTopics: SubjectTopic? = nil
    @State private var selectedSubjectSectionRoute: SubjectSectionExerciseRoute? = nil
    
    // ✅ NEW: nav גלובאלי (כדי לנווט למסכים עטופים ב-KmiRootLayout)
    @EnvironmentObject private var nav: AppNavModel
    @StateObject private var coach = CoachService.shared
    // ✅ החגורות שמציגים בגלגל (ללא לבנה)
    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
    private let catalog = CatalogData.shared.data
    
    // ✅ החגורה שנבחרה בפועל במסך
    @State private var selectedBelt: Belt = .orange
    @State private var byTopicActiveBelt: Belt = .orange
    @State private var didInitializeSelectedBelt: Bool = false
    @State private var tab: Tab = .byBelt
    @State private var quickMenuOpen: Bool = false
    @State private var expandedTopic: String? = nil
    @State private var accessRefreshTick: Int = 0
    
    // Global search
    @State private var pickedExercise: ExerciseSelection? = nil
    
    // ✅ Android parity:
    // באנדרואיד מצב הגישה מתרענן גם בלי שינוי SharedPreferences,
    // כדי שמנוי שפג יחזיר מנעולים כשהמשתמש נשאר במסך.
    private let accessRefreshTimer = Timer
        .publish(every: 30, on: .main, in: .common)
        .autoconnect()
    
    private struct BeltTopicExerciseRoute: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let topicTitle: String
        let forcedSubTopicTitle: String?
        
        init(belt: Belt, topicTitle: String, forcedSubTopicTitle: String? = nil) {
            self.belt = belt
            self.topicTitle = topicTitle
            self.forcedSubTopicTitle = forcedSubTopicTitle
            self.id = "\(belt.id)::\(topicTitle)::\(forcedSubTopicTitle ?? "__ALL__")"
        }
    }
    
    struct SubjectSectionExerciseRoute: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let subject: SubjectTopic
        let sectionTitle: String
        
        init(belt: Belt, subject: SubjectTopic, sectionTitle: String) {
            self.belt = belt
            self.subject = subject
            self.sectionTitle = sectionTitle
            self.id = "\(belt.id)::\(subject.id)::\(sectionTitle)"
        }
    }
    
    private struct LinkedTopicRoute: Identifiable, Hashable {
        let id: String
        let title: String
        let subjects: [SubjectTopic]
        
        init(title: String, subjects: [SubjectTopic]) {
            self.title = title
            self.subjects = subjects
            self.id = "linked-topic::\(title)"
        }
    }
    
    private struct BeltTopicSubTopicsRoute: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let topicTitle: String
        let linkedSubjects: [SubjectTopic]
        
        init(belt: Belt, topicTitle: String, linkedSubjects: [SubjectTopic]) {
            self.belt = belt
            self.topicTitle = topicTitle
            self.linkedSubjects = linkedSubjects
            self.id = "topic-subtopics::\(belt.id)::\(topicTitle)"
        }
    }
    
    private struct BeltTopicUi: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let linkedSubjects: [SubjectTopic]
    }
    
    private struct TopicDetailsUi {
        let itemCount: Int
        let subTitles: [String]
    }
    
    private func topicDetailsFor(belt: Belt, topicTitle: String) -> TopicDetailsUi {
        let details = TopicsEngine.shared.topicDetailsFor(
            belt: belt,
            topicTitle: topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        let topicTrim = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanSubs = details.subTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != topicTrim }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
        
        return TopicDetailsUi(
            itemCount: Int(details.itemCount),
            subTitles: cleanSubs
        )
    }
    
    private func hasRealSubTopicsForUi(title: String, details: TopicDetailsUi) -> Bool {
        let topicTrim = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return details.subTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0 != topicTrim }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
            .isEmpty == false
    }
    
    private func topicPriorityRankForUi(
        belt: Belt,
        title: String,
        details: TopicDetailsUi
    ) -> Int {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRealSubs = hasRealSubTopicsForUi(title: title, details: details)
        
        // Android source of truth:
        // Yellow: defenses first, releases second, hand work after them.
        if belt == .yellow {
            if clean.contains("הגנות") { return 0 }
            if clean.contains("שחרורים") { return 1 }
            if clean.contains("עבודת ידיים") { return 2 }
            if hasRealSubs { return 3 }
            return 10
        }
        
        // Android exception:
        // Brown belt "שחרורים" is a regular single-topic item,
        // not a locked / grouped subtopic section.
        if belt == .brown && clean.contains("שחרורים") {
            return 10
        }
        
        if hasRealSubs { return 0 }
        if clean.contains("הגנות") { return 1 }
        if clean.contains("שחרורים") { return 2 }
        
        return 10
    }
    
    private var beltTopicsUi: [BeltTopicUi] {
        let rawTopicTitles = TopicsEngine.shared.topicTitlesFor(belt: selectedBelt)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }
        
        let detailsByTitle: [String: TopicDetailsUi] = Dictionary(
            uniqueKeysWithValues: rawTopicTitles.map { title in
                (title, topicDetailsFor(belt: selectedBelt, topicTitle: title))
            }
        )
        
        let topicTitles = rawTopicTitles
            .enumerated()
            .sorted { lhs, rhs in
                let lhsDetails = detailsByTitle[lhs.element] ?? TopicDetailsUi(itemCount: 0, subTitles: [])
                let rhsDetails = detailsByTitle[rhs.element] ?? TopicDetailsUi(itemCount: 0, subTitles: [])
                
                let lhsRank = topicPriorityRankForUi(
                    belt: selectedBelt,
                    title: lhs.element,
                    details: lhsDetails
                )
                
                let rhsRank = topicPriorityRankForUi(
                    belt: selectedBelt,
                    title: rhs.element,
                    details: rhsDetails
                )
                
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
        
        return topicTitles.map { title in
            let details = detailsByTitle[title] ?? TopicDetailsUi(itemCount: 0, subTitles: [])
            let subCount = details.subTitles.count
            let itemCount = details.itemCount
            
            let subtitle: String? = {
                if subCount > 0 {
                    return subTopicsAndExercisesText(
                        subTopicsCount: subCount,
                        exercisesCount: itemCount
                    )
                } else {
                    return exercisesCountText(itemCount)
                }
            }()
            
            return BeltTopicUi(
                id: "belt-topic::\(selectedBelt.id)::\(title)",
                title: title,
                subtitle: subtitle,
                linkedSubjects: []
            )
        }
    }
    
    @State private var practiceTokenFromLists: String = "__ALL__"
    
    private enum Tab {
        case byBelt
        case byTopic
    }

    private var quickMenuBelt: Belt {
        tab == .byTopic ? byTopicActiveBelt : selectedBelt
    }

    private var screenTitleForMode: String {
        if tab == .byTopic {
            return isEnglish ? "Exercises by Topic" : "תרגילים לפי נושא"
        }

        return beltDisplayTitle(selectedBelt)
    }

    private var beltScreenQuickMenuItems: [BeltScreenQuickMenuItem] {
        var items: [BeltScreenQuickMenuItem] = []

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "Weak Points" : "נקודות תורפה",
                systemImage: "exclamationmark.triangle.fill"
            ) {
                if LockedContentPolicy.shouldShowLock(
                    accessMode: LockedContentPolicy.currentAccessMode(),
                    title: isEnglish ? "Weak Points" : "נקודות תורפה"
                ) {
                    nav.push(.subscriptionPlans)
                } else {
                    nav.push(.weakPoints(belt: quickMenuBelt))
                }
            }
        )

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "All Lists" : "כל הרשימות",
                systemImage: "list.bullet.rectangle.fill"
            ) {
                if LockedContentPolicy.shouldShowLock(
                    accessMode: LockedContentPolicy.currentAccessMode(),
                    title: isEnglish ? "All Lists" : "כל הרשימות"
                ) {
                    nav.push(.subscriptionPlans)
                } else {
                    nav.push(.allLists(belt: quickMenuBelt))
                }
            }
        )

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "Practice" : "תרגול",
                systemImage: "figure.martial.arts"
            ) {
                if LockedContentPolicy.shouldShowLock(
                    accessMode: LockedContentPolicy.currentAccessMode(),
                    title: isEnglish ? "Practice" : "תרגול"
                ) {
                    nav.push(.subscriptionPlans)
                } else {
                    practiceTokenFromLists = "__ALL__"
                    nav.push(.practice(belt: quickMenuBelt, topicTitle: "__ALL__"))
                }
            }
        )

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "Summary" : "מסך סיכום",
                systemImage: "chart.bar.doc.horizontal"
            ) {
                if LockedContentPolicy.shouldShowLock(
                    accessMode: LockedContentPolicy.currentAccessMode(),
                    title: isEnglish ? "Summary" : "מסך סיכום"
                ) {
                    nav.push(.subscriptionPlans)
                } else {
                    nav.push(.summary(belt: quickMenuBelt))
                }
            }
        )

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                systemImage: "mic.fill"
            ) {
                nav.push(.voiceAssistant)
            }
        )

        items.append(
            BeltScreenQuickMenuItem(
                title: isEnglish ? "Final Exam" : "מבחן מסכם",
                systemImage: "checkmark.seal.fill"
            ) {
                if LockedContentPolicy.shouldShowLock(
                    accessMode: LockedContentPolicy.currentAccessMode(),
                    title: isEnglish ? "Final Exam" : "מבחן מסכם"
                ) {
                    nav.push(.subscriptionPlans)
                } else {
                    nav.push(.beltFinalExam(belt: quickMenuBelt))
                }
            }
        )

        if coach.isCoach {
            items.append(
                BeltScreenQuickMenuItem(
                    title: isEnglish ? "Internal Exam" : "מבחן פנימי",
                    systemImage: "checklist"
                ) {
                    nav.push(.internalExam(belt: quickMenuBelt))
                }
            )
        }

        return items
    }
    
    private func beltFromStoredId(_ raw: String?) -> Belt? {
        let clean = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        switch clean {
        case "white", "לבן", "לבנה", "חגורה לבנה":
            return Belt.white
        case "yellow", "צהוב", "צהובה", "חגורה צהובה":
            return Belt.yellow
        case "orange", "כתום", "כתומה", "חגורה כתומה":
            return Belt.orange
        case "green", "ירוק", "ירוקה", "חגורה ירוקה":
            return Belt.green
        case "blue", "כחול", "כחולה", "חגורה כחולה":
            return Belt.blue
        case "brown", "חום", "חומה", "חגורה חומה":
            return Belt.brown
        case "black", "שחור", "שחורה", "חגורה שחורה":
            return Belt.black
        default:
            return nil
        }
    }
    
    private func nextBelt(after registered: Belt) -> Belt {
        guard let currentIndex = belts.firstIndex(of: registered) else {
            return Belt.orange
        }
        
        if currentIndex >= belts.count - 1 {
            return belts.first ?? Belt.orange
        }
        
        return belts[currentIndex + 1]
    }
    
    private func initialBeltLikeAndroid(defaults: UserDefaults = .standard) -> Belt {
        let storedRaw =
            defaults.string(forKey: "current_belt") ??
            defaults.string(forKey: "belt_current")
        
        guard let registeredBelt = beltFromStoredId(storedRaw),
              registeredBelt != Belt.white else {
            return Belt.orange
        }
        
        return nextBelt(after: registeredBelt)
    }
    
    private func toSharedSubject(_ local: SubjectTopic) -> Shared.SubjectTopic {
        Shared.SubjectTopic(
            id: local.id,
            titleHeb: local.titleHeb,
            topicsByBelt: local.topicsByBelt,
            subTopicHint: local.subTopicHint,
            includeItemKeywords: local.includeItemKeywords,
            requireAllItemKeywords: local.requireAllItemKeywords,
            excludeItemKeywords: local.excludeItemKeywords
        )
    }
    
    private func allItemsForSelectedBelt() -> [(topicTitle: String, item: String)] {
        guard let topics = catalog[selectedBelt]?.topics else { return [] }
        
        var result: [(String, String)] = []
        
        for t in topics {
            for it in t.items { result.append((t.title, it)) }
            for st in t.subTopics {
                for it in st.items { result.append((t.title, it)) }
            }
        }
        return result
    }
    
    private func practiceItemsForCurrentToken() -> [String] {
        let token = practiceTokenFromLists.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if token.isEmpty || token == "__ALL__" {
            return allItemsForSelectedBelt().map { $0.item }
        }
        
        return ContentRepo.shared.getAllItemsFor(
            belt: selectedBelt,
            topicTitle: token,
            subTopicTitle: nil
        )
    }
    
    private func isDone(topicTitle: String, item: String) -> Bool {
        let b = selectedBelt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "kmi.exercise.\(b).\(t).\(i).done"
        
        if UserDefaults.standard.object(forKey: key) == nil { return false }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    private var beltProgress: (done: Int, total: Int) {
        let all = allItemsForSelectedBelt()
        let doneCount = all.filter { isDone(topicTitle: $0.topicTitle, item: $0.item) }.count
        return (doneCount, all.count)
    }
    
    private func topicAccentColor(_ topicTitle: String) -> Color {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.contains("הגנות") || clean.lowercased().contains("defense") {
            return Color.green.opacity(0.86)
        }
        
        if clean.contains("שחרור") || clean.lowercased().contains("release") {
            return Color.blue.opacity(0.78)
        }
        
        if clean.contains("יד") || clean.contains("אגרוף") || clean.contains("מרפק") {
            return Color.red.opacity(0.78)
        }
        
        if clean.contains("בעיטה") || clean.contains("בעיטות") {
            return Color.orange.opacity(0.86)
        }
        
        if clean.contains("בלימות") || clean.contains("גלגולים") {
            return Color.purple.opacity(0.78)
        }
        
        if clean.contains("קרקע") {
            return Color.orange.opacity(0.80)
        }
        
        if clean.contains("קאוול") {
            return Color.gray.opacity(0.70)
        }
        
        return BeltPaletteByBeltScreen.color(for: selectedBelt)
    }
    
    private func topicImageName(_ topicTitle: String) -> String? {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        if clean.contains("הגנות") || lower.contains("defense") || lower.contains("defenses") {
            return "topic_defenses"
        }
        
        if clean.contains("שחרור") ||
            clean.contains("שחרורים") ||
            lower.contains("release") ||
            lower.contains("releases") {
            return "topic_releases"
        }
        
        if clean.contains("עבודת ידיים") ||
            clean.contains("עבודת יד") ||
            clean.contains("מכות ידיים") ||
            clean.contains("מכות יד") ||
            lower.contains("hand") ||
            lower.contains("hands") {
            return "topic_hand_strikes"
        }
        
        if clean.contains("מכות מרפק") ||
            clean.contains("מרפק") ||
            lower.contains("elbow") ||
            lower.contains("elbows") {
            return "topic_elbow_strikes"
        }
        
        if clean.contains("בעיטה") ||
            clean.contains("בעיטות") ||
            lower.contains("kick") ||
            lower.contains("kicks") {
            return "topic_kicks"
        }
        
        if clean.contains("בלימות") ||
            clean.contains("גלגולים") ||
            clean.contains("גלגול") ||
            clean.contains("בלימה") ||
            lower.contains("breakfall") ||
            lower.contains("roll") {
            return "topic_breakfalls_rolls"
        }
        
        if clean.contains("עמידת מוצא") ||
            lower.contains("ready stance") ||
            lower.contains("stance") {
            return "topic_ready_stance"
        }
        
        if clean.contains("קרקע") ||
            lower.contains("ground") {
            return "topic_ground_fighting"
        }
        
        if clean.contains("קוואלר") ||
            clean.contains("קאוולר") ||
            clean.contains("קאוול") ||
            lower.contains("cavalier") ||
            lower.contains("kavaler") {
            return "topic_cavalier"
        }
        
        if clean.contains("כללי") ||
            lower.contains("general") {
            return "topic_general"
        }
        
        return nil
    }
    
    private func topicSymbolName(_ topicTitle: String) -> String {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        
        if clean.contains("הגנות") || lower.contains("defense") {
            return "shield.fill"
        }
        
        if clean.contains("שחרור") || lower.contains("release") {
            return "hand.raised.fill"
        }
        
        if clean.contains("יד") || clean.contains("אגרוף") || clean.contains("מרפק") {
            return "hand.tap.fill"
        }
        
        if clean.contains("בעיטה") || clean.contains("בעיטות") {
            return "figure.kickboxing"
        }
        
        if clean.contains("בלימות") || clean.contains("גלגולים") {
            return "arrow.triangle.2.circlepath"
        }
        
        if clean.contains("קרקע") {
            return "figure.wrestling"
        }
        
        if clean.contains("קאוול") {
            return "list.bullet.rectangle.fill"
        }
        
        return "list.bullet.rectangle.fill"
    }
    
    private func isTopicLocked(_ topicTitle: String) -> Bool {
        let _ = accessRefreshTick
        
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = topicDetailsFor(belt: selectedBelt, topicTitle: clean)
        
        // Android exception:
        // Brown belt "שחרורים" with no real subtopics and up to one item
        // stays a regular open topic.
        if selectedBelt == .brown &&
            clean.contains("שחרורים") &&
            details.subTitles.isEmpty &&
            details.itemCount <= 1 {
            return false
        }
        
        let accessMode = LockedContentPolicy.currentAccessMode()
        
        return LockedContentPolicy.shouldShowLock(
            accessMode: accessMode,
            title: clean
        )
    }
    
    private func openTopicFromByBelt(
        topicTitle: String,
        hasSubs: Bool,
        isExpanded: Bool
    ) {
        if isTopicLocked(topicTitle) {
            nav.push(.subscriptionPlans)
            return
        }
        
        if hasSubs {
            withAnimation(.easeInOut(duration: 0.22)) {
                expandedTopic = isExpanded ? nil : topicTitle
            }
        } else {
            selectedExerciseRoute = BeltTopicExerciseRoute(
                belt: selectedBelt,
                topicTitle: topicTitle
            )
        }
    }
   
    @ViewBuilder
    private func navigationChevron(
        hasSubs: Bool,
        isExpanded: Bool,
        isEnglish: Bool
    ) -> some View {
        if hasSubs {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.42))
                .frame(width: 20)
        } else {
            Image(systemName: isEnglish ? "chevron.right" : "chevron.left")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.30))
                .frame(width: 20)
        }
    }
    
    private func topicTextBlock(
        title: String,
        subtitle: String?,
        isEnglish: Bool
    ) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 3) {
            Text(uiTopicTitle(title))
                .font(.system(size: 15.5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.48))
                    .frame(
                        maxWidth: .infinity,
                        alignment: isEnglish ? .leading : .trailing
                    )
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }
    
    private func topicIconBox(
        topicTitle: String,
        accent: Color
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            if let imageName = topicImageName(topicTitle) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: topicSymbolName(topicTitle))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(accent)
            }
        }
        .frame(width: 42, height: 42)
    }
    
    private func topicAccentStrip(_ accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(1.0),
                        accent.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: 34)
    }
    
    private var quickViewButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                quickMenuOpen = true
            }
        } label: {
            let beltColor = BeltPaletteByBeltScreen.color(for: selectedBelt)
            
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .black))
                
                Text(isEnglish ? "Quick View" : "מבט מהיר")
                    .font(.system(size: 17, weight: .black))
            }
            .foregroundStyle(beltColor)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                beltColor.opacity(0.10),
                                Color.white.opacity(0.98),
                                beltColor.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(beltColor.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            if tab == .byTopic {
                BeltQuestionsByTopicView(
                    belt: selectedBelt,
                    embeddedMode: true,
                    onSwitchToByBelt: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                            quickMenuOpen = false
                            tab = .byBelt
                        }

                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                                object: screenTitleForMode
                            )
                        }
                    },
                    onActiveBeltChange: { activeBelt in
                        byTopicActiveBelt = activeBelt
                    }
                )
                .onAppear {
                    byTopicActiveBelt = selectedBelt
                }
                .transition(.opacity)
            } else {
                byBeltContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: tab)
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()
            
            tabContent
            
            if tab == .byBelt {
                GeometryReader { geo in
                    let isCompactHeight = geo.size.height < 760
                    let pickerWidth: CGFloat = isCompactHeight ? 292 : 304
                    let pickerHeight: CGFloat = isCompactHeight ? 108 : 114
                    let pickerOffsetY: CGFloat = isCompactHeight ? 16 : 12
                    
                    VStack {
                        Spacer()
                        
                        BeltArcPicker(
                            belts: belts,
                            selectedBelt: $selectedBelt,
                            isEnglish: isEnglish
                        )
                        .frame(width: pickerWidth, height: pickerHeight)
                        .offset(y: pickerOffsetY)
                        .padding(.bottom, 0)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                }
                .zIndex(2.2)
                .allowsHitTesting(!quickMenuOpen)
            }
            
            BeltScreenSideQuickMenuOverlay(
                isPresented: $quickMenuOpen,
                isEnglish: isEnglish,
                items: beltScreenQuickMenuItems,
                onClose: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        quickMenuOpen = false
                    }
                }
            )
            .zIndex(1200)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            quickMenuOpen = false

            guard !didInitializeSelectedBelt else {
                NotificationCenter.default.post(
                    name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                    object: screenTitleForMode
                )
                return
            }

            // Android parity:
            // כניסה ראשונה למסך דרך מסך הבית מתחילה במצב לפי חגורה.
            tab = .byBelt
            expandedTopic = nil

            // Android parity:
            // אם אין חגורה רשומה / המשתמש לבנה — מתחילים מכתומה.
            // אחרת מתחילים מהחגורה הבאה אחרי החגורה הרשומה.
            selectedBelt = initialBeltLikeAndroid()
            byTopicActiveBelt = selectedBelt

            didInitializeSelectedBelt = true

            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: screenTitleForMode
            )
        }
        .onChange(of: selectedBelt) { _, newValue in
            expandedTopic = nil
            
            if tab == .byBelt {
                byTopicActiveBelt = newValue
            }
            
            if quickMenuOpen {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                    quickMenuOpen = false
                }
            }

            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: screenTitleForMode
            )
        }
        .onChange(of: tab) { _, _ in
            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: screenTitleForMode
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_GLOBAL_SEARCH_PICK")
            )
        ) { notif in
            guard let key = notif.object as? String else { return }
            pickedExercise = ExerciseSelection.fromSearchKey(key)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_ACCESS_CHANGED")
            )
        ) { _ in
            accessRefreshTick += 1
        }
        .onReceive(accessRefreshTimer) { _ in
            accessRefreshTick += 1
        }
        .onDisappear {
            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: ""
            )
        }
        .navigationDestination(item: $selectedLinkedTopicRoute) { route in
            LinkedTopicSubTopicsView(
                title: route.title,
                subjects: route.subjects,
                onPickLinkedSubject: { subject in
                    selectedSubjectForSubTopics = subject
                }
            )
        }
        .navigationDestination(item: $selectedTopicSubTopicsRoute) { route in
            BeltTopicSubTopicsView(
                belt: route.belt,
                topicTitle: route.topicTitle,
                linkedSubjects: route.linkedSubjects,
                onPickAllTopic: {
                    selectedExerciseRoute = BeltTopicExerciseRoute(
                        belt: route.belt,
                        topicTitle: route.topicTitle
                    )
                },
                onPickSubTopic: { subTopicTitle in
                    selectedExerciseRoute = BeltTopicExerciseRoute(
                        belt: route.belt,
                        topicTitle: route.topicTitle,
                        forcedSubTopicTitle: subTopicTitle
                    )
                },
                onPickLinkedSubject: { subject in
                    selectedSubjectForSubTopics = subject
                }
            )
        }
        .navigationDestination(item: $selectedExerciseRoute) { (route: BeltQuestionsByBeltView.BeltTopicExerciseRoute) in
            MaterialsView(
                belt: route.belt,
                topicTitle: route.topicTitle,
                subTopicTitle: route.forcedSubTopicTitle,
                onSummary: { belt, topicTitle, subTopicTitle in
                    selectedBelt = belt
                    nav.push(.summary(belt: belt))
                },
                onPractice: { belt, topicTitle in
                    selectedBelt = belt
                    practiceTokenFromLists = topicTitle
                    nav.push(.practice(belt: belt, topicTitle: topicTitle))
                }
            )
        }
        .navigationDestination(item: $selectedSubjectForSubTopics) { subject in
            SubjectSubTopicsView(
                belt: selectedBelt,
                subject: subject,
                onPickSection: { sectionTitle in
                    selectedSubjectSectionRoute = SubjectSectionExerciseRoute(
                        belt: selectedBelt,
                        subject: subject,
                        sectionTitle: sectionTitle
                    )
                }
            )
        }
        .navigationDestination(item: $selectedSubjectSectionRoute) { (route: BeltQuestionsByBeltView.SubjectSectionExerciseRoute) in
            SubjectExercisesView(route: route)
        }
        .navigationDestination(item: $pickedExercise) { selection in
            ExerciseDetailView(
                belt: selection.belt,
                topicTitle: selection.topicTitle,
                item: selection.item
            )
        }
    }
    
    @ViewBuilder
    private func topicRowCard(
        entry: BeltTopicUi,
        topicTitle: String,
        subTitles: [String],
        hasSubs: Bool,
        isExpanded: Bool,
        locked: Bool,
        accent: Color,
        rowMinHeight: CGFloat
    ) -> some View {
        let rowOpacity: Double = locked ? 0.88 : 1.0

        Button {
            openTopicFromByBelt(
                topicTitle: topicTitle,
                hasSubs: hasSubs,
                isExpanded: isExpanded
            )
        } label: {
            VStack(spacing: 0) {
                topicMainRow(
                    entry: entry,
                    topicTitle: topicTitle,
                    hasSubs: hasSubs,
                    isExpanded: isExpanded,
                    locked: locked,
                    accent: accent,
                    rowMinHeight: rowMinHeight
                )

                if hasSubs && isExpanded {
                    expandedSubTopicsBlock(
                        topicTitle: topicTitle,
                        subTitles: subTitles,
                        accent: accent
                    )
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                accent.opacity(0.08),
                                Color.white.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        locked ? Color.orange.opacity(0.34) : accent.opacity(0.14),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.055), radius: 6, x: 0, y: 3)
            .opacity(rowOpacity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func topicMainRow(
        entry: BeltTopicUi,
        topicTitle: String,
        hasSubs: Bool,
        isExpanded: Bool,
        locked: Bool,
        accent: Color,
        rowMinHeight: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                navigationChevron(
                    hasSubs: hasSubs,
                    isExpanded: isExpanded,
                    isEnglish: isEnglish
                )

                topicIconBox(
                    topicTitle: topicTitle,
                    accent: accent
                )

                topicTextBlock(
                    title: entry.title,
                    subtitle: entry.subtitle,
                    isEnglish: isEnglish
                )

                if locked {
                    PulsingLockBadge()
                }

                topicAccentStrip(accent)
            } else {
                navigationChevron(
                    hasSubs: hasSubs,
                    isExpanded: isExpanded,
                    isEnglish: isEnglish
                )

                Spacer(minLength: 0)

                topicTextBlock(
                    title: entry.title,
                    subtitle: entry.subtitle,
                    isEnglish: isEnglish
                )

                if locked {
                    PulsingLockBadge()
                }

                topicIconBox(
                    topicTitle: topicTitle,
                    accent: accent
                )

                topicAccentStrip(accent)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: rowMinHeight)
    }

    @ViewBuilder
    private func expandedSubTopicsBlock(
        topicTitle: String,
        subTitles: [String],
        accent: Color
    ) -> some View {
        VStack(spacing: 8) {
            ForEach(subTitles, id: \.self) { sub in
                subTopicButton(
                    topicTitle: topicTitle,
                    subTitle: sub
                )
            }

            let directItems = ContentRepo.shared.getAllItemsFor(
                belt: selectedBelt,
                topicTitle: topicTitle,
                subTopicTitle: nil
            )

            if !directItems.isEmpty {
                fullTopicButton(
                    topicTitle: topicTitle,
                    accent: accent
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func subTopicButton(
        topicTitle: String,
        subTitle: String
    ) -> some View {
        let itemCount = ContentRepo.shared.getAllItemsFor(
            belt: selectedBelt,
            topicTitle: topicTitle,
            subTopicTitle: subTitle
        ).count

        Button {
            if isTopicLocked(topicTitle) || isTopicLocked(subTitle) {
                nav.push(.subscriptionPlans)
            } else {
                selectedExerciseRoute = BeltTopicExerciseRoute(
                    belt: selectedBelt,
                    topicTitle: topicTitle,
                    forcedSubTopicTitle: subTitle
                )
            }
        } label: {
            HStack(spacing: 10) {
                if isEnglish {
                    VStack(alignment: .leading, spacing: 3) {
                        subTopicTitleLine(subTitle)

                        Text(exercisesCountText(itemCount))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.48))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.26))
                } else {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.26))

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        subTopicTitleLine(subTitle)

                        Text(exercisesCountText(itemCount))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.48))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func subTopicTitleLine(_ subTitle: String) -> some View {
        HStack(spacing: 6) {
            if isEnglish {
                Text(uiTopicTitle(subTitle))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if isTopicLocked(subTitle) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11.5, weight: .black))
                        .foregroundStyle(Color.orange.opacity(0.90))
                }

                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)

                if isTopicLocked(subTitle) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11.5, weight: .black))
                        .foregroundStyle(Color.orange.opacity(0.90))
                }

                Text(uiTopicTitle(subTitle))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(
            maxWidth: .infinity,
            alignment: isEnglish ? .leading : .trailing
        )
    }

    @ViewBuilder
    private func fullTopicButton(
        topicTitle: String,
        accent: Color
    ) -> some View {
        Button {
            if isTopicLocked(topicTitle) {
                nav.push(.subscriptionPlans)
            } else {
                selectedExerciseRoute = BeltTopicExerciseRoute(
                    belt: selectedBelt,
                    topicTitle: topicTitle
                )
            }
        } label: {
            HStack(spacing: 10) {
                if isEnglish {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(accent)

                    Text("Full topic")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if isTopicLocked(topicTitle) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11.5, weight: .black))
                            .foregroundStyle(Color.orange.opacity(0.90))
                    }

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    if isTopicLocked(topicTitle) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11.5, weight: .black))
                            .foregroundStyle(Color.orange.opacity(0.90))
                    }

                    Text("כל הנושא")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(accent)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
   
        private var beltModeTabs: some View {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                        quickMenuOpen = false
                        tab = .byTopic
                    }
                } label: {
                    beltModeTabButton(
                        title: isEnglish ? "By Topic" : "לפי נושא",
                        selected: tab == .byTopic
                    )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                        quickMenuOpen = false
                        tab = .byBelt
                    }
                } label: {
                    beltModeTabButton(
                        title: isEnglish ? "By Belt" : "לפי חגורה",
                        selected: tab == .byBelt
                    )
                }
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity)
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
        }
        
    private func beltModeTabButton(
        title: String,
        selected: Bool
    ) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(selected ? Color.white : Color(red: 0.28, green: 0.22, blue: 0.56))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        selected
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.50, green: 0.00, blue: 1.00),
                                Color(red: 0.25, green: 0.32, blue: 0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color.white.opacity(0.86)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selected
                        ? Color.white.opacity(0.42)
                        : Color(red: 0.50, green: 0.00, blue: 1.00).opacity(0.22),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: selected ? Color.black.opacity(0.16) : Color.black.opacity(0.06),
                radius: selected ? 8 : 4,
                x: 0,
                y: selected ? 5 : 2
            )
    }
    
    @ViewBuilder
    private var byBeltContent: some View {
        VStack(spacing: 0) {
            beltModeTabs
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            
            GeometryReader { geo in
                let rowMinHeight: CGFloat = 56
                let visibleRows: CGFloat = 5.55
                let listHeight = rowMinHeight * visibleRows + 6
                let cardHeight = min(geo.size.height * 0.84, listHeight + 74)
                
                WhiteCard {
                    VStack(spacing: 7) {
                        Text(isEnglish ? "Topics in Belt" : "נושאים בחגורה")
                            .font(.system(size: 16.5, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .lineLimit(1)
                            .padding(.top, 0)
                        
                        if beltTopicsUi.isEmpty {
                            Text(isEnglish ? "No topics to display" : "אין נושאים להצגה")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.52))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 22)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 3) {
                                        Color.clear
                                            .frame(height: 0)
                                            .id("topics_top_anchor")
                                        
                                        ForEach(beltTopicsUi, id: \.id) { entry in
                                            let topicTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                            
                                            let details = topicDetailsFor(
                                                belt: selectedBelt,
                                                topicTitle: topicTitle
                                            )
                                            
                                            let subTitles = details.subTitles
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty && $0 != topicTitle }
                                                .reduce(into: [String]()) { partial, item in
                                                    if !partial.contains(item) {
                                                        partial.append(item)
                                                    }
                                                }
                                            
                                            let hasSubs = !subTitles.isEmpty
                                            let isExpanded = expandedTopic == topicTitle
                                            let locked = isTopicLocked(topicTitle)
                                            let accent = topicAccentColor(topicTitle)
                                            
                                            topicRowCard(
                                                entry: entry,
                                                topicTitle: topicTitle,
                                                subTitles: subTitles,
                                                hasSubs: hasSubs,
                                                isExpanded: isExpanded,
                                                locked: locked,
                                                accent: accent,
                                                rowMinHeight: rowMinHeight
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                    .padding(.bottom, 8)
                                }
                                .frame(maxHeight: listHeight)
                                .onChange(of: selectedBelt) { _, _ in
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        proxy.scrollTo("topics_top_anchor", anchor: .top)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 5)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 7)
                }
                .frame(height: cardHeight)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
        .zIndex(1)
        .allowsHitTesting(!quickMenuOpen)
    }
    
    // MARK: - Belt Palette + Wheel4
    // ✅ Rename to avoid "Invalid redeclaration of BeltPalette"
    private enum BeltPaletteByBeltScreen {
        static let white  = Color(red: 0.92, green: 0.92, blue: 0.92)
        static let yellow = Color(red: 0.98, green: 0.85, blue: 0.18)
        static let orange = Color(red: 0.98, green: 0.64, blue: 0.15)
        static let green  = Color(red: 0.18, green: 0.80, blue: 0.44)
        static let blue   = Color(red: 0.18, green: 0.52, blue: 0.95)
        static let brown  = Color(red: 0.55, green: 0.34, blue: 0.23)
        static let black  = Color(red: 0.10, green: 0.10, blue: 0.12)
        
        static func color(for belt: Belt) -> Color {
            switch belt {
            case .white:  return white
            case .yellow: return yellow
            case .orange: return orange
            case .green:  return green
            case .blue:   return blue
            case .brown:  return brown
            case .black:  return black
            default:      return orange
            }
        }
        
        static var ringColors: [Color] {
            [white, yellow, orange, green, blue, brown, black]
        }
    }
    
    
    // MARK: - Subject pill
    // Moved to BeltQuestionsSharedComponents.swift
    
    // MARK: - Floating quick menu overlay
    
    private struct BeltQuickMenuOverlay: View {
        @Binding var isPresented: Bool
        
        let isEnglish: Bool
        let isByTopicMode: Bool
        let beltTitle: String
        let beltFill: Color
        
        let onWeakPoints: () -> Void
        let onAllLists: () -> Void
        let onPractice: () -> Void
        let onSummary: () -> Void
        let onVoice: () -> Void
        
        let onFinalExam: () -> Void
        let onInternalExam: (() -> Void)?
        
        private var isOpen: Bool { isPresented }
        
        private func isMenuItemLocked(_ title: String) -> Bool {
            LockedContentPolicy.shouldShowLock(
                accessMode: LockedContentPolicy.currentAccessMode(),
                title: title
            )
        }
        
        var body: some View {
            ZStack(alignment: .bottom) {
                
                if isOpen {
                    Color.black.opacity(isByTopicMode ? 0.16 : 0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            close()
                        }
                        .transition(.opacity)
                        .zIndex(1)
                }
                
                if isByTopicMode {
                    byTopicBottomBar
                        .zIndex(3)
                } else {
                    byBeltAndroidStyleMenu
                        .zIndex(3)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .environment(\.layoutDirection, .leftToRight)
            .animation(.spring(response: 0.28, dampingFraction: 0.90), value: isPresented)
        }
        
        // MARK: - By Belt — Android style
        
        private var byBeltAndroidStyleMenu: some View {
            GeometryReader { geo in
                let safeBottom = geo.safeAreaInsets.bottom
                let isCompactHeight = geo.size.height < 760
                
                let popupBottom: CGFloat = {
                    let base = isCompactHeight ? geo.size.height * 0.245 : geo.size.height * 0.258
                    return max(190 + safeBottom, min(226 + safeBottom, base))
                }()
                
                let fabBottom: CGFloat = {
                    let base = isCompactHeight ? geo.size.height * 0.126 : geo.size.height * 0.130
                    return max(94 + safeBottom, min(112 + safeBottom, base))
                }()
                
                ZStack {
                    if isOpen {
                        androidPopupCard
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.horizontal, isCompactHeight ? 58 : 54)
                            .padding(.bottom, popupBottom)
                            .transition(
                                .scale(scale: 0.94, anchor: .bottom)
                                .combined(with: .opacity)
                            )
                    }

                    // באנדרואיד אין כפתור סגירה ירוק נפרד בצד בזמן שהתפריט פתוח.
                    // כשהתפריט סגור מציגים רק את כפתור הפתיחה.
                    if !isOpen {
                        let fabTrailing = max(34, min(44, geo.size.width * 0.105))
                        
                        byBeltFabButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing, fabTrailing)
                            .padding(.bottom, fabBottom)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        
        private var androidPopupCard: some View {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(beltFill.opacity(0.86))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(beltFill.opacity(0.10))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer(minLength: 0)
                    
                    Text(isEnglish ? "Quick Menu" : "תפריט מהיר")
                        .font(.system(size: 19.5, weight: .black))
                        .foregroundStyle(beltFill.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }
                .padding(.horizontal, 15)
                .padding(.top, 9)
                .padding(.bottom, 2)
                
                VStack(spacing: 0) {
                    androidMenuRow(
                        title: isEnglish ? "Weak Points" : "נקודות תורפה",
                        systemImage: "exclamationmark.triangle",
                        showsLock: isMenuItemLocked(isEnglish ? "Weak Points" : "נקודות תורפה"),
                        action: onWeakPoints
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "All Lists" : "כל הרשימות",
                        systemImage: "list.bullet",
                        showsLock: isMenuItemLocked(isEnglish ? "All Lists" : "כל הרשימות"),
                        action: onAllLists
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Practice" : "תרגול",
                        systemImage: "figure.walk",
                        showsLock: isMenuItemLocked(isEnglish ? "Practice" : "תרגול"),
                        action: onPractice
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Summary" : "מסך סיכום",
                        systemImage: "doc.text",
                        showsLock: isMenuItemLocked(isEnglish ? "Summary" : "מסך סיכום"),
                        action: onSummary
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                        systemImage: "mic",
                        showsLock: false,
                        action: onVoice
                    )
                    
                    androidDivider
                    
                    androidMenuRow(
                        title: isEnglish ? "Final Exam" : "מבחן מסכם",
                        systemImage: "checkmark.seal",
                        showsLock: isMenuItemLocked(isEnglish ? "Final Exam" : "מבחן מסכם"),
                        action: onFinalExam
                    )
                    
                    if let onInternalExam {
                        androidDivider
                        
                        androidMenuRow(
                            title: isEnglish ? "Internal Exam" : "מבחן פנימי",
                            systemImage: "person.badge.key",
                            showsLock: false,
                            action: onInternalExam
                        )
                    }
                }
                .padding(.horizontal, 11)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: 258)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.98, green: 0.98, blue: 0.96),
                                Color.white
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(beltFill.opacity(0.42), lineWidth: 1.05)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 8)
        }
        
        private var androidDivider: some View {
            Rectangle()
                .fill(beltFill.opacity(0.16))
                .frame(height: 1)
                .padding(.leading, 12)
                .padding(.trailing, 12)
        }
        
        private func androidMenuRow(
            title: String,
            systemImage: String,
            showsLock: Bool,
            action: @escaping () -> Void
        ) -> some View {
            Button {
                closeThen(action)
            } label: {
                HStack(spacing: 9) {
                    if isEnglish {
                        ZStack {
                            Circle()
                                .fill(beltFill.opacity(0.12))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(beltFill.opacity(0.28), lineWidth: 1)
                                )

                            Image(systemName: systemImage)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(beltFill.opacity(0.86))
                        }

                        Text(title)
                            .font(.system(size: 18.5, weight: .black))
                            .foregroundStyle(beltFill.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: showsLock ? "lock.fill" : "chevron.right")
                            .font(.system(size: showsLock ? 13 : 12, weight: .bold))
                            .foregroundStyle(beltFill.opacity(0.88))
                            .frame(width: 24)
                    } else {
                        Image(systemName: showsLock ? "lock.fill" : "chevron.left")
                            .font(.system(size: showsLock ? 13 : 12, weight: .bold))
                            .foregroundStyle(beltFill.opacity(0.88))
                            .frame(width: 24)

                        Text(title)
                            .font(.system(size: 18.5, weight: .black))
                            .foregroundStyle(beltFill.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        ZStack {
                            Circle()
                                .fill(beltFill.opacity(0.12))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(beltFill.opacity(0.28), lineWidth: 1)
                                )

                            Image(systemName: systemImage)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(beltFill.opacity(0.86))
                        }
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .frame(height: 43)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        
        private var byBeltFabButton: some View {
            Button {
                toggle()
            } label: {
                Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        beltFill.opacity(0.98),
                                        beltFill.opacity(0.78)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.74), lineWidth: 2.5)
                    )
                    .overlay(
                        Circle()
                            .stroke(beltFill.opacity(0.34), lineWidth: 4.5)
                            .blur(radius: 0.30)
                    )
                    .shadow(color: beltFill.opacity(0.32), radius: 8, x: 0, y: 3)
                    .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        
        // MARK: - By Topic — bottom bar
        
        private var byTopicBottomBar: some View {
            GeometryReader { geo in
                let safeBottom = geo.safeAreaInsets.bottom
                let isCompactHeight = geo.size.height < 760
                let bottomPadding = max(72 + safeBottom, min(92 + safeBottom, geo.size.height * (isCompactHeight ? 0.095 : 0.105)))
                
                VStack(spacing: 12) {
                    
                    if isOpen {
                        VStack(spacing: 10) {
                            androidMenuRow(
                                title: isEnglish ? "Weak Points" : "נקודות תורפה",
                                systemImage: "exclamationmark.triangle",
                                showsLock: isMenuItemLocked(isEnglish ? "Weak Points" : "נקודות תורפה"),
                                action: onWeakPoints
                            )
                            
                            androidMenuRow(
                                title: isEnglish ? "Practice" : "תרגול",
                                systemImage: "figure.walk",
                                showsLock: isMenuItemLocked(isEnglish ? "Practice" : "תרגול"),
                                action: onPractice
                            )
                            
                            androidMenuRow(
                                title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                                systemImage: "mic",
                                showsLock: false,
                                action: onVoice
                            )
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(beltFill.opacity(0.22), lineWidth: 1)
                        )
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button {
                        toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                                .font(.system(size: 17, weight: .black))
                            
                            Text(isEnglish ? "Quick View" : "מבט מהיר")
                                .font(.system(size: 17, weight: .black))
                        }
                        .foregroundStyle(beltFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            beltFill.opacity(0.10),
                                            Color.white.opacity(0.98),
                                            beltFill.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(beltFill.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, bottomPadding)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            }
        }
        
        // MARK: - Actions
        
        private func toggle() {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                isPresented.toggle()
            }
        }
        
        private func closeThen(_ action: @escaping () -> Void) {
            close()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action()
            }
        }
        
        private func close() {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                isPresented = false
            }
        }
    }
    
    // MARK: - Belt topic sub-topics
    // Moved to BeltTopicSubTopicsView.swift
    
    // MARK: - Linked topic sub-topics
    // Moved to LinkedTopicSubTopicsView.swift
    
    // MARK: - Belt topic exercises
    // Moved to BeltTopicExercisesView.swift
    
    // MARK: - Belt topic exercise row
    // Moved to KmiExerciseMarkRow in BeltQuestionsSharedComponents.swift
    
    // MARK: - Belt topic mark button
    // Moved to KmiMarkCircleButton in BeltQuestionsSharedComponents.swift
    
    // MARK: - Subject sub-topics
    // Moved to SubjectSubTopicsView.swift
    
    // MARK: - Subject exercises
    // Moved to SubjectExercisesView.swift
    
    // MARK: - Subject exercise row
    // Moved to KmiExerciseMarkRow in BeltQuestionsSharedComponents.swift
    
    // MARK: - Subject mark button
    // Moved to KmiMarkCircleButton in BeltQuestionsSharedComponents.swift
    
    private struct ExerciseSelection: Identifiable, Hashable {
        let belt: Belt
        let topicTitle: String
        let item: String
        
        var id: String {
            "\(belt.id)|\(topicTitle)|\(item)"
        }
        
        private static func parseBelt(_ raw: String) -> Belt? {
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "white", "לבן", "לבנה":
                return .white
            case "yellow", "צהוב", "צהובה":
                return .yellow
            case "orange", "כתום", "כתומה":
                return .orange
            case "green", "ירוק", "ירוקה":
                return .green
            case "blue", "כחול", "כחולה":
                return .blue
            case "brown", "חום", "חומה":
                return .brown
            case "black", "שחור", "שחורה":
                return .black
            default:
                return nil
            }
        }
        
        static func fromSearchKey(_ key: String) -> ExerciseSelection? {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            guard let belt = parseBelt(parts[0]) else { return nil }
            
            return ExerciseSelection(
                belt: belt,
                topicTitle: parts[1],
                item: parts[2]
            )
        }
    }
}

private struct BeltScreenQuickMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) {
        self.id = title + systemImage
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

private struct BeltScreenSideQuickMenuOverlay: View {
    @Binding var isPresented: Bool

    let isEnglish: Bool
    let items: [BeltScreenQuickMenuItem]
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let fabWidth: CGFloat = 44
            let panelWidth: CGFloat = 196
            let fabHeight: CGFloat = 68

            // ✅ מיקום פיזי, לא מושפע מ-RTL:
            // עברית = ימין, אנגלית = שמאל
            let isRightSide = !isEnglish

            let sidePadding: CGFloat = 2
            let topOffset: CGFloat = 118

            ZStack(alignment: .topLeading) {
                if isPresented {
                    BeltScreenQuickMenuPanel(
                        title: isEnglish ? "Quick Actions" : "קיצורי דרך",
                        isEnglish: isEnglish,
                        items: items,
                        onClose: onClose
                    )
                    .frame(width: panelWidth)
                    .offset(
                        x: isRightSide
                            ? geo.size.width - panelWidth - fabWidth - 8
                            : fabWidth + 8,
                        y: topOffset + 38
                    )
                    .transition(
                        .scale(scale: 0.94)
                        .combined(with: .opacity)
                    )
                    .zIndex(51)
                }

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isPresented.toggle()
                    }
                } label: {
                    BeltScreenSideQuickFab(
                        isOpen: isPresented,
                        isEnglish: isEnglish
                    )
                }
                .buttonStyle(.plain)
                .frame(width: fabWidth, height: fabHeight)
                .offset(
                    x: isRightSide
                        ? geo.size.width - fabWidth - sidePadding
                        : sidePadding,
                    y: topOffset
                )
                .zIndex(52)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .environment(\.layoutDirection, .leftToRight)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct BeltScreenSideQuickFab: View {
    let isOpen: Bool
    let isEnglish: Bool

    var body: some View {
        ZStack {
            if isEnglish {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .fill(fabGradient)

                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(fabGradient)

                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
            }

            Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.white)
        }
        .frame(width: 44, height: 68)
        .shadow(color: Color.black.opacity(0.24), radius: 9, x: 0, y: 5)
    }

    private var fabGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.50, green: 0.00, blue: 1.00),
                Color(red: 0.25, green: 0.32, blue: 0.72),
                Color(red: 0.02, green: 0.66, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BeltScreenQuickMenuPanel: View {
    let title: String
    let isEnglish: Bool
    let items: [BeltScreenQuickMenuItem]
    let onClose: () -> Void

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                BeltScreenQuickMenuRow(
                    title: item.title,
                    systemImage: item.systemImage,
                    isEnglish: isEnglish,
                    action: {
                        onClose()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            item.action()
                        }
                    }
                )
                
                if index != items.count - 1 {
                    Rectangle()
                        .fill(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.18))
                        .frame(height: 0.8)
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.bottom, 7)
        .frame(width: 196)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 0.97))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.08),
                                Color.white.opacity(0.04),
                                Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}

private struct BeltScreenQuickMenuRow: View {
    let title: String
    let systemImage: String
    let isEnglish: Bool
    let action: () -> Void

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29))
                    .frame(width: 19, height: 19)

                Text(title)
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundStyle(Color(red: 0.04, green: 0.19, blue: 0.12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PulsingLockBadge: View {
    @State private var pulse: Bool = false
    
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 13.5, weight: .black))
            .foregroundStyle(Color.orange.opacity(0.92))
            .frame(width: 25, height: 25)
            .background(
                Circle()
                    .fill(Color.orange.opacity(0.13))
            )
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            )
            .scaleEffect(pulse ? 1.08 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.78)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // ⚠️ בפריוויו הזה עדיין אין KmiRootLayout,
        // אז תראה "בלי" הסרגל הגלובאלי (זה תקין לפריוויו).
        BeltQuestionsByBeltView(belt: .orange)
    }
}
