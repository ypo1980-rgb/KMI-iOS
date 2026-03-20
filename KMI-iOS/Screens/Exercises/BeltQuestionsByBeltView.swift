import SwiftUI
import Shared

// ✅ CONTENT-ONLY: אין כאן TopBar ואין כאן IconStrip ואין כאן DrawerContainer
struct BeltQuestionsByBeltView: View {

    let belt: Belt

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

    fileprivate struct SubjectSectionExerciseRoute: Identifiable, Hashable {
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
    
    private var beltTopicsUi: [BeltTopicUi] {
        let repoTopics = ContentRepo.shared.data[selectedBelt]?.topics ?? []

        return repoTopics.compactMap { topic in
            let cleanTopicTitle = topic.title.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanTopicTitle.isEmpty else { return nil }

            let repoSubTopics = ContentRepo.shared.getSubTopicsFor(
                belt: selectedBelt,
                topicTitle: cleanTopicTitle
            )

            let realSubTopics = repoSubTopics.filter {
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines) != cleanTopicTitle
            }

            let totalFromSubTopics = repoSubTopics.reduce(0) { partial, subTopic in
                partial + subTopic.items.count
            }

            let totalDirectItems = ContentRepo.shared.getAllItemsFor(
                belt: selectedBelt,
                topicTitle: cleanTopicTitle,
                subTopicTitle: nil
            ).count

            let totalItemsInsideTopic =
                topic.items.count +
                topic.subTopics.reduce(0) { partial, subTopic in
                    partial + subTopic.items.count
                }

            let totalExercises = max(
                totalFromSubTopics,
                max(totalDirectItems, totalItemsInsideTopic)
            )

            let visibleSubTopicsCount = realSubTopics.count

            let subtitle: String? = {
                if visibleSubTopicsCount >= 2 && totalExercises > 0 {
                    return "\(visibleSubTopicsCount) תתי נושאים • \(totalExercises) תרגילים"
                }

                if totalExercises > 0 {
                    return "\(totalExercises) תרגילים"
                }

                return nil
            }()

            return BeltTopicUi(
                id: "belt-topic::\(selectedBelt.id)::\(cleanTopicTitle)",
                title: cleanTopicTitle,
                subtitle: subtitle,
                linkedSubjects: []
            )
        }
    }
    
    private func nonEmptySubTopics(for topic: CatalogData.Topic) -> [CatalogData.SubTopic] {
        topic.subTopics.filter { !$0.items.isEmpty }
    }

    private func normalizedTopicKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "/", with: " / ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func linkedSubjects(for topic: CatalogData.Topic) -> [SubjectTopic] {
        let topicKey = normalizedTopicKey(topic.title)

        return TopicsBySubjectRegistry.subjectsForBelt(selectedBelt).filter { subject in
            let mappedTopics = subject.topicsByBelt[selectedBelt] ?? []
            return mappedTopics.contains { raw in
                normalizedTopicKey(raw) == topicKey
            }
        }
    }

    private func totalExercisesCount(for topic: CatalogData.Topic) -> Int {
        topic.items.count + nonEmptySubTopics(for: topic).reduce(0) { $0 + $1.items.count }
    }

    private func subtitleForTopic(_ topic: CatalogData.Topic) -> String {
        let subCount = nonEmptySubTopics(for: topic).count
        let total = totalExercisesCount(for: topic)

        if subCount > 0 {
            return "\(subCount) תתי נושאים • \(total) תרגילים"
        } else {
            return "\(total) תרגילים"
        }
    }
    
    private func catalogExercisesCount(for topicTitle: String, belt: Belt) -> Int {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let topic = catalog[belt]?.topics.first(where: {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == clean
        }) else {
            return 0
        }

        let direct = topic.items.count
        let subItems = topic.subTopics.reduce(0) { partial, subTopic in
            partial + subTopic.items.count
        }

        return direct + subItems
    }
    
    @State private var tab: Tab = .byBelt
    @State private var goWeakPoints: Bool = false
    @State private var goPractice: Bool = false
    @State private var goSummary: Bool = false
    @State private var goVoice: Bool = false
    @State private var goPdf: Bool = false
    @State private var goAllLists: Bool = false

    enum Tab { case byBelt, byTopic }
    
    private func nextBelt(after registered: Belt) -> Belt {
        let base: Belt = (registered == .white) ? .yellow : registered
        guard let idx = belts.firstIndex(of: base) else { return .orange }
        let nextIdx = min(idx + 1, belts.count - 1)
        return belts[nextIdx]
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

    private var beltProgressRatio: Double {
        guard beltProgress.total > 0 else { return 0 }
        return Double(beltProgress.done) / Double(beltProgress.total)
    }

    var body: some View {
        ZStack {
            KmiGradientBackground()

            VStack(spacing: 0) {
                SegmentedTabs(
                    leftTitle: "לפי נושא",
                    rightTitle: "לפי חגורה",
                    selected: (tab == .byTopic ? .left : .right),
                    onSelect: { sel in
                        tab = (sel == .left ? .byTopic : .byBelt)

                        if sel == .left {
                            nav.push(.beltQuestionsByTopic(belt: selectedBelt))
                        }
                    }
                )
                .padding(.horizontal, 18)
                .padding(.top, 10)

                GeometryReader { geo in
                    WhiteCard {
                        VStack(spacing: 12) {
                            Text("נושאים בחגורה")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 12) {
                                    ForEach(beltTopicsUi) { entry in
                                        SubjectPill(
                                            title: entry.title,
                                            subtitle: entry.subtitle,
                                            fill: BeltPaletteByBeltScreen.color(for: selectedBelt),
                                            onTap: {
                                                let topicTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)

                                                let repoSubTopics = ContentRepo.shared.getSubTopicsFor(
                                                    belt: selectedBelt,
                                                    topicTitle: topicTitle
                                                )

                                                let realSubTopics = repoSubTopics.filter {
                                                    $0.title.trimmingCharacters(in: .whitespacesAndNewlines) != topicTitle
                                                }

                                                if repoSubTopics.count > 1 || !realSubTopics.isEmpty {
                                                    selectedTopicSubTopicsRoute = BeltTopicSubTopicsRoute(
                                                        belt: selectedBelt,
                                                        topicTitle: topicTitle,
                                                        linkedSubjects: []
                                                    )
                                                    return
                                                }

                                                if let onlySubTopic = repoSubTopics.first {
                                                    let trimmedSubTitle = onlySubTopic.title.trimmingCharacters(in: .whitespacesAndNewlines)

                                                    if trimmedSubTitle != topicTitle {
                                                        selectedExerciseRoute = BeltTopicExerciseRoute(
                                                            belt: selectedBelt,
                                                            topicTitle: topicTitle,
                                                            forcedSubTopicTitle: onlySubTopic.title
                                                        )
                                                    } else {
                                                        selectedExerciseRoute = BeltTopicExerciseRoute(
                                                            belt: selectedBelt,
                                                            topicTitle: topicTitle
                                                        )
                                                    }
                                                    return
                                                }

                                                let directItems = ContentRepo.shared.getAllItemsFor(
                                                    belt: selectedBelt,
                                                    topicTitle: topicTitle,
                                                    subTopicTitle: nil
                                                )

                                                if !directItems.isEmpty {
                                                    selectedExerciseRoute = BeltTopicExerciseRoute(
                                                        belt: selectedBelt,
                                                        topicTitle: topicTitle
                                                    )
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .frame(height: geo.size.height * 0.65)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .zIndex(1)

            VStack {
                Spacer()

                BeltArcPicker(
                    belts: belts,
                    selectedBelt: $selectedBelt
                )
                .frame(height: 124)
                .padding(.horizontal, 34)
                .padding(.bottom, 92)
            }
            .zIndex(2.2)

            BeltQuickMenuOverlay(
                beltTitle: "\(selectedBelt.heb)\nחגורה",
                beltFill: BeltPaletteByBeltScreen.color(for: selectedBelt),
                onWeakPoints: { goWeakPoints = true },
                onAllLists: { goAllLists = true },
                onPractice: { goPractice = true },
                onSummary: { goSummary = true },
                onVoice: { goVoice = true },
                onPdf: { goPdf = true },
                onFinalExam: { nav.push(.beltFinalExam(belt: selectedBelt)) },
                onInternalExam: coach.isCoach ? { nav.push(.internalExam(belt: selectedBelt)) } : nil
            )
            .zIndex(2)
        }
        .onAppear {
            selectedBelt = (belt == .white) ? .yellow : belt
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
            BeltTopicExercisesView(
                belt: route.belt,
                topicTitle: route.topicTitle,
                forcedSubTopicTitle: route.forcedSubTopicTitle
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
        .navigationDestination(isPresented: $goWeakPoints) {
            FavoritesByBeltView(belt: selectedBelt)
        }
        .navigationDestination(isPresented: $goPractice) {
            PracticeView(belt: selectedBelt)
        }
        .navigationDestination(isPresented: $goAllLists) {
            ExercisesMarksListView(belt: selectedBelt, topic: "__ALL__", subTopic: nil)
        }
        .navigationDestination(isPresented: $goSummary) {
            SummaryView(belt: selectedBelt, nav: nav)
        }
        .navigationDestination(isPresented: $goVoice) {
            VoiceAssistantView()
        }
        .navigationDestination(isPresented: $goPdf) {
            PdfExportView(belt: selectedBelt)
        }
    }
}

// MARK: - Belt Palette + Wheel

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

private struct SubjectPill: View {
    let title: String
    let subtitle: String?
    let fill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating quick menu overlay

private struct BeltQuickMenuOverlay: View {
    let beltTitle: String
    let beltFill: Color

    let onWeakPoints: () -> Void
    let onAllLists: () -> Void
    let onPractice: () -> Void
    let onSummary: () -> Void
    let onVoice: () -> Void
    let onPdf: () -> Void

    let onFinalExam: () -> Void
    let onInternalExam: (() -> Void)?

    @State private var isOpen: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {

            if isOpen {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
            }

            VStack(spacing: 0) {
                Spacer()

                HStack(alignment: .bottom) {
                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
                            isOpen.toggle()
                        }
                    } label: {
                        Image(systemName: isOpen ? "xmark" : "line.3.horizontal")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color.black.opacity(0.35)))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
                }

                if isOpen {
                    VStack(alignment: .leading, spacing: 12) {

                        QuickPill(title: "נקודות תורפה", systemImage: "exclamationmark.triangle.fill", onTap: { closeThen(onWeakPoints) })
                        QuickPill(title: "כל הרשימות", systemImage: "line.3.horizontal", onTap: { closeThen(onAllLists) })
                        QuickPill(title: "תרגול", systemImage: "figure.walk", onTap: { closeThen(onPractice) })
                        QuickPill(title: "מסך סיכום", systemImage: "list.bullet.clipboard", onTap: { closeThen(onSummary) })
                        QuickPill(title: "עוזר קולי", systemImage: "mic.fill", onTap: { closeThen(onVoice) })
                        QuickPill(title: "PDF", systemImage: "doc.richtext", onTap: { closeThen(onPdf) })

                        QuickPill(title: "מבחן מסכם", systemImage: "checkmark.seal.fill", onTap: { closeThen(onFinalExam) })

                        if let onInternalExam {
                            QuickPill(title: "מבחן פנימי", systemImage: "person.badge.key.fill", onTap: { closeThen(onInternalExam) })
                        }
                    }
                    .padding(.leading, 18)
                    .padding(.bottom, 106)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func closeThen(_ action: () -> Void) {
        close()
        action()
    }

    private func close() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.95)) {
            isOpen = false
        }
    }

    private struct QuickPill: View {
        let title: String
        let systemImage: String
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 44, height: 44)
                            .shadow(radius: 6, y: 2)

                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                    }

                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                        )
                        .shadow(radius: 6, y: 2)

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct BeltTopicSubTopicsView: View {
    let belt: Belt
    let topicTitle: String
    let linkedSubjects: [SubjectTopic]
    let onPickAllTopic: () -> Void
    let onPickSubTopic: (String) -> Void
    let onPickLinkedSubject: (SubjectTopic) -> Void

    var body: some View {
        let repoSubTopics = ContentRepo.shared.getSubTopicsFor(
            belt: belt,
            topicTitle: topicTitle
        )

        let realSubTopics = repoSubTopics.filter {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines) !=
            topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        ZStack {
            KmiGradientBackground()

            ScrollView {
                WhiteCard {
                    VStack(spacing: 12) {
                        Text(topicTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            ForEach(linkedSubjects, id: \.id) { subject in
                                SubjectPill(
                                    title: subject.titleHeb,
                                    subtitle: nil,
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
                                    onTap: {
                                        onPickLinkedSubject(subject)
                                    }
                                )
                            }

                            ForEach(realSubTopics, id: \.title) { st in
                                SubjectPill(
                                    title: st.title,
                                    subtitle: "\(st.items.count) תרגילים",
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
                                    onTap: {
                                        onPickSubTopic(st.title)
                                    }
                                )
                            }

                            if linkedSubjects.isEmpty && realSubTopics.isEmpty && !repoSubTopics.isEmpty {
                                let total = repoSubTopics.reduce(0) { $0 + $1.items.count }

                                SubjectPill(
                                    title: "כל התרגילים בנושא",
                                    subtitle: "\(total) תרגילים",
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
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
        .navigationTitle(topicTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LinkedTopicSubTopicsView: View {
    let title: String
    let subjects: [SubjectTopic]
    let onPickLinkedSubject: (SubjectTopic) -> Void

        var body: some View {
            ZStack {
                KmiGradientBackground()

                ScrollView {
                    WhiteCard {
                        VStack(spacing: 12) {
                            Text(title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .center)

                            VStack(spacing: 12) {
                                ForEach(subjects, id: \.id) { subject in
                                    SubjectPill(
                                        title: subject.titleHeb,
                                        subtitle: nil,
                                        fill: BeltPaletteByBeltScreen.color(for: .orange),
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    

private struct BeltTopicExercisesView: View {
    let belt: Belt
    let topicTitle: String
    let forcedSubTopicTitle: String?

    fileprivate enum Mark: String {
        case done
        case notDone
    }

    @State private var marksCache: [String: Mark?] = [:]

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [String]
    }

    private var sections: [UiSection] {
        let repoSubTopics = ContentRepo.shared.getSubTopicsFor(
            belt: belt,
            topicTitle: topicTitle
        )

        if let forcedSubTopicTitle, !forcedSubTopicTitle.isEmpty {
            let items = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: topicTitle,
                subTopicTitle: forcedSubTopicTitle
            )

            guard !items.isEmpty else { return [] }

            return [
                UiSection(
                    id: "\(topicTitle)::\(forcedSubTopicTitle)",
                    title: forcedSubTopicTitle,
                    items: items
                )
            ]
        }

        if repoSubTopics.count == 1,
           let only = repoSubTopics.first,
           only.title.trimmingCharacters(in: .whitespacesAndNewlines) ==
           topicTitle.trimmingCharacters(in: .whitespacesAndNewlines) {
            return [
                UiSection(
                    id: "\(topicTitle)::__direct__",
                    title: topicTitle,
                    items: only.items
                )
            ]
        }

        return repoSubTopics.map { subTopic in
            UiSection(
                id: "\(topicTitle)::\(subTopic.title)",
                title: subTopic.title,
                items: subTopic.items
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

    private func loadMark(sectionTitle: String, item: String) -> Mark? {
        let key = markKey(sectionTitle: sectionTitle, item: item)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return Mark(rawValue: raw)
    }

    private func setMark(_ mark: Mark?, sectionTitle: String, item: String) {
        let key = markKey(sectionTitle: sectionTitle, item: item)
        if let mark {
            UserDefaults.standard.set(mark.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func currentMark(sectionTitle: String, item: String) -> Mark? {
        let cacheKey = "\(sectionTitle)::\(item)"
        if let cached = marksCache[cacheKey] { return cached }
        return loadMark(sectionTitle: sectionTitle, item: item)
    }

    private func toggleMark(_ mark: Mark, sectionTitle: String, item: String) {
        let cacheKey = "\(sectionTitle)::\(item)"
        let cur = currentMark(sectionTitle: sectionTitle, item: item)
        let next: Mark? = (cur == mark) ? nil : mark
        setMark(next, sectionTitle: sectionTitle, item: item)
        marksCache[cacheKey] = next
    }

    var body: some View {
        ZStack {
            KmiGradientBackground()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sections) { sec in
                        WhiteCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(sec.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(spacing: 0) {
                                    ForEach(Array(sec.items.enumerated()), id: \.offset) { idx, item in
                                        BeltTopicExerciseMarkRow(
                                            title: item,
                                            mark: currentMark(sectionTitle: sec.title, item: item),
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
        .navigationTitle(topicTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BeltTopicExerciseMarkRow: View {
    let title: String
    let mark: BeltTopicExercisesView.Mark?

    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            HStack(spacing: 10) {
                BeltTopicMarkCircleButton(
                    systemName: "xmark",
                    isSelected: mark == .notDone,
                    selectedFill: Color.red.opacity(0.75),
                    unselectedFill: Color.red.opacity(0.18),
                    onTap: onMarkNotDone
                )

                BeltTopicMarkCircleButton(
                    systemName: "checkmark",
                    isSelected: mark == .done,
                    selectedFill: Color.green.opacity(0.75),
                    unselectedFill: Color.green.opacity(0.18),
                    onTap: onMarkDone
                )
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 10)
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .padding(.vertical, 6)
    }
}

private struct BeltTopicMarkCircleButton: View {
    let systemName: String
    let isSelected: Bool
    let selectedFill: Color
    let unselectedFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedFill : unselectedFill)
                    .frame(width: 38, height: 38)

                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.95 : 0.55))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SubjectSubTopicsView: View {
    let belt: Belt
    let subject: SubjectTopic
    let onPickSection: (String) -> Void

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
            KmiGradientBackground()

            ScrollView {
                WhiteCard {
                    VStack(spacing: 12) {
                        Text(subject.titleHeb)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .center)

                        VStack(spacing: 12) {
                            ForEach(rawSections, id: \.title) { sec in
                                SubjectPill(
                                    title: sec.title,
                                    subtitle: "\(sec.items.count) תרגילים",
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
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
        .navigationTitle(subject.titleHeb)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubjectExercisesView: View {
    let route: BeltQuestionsByBeltView.SubjectSectionExerciseRoute

    @EnvironmentObject private var nav: AppNavModel

    fileprivate enum Mark: String {
        case done
        case notDone
    }

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
            title: route.sectionTitle,
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: "חגורה \(route.belt.heb) • \(allItems.count)",
            titleColor: KmiBeltPalette.color(for: route.belt)
        ) {
            ZStack {
                BeltTopicsGradientBackground()

                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(spacing: 6) {
                                Text("חגורה: \(route.belt.heb) • תרגילים: \(allItems.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        WhiteCard {
                            VStack(spacing: 0) {
                                ForEach(Array(allItems.enumerated()), id: \.offset) { idx, item in
                                    SubjectExerciseMarkRow(
                                        title: item,
                                        isDoneSelected: currentMark(for: item) == .done,
                                        isNotDoneSelected: currentMark(for: item) == .notDone,
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

private struct SubjectExerciseMarkRow: View {
    let title: String
    let isDoneSelected: Bool
    let isNotDoneSelected: Bool

    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            HStack(spacing: 10) {
                SubjectMarkCircleButton(
                    systemName: "xmark",
                    isSelected: isNotDoneSelected,
                    selectedFill: Color.red.opacity(0.75),
                    unselectedFill: Color.red.opacity(0.18),
                    onTap: onMarkNotDone
                )

                SubjectMarkCircleButton(
                    systemName: "checkmark",
                    isSelected: isDoneSelected,
                    selectedFill: Color.green.opacity(0.75),
                    unselectedFill: Color.green.opacity(0.18),
                    onTap: onMarkDone
                )
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 10)
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}

private struct SubjectMarkCircleButton: View {
    let systemName: String
    let isSelected: Bool
    let selectedFill: Color
    let unselectedFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedFill : unselectedFill)
                    .frame(width: 38, height: 38)

                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.95 : 0.55))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        // ⚠️ בפריוויו הזה עדיין אין KmiRootLayout,
        // אז תראה "בלי" הסרגל הגלובאלי (זה תקין לפריוויו).
        BeltQuestionsByBeltView(belt: .orange)
    }
}
