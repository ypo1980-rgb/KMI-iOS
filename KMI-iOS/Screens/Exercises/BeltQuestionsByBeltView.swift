import SwiftUI
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
    @State private var didInitializeSelectedBelt: Bool = false
    @State private var tab: Tab = .byBelt
    @State private var quickMenuOpen: Bool = false
    @State private var expandedTopic: String? = nil
    @State private var accessRefreshTick: Int = 0
    
    // Global search
    @State private var pickedExercise: ExerciseSelection? = nil
    
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
    
    private func nextBelt(after registered: Belt) -> Belt {
        switch registered {
        case .white:
            return .yellow
        case .yellow:
            return .orange
        case .orange:
            return .green
        case .green:
            return .blue
        case .blue:
            return .brown
        case .brown:
            return .black
        case .black:
            return .black
        default:
            return .orange
        }
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
                .font(.system(size: 16.5, weight: .heavy))
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
                    .font(.system(size: 12.5, weight: .bold))
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.20),
                            accent.opacity(0.08),
                            Color.white.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
            
            Image(systemName: topicSymbolName(topicTitle))
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(accent)
        }
        .frame(width: 54, height: 46)
    }
    
    private func topicAccentStrip(_ accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(accent)
            .frame(width: 6, height: 46)
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
                        withAnimation(.easeInOut(duration: 0.20)) {
                            tab = .byBelt
                        }
                    }
                )
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
            KmiGradientBackground(forceTraineeStyle: false)
            
            tabContent
            
            if tab == .byBelt {
                VStack {
                    Spacer()
                    
                    BeltArcPicker(
                        belts: belts,
                        selectedBelt: $selectedBelt,
                        isEnglish: isEnglish
                    )
                    .frame(width: 340, height: 132)
                    .offset(y: 34)
                    .padding(.bottom, 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .zIndex(2.2)
                .allowsHitTesting(!quickMenuOpen)
            }
            
            BeltQuickMenuOverlay(
                isPresented: $quickMenuOpen,
                isEnglish: isEnglish,
                isByTopicMode: tab == .byTopic,
                beltTitle: isEnglish
                ? "\(beltDisplayTitle(selectedBelt))\nBelt"
                : "\(selectedBelt.heb)\nחגורה",
                beltFill: BeltPaletteByBeltScreen.color(for: selectedBelt),
                onWeakPoints: {
                    print("🟣 QUICK TAP: weakPoints | belt =", selectedBelt.heb)
                    nav.push(.weakPoints(belt: selectedBelt))
                },
                onAllLists: {
                    print("🟣 QUICK TAP: allLists | belt =", selectedBelt.heb)
                    nav.push(.allLists(belt: selectedBelt))
                },
                onPractice: {
                    print("🟣 QUICK TAP: practice | belt =", selectedBelt.heb)
                    practiceTokenFromLists = "__ALL__"
                    nav.push(.practice(belt: selectedBelt, topicTitle: "__ALL__"))
                },
                onSummary: {
                    print("🟣 QUICK TAP: summary | belt =", selectedBelt.heb)
                    nav.push(.summary(belt: selectedBelt))
                },
                onVoice: {
                    print("🟣 QUICK TAP: voice | belt =", selectedBelt.heb)
                    nav.push(.voiceAssistant)
                },
                onFinalExam: {
                    print("🟣 QUICK TAP: beltFinalExam | belt =", selectedBelt.heb)
                    nav.push(.beltFinalExam(belt: selectedBelt))
                },
                onInternalExam: coach.isCoach ? {
                    print("🟣 QUICK TAP: internalExam | belt =", selectedBelt.heb)
                    nav.push(.internalExam(belt: selectedBelt))
                } : nil
            )
            .zIndex(1000)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            guard !didInitializeSelectedBelt else { return }
            
            if belts.contains(belt) {
                selectedBelt = belt
            } else {
                selectedBelt = .orange
            }
            
            didInitializeSelectedBelt = true
        }
        .onChange(of: selectedBelt) { _, _ in
            expandedTopic = nil
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
        HStack(spacing: 10) {
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

                if locked {
                    PulsingLockBadge()
                }

                topicTextBlock(
                    title: entry.title,
                    subtitle: entry.subtitle,
                    isEnglish: isEnglish
                )

                topicIconBox(
                    topicTitle: topicTitle,
                    accent: accent
                )

                topicAccentStrip(accent)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                Image(systemName: isEnglish ? "chevron.right" : "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.26))

                Spacer(minLength: 0)

                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 3) {
                    subTopicTitleLine(subTitle)

                    Text(exercisesCountText(itemCount))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.48))
                        .frame(
                            maxWidth: .infinity,
                            alignment: isEnglish ? .leading : .trailing
                        )
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                }
            }
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
                    Text("🔒")
                        .font(.system(size: 14, weight: .black))
                }

                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)

                if isTopicLocked(subTitle) {
                    Text("🔒")
                        .font(.system(size: 14, weight: .black))
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
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(accent)

                Text(isEnglish ? "Full topic" : "כל הנושא")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.82))

                if isTopicLocked(topicTitle) {
                    Text("🔒")
                        .font(.system(size: 14, weight: .black))
                }

                Spacer(minLength: 0)
            }
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
    private var byBeltContent: some View {
        VStack(spacing: 0) {
            SegmentedTabs(
                leftTitle: isEnglish ? "By Topic" : "לפי נושא",
                rightTitle: isEnglish ? "By Belt" : "לפי חגורה",
                selected: (tab == .byTopic ? .left : .right),
                onSelect: { sel in
                    if sel == .left {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            tab = .byTopic
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            tab = .byBelt
                        }
                    }
                }
            )
            .padding(.horizontal, 22)
            .padding(.top, 8)
            
            GeometryReader { geo in
                let rowMinHeight: CGFloat = 62
                let visibleRows: CGFloat = 5
                let listHeight = rowMinHeight * visibleRows + 12
                let cardHeight = min(geo.size.height * 0.66, listHeight + 76)
                
                WhiteCard {
                    VStack(spacing: 7) {
                        Text(isEnglish ? "Topics in Belt" : "נושאים בחגורה")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .lineLimit(1)
                            .padding(.top, 1)
                        
                        if beltTopicsUi.isEmpty {
                            Text(isEnglish ? "No topics to display" : "אין נושאים להצגה")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.52))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 22)
                        } else {
                            ScrollViewReader { proxy in
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 10) {
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
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(height: cardHeight)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
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
        
        var body: some View {
            ZStack(alignment: .bottom) {
                
                if isOpen {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        if isByTopicMode {
                            Button {
                                print("🟠 MENU BAR TAP | before isOpen =", isOpen)
                                
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                                    isPresented.toggle()
                                }
                                
                                print("🟠 MENU BAR TAP | after isOpen =", isPresented)
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
                                        .fill(Color.white.opacity(0.96))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(beltFill.opacity(0.22), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            .zIndex(3)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 78)
                        } else {
                            Button {
                                print("🟠 MENU BUTTON TAP | before isOpen =", isOpen)
                                
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                                    isPresented.toggle()
                                }
                                
                                print("🟠 MENU BUTTON TAP | after isOpen =", isPresented)
                            } label: {
                                Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        beltFill.opacity(0.95),
                                                        Color.black.opacity(0.58)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                    .shadow(radius: 8, y: 3)
                            }
                            .buttonStyle(.plain)
                            .zIndex(3)
                            .padding(.leading, 18)
                            .padding(.bottom, 72)
                            
                            Spacer()
                        }
                    }
                    
                    if isOpen {
                        VStack(
                            alignment: isByTopicMode ? .center : .leading,
                            spacing: 12
                        ) {
                            
                            QuickPill(
                                title: isEnglish ? "Weak Points" : "נקודות תורפה",
                                systemImage: "exclamationmark.triangle.fill",
                                onTap: { closeThen(onWeakPoints) }
                            )
                            
                            QuickPill(
                                title: isEnglish ? "All Lists" : "כל הרשימות",
                                systemImage: "line.3.horizontal",
                                onTap: { closeThen(onAllLists) }
                            )
                            
                            QuickPill(
                                title: isEnglish ? "Practice" : "תרגול",
                                systemImage: "figure.walk",
                                onTap: { closeThen(onPractice) }
                            )
                            
                            QuickPill(
                                title: isEnglish ? "Summary" : "מסך סיכום",
                                systemImage: "list.bullet.clipboard",
                                onTap: { closeThen(onSummary) }
                            )
                            
                            QuickPill(
                                title: isEnglish ? "Voice Assistant" : "עוזר קולי",
                                systemImage: "mic.fill",
                                onTap: { closeThen(onVoice) }
                            )
                            
                            QuickPill(
                                title: isEnglish ? "Final Exam" : "מבחן מסכם",
                                systemImage: "checkmark.seal.fill",
                                onTap: { closeThen(onFinalExam) }
                            )
                            
                            if let onInternalExam {
                                QuickPill(
                                    title: isEnglish ? "Internal Exam" : "מבחן פנימי",
                                    systemImage: "person.badge.key.fill",
                                    onTap: { closeThen(onInternalExam) }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isByTopicMode ? .center : .leading)
                        .padding(.horizontal, isByTopicMode ? 18 : 0)
                        .padding(.leading, isByTopicMode ? 0 : 18)
                        .padding(.bottom, isByTopicMode ? 146 : 92)
                        .transition(
                            .move(edge: isByTopicMode ? .bottom : .leading)
                            .combined(with: .opacity)
                        )
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        
        private func closeThen(_ action: @escaping () -> Void) {
            print("🟣 OVERLAY closeThen start | isOpen =", isOpen)
            
            close()
            
            DispatchQueue.main.async {
                print("🟣 OVERLAY closeThen dispatch action")
                action()
            }
        }
        
        private func close() {
            print("🟠 OVERLAY close()")
            withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
                isPresented = false
            }
        }
        
        private struct QuickPill: View {
            let title: String
            let systemImage: String
            let onTap: () -> Void
            
            var body: some View {
                Button {
                    print("🟠 QUICK PILL TAP -> \(title)")
                    onTap()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.96))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 3)
                            
                            Image(systemName: systemImage)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.76))
                        }
                        
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(width: 176, alignment: .center)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.96))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 3)
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

private struct PulsingLockBadge: View {
    @State private var pulse: Bool = false
    
    var body: some View {
        Text("🔒")
            .font(.system(size: 22, weight: .black))
            .frame(width: 28, height: 28)
            .scaleEffect(pulse ? 1.12 : 1.0)
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
