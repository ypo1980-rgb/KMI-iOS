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
    @State private var didInitializeSelectedBelt: Bool = false
    @State private var tab: Tab = .byBelt
    @State private var quickMenuOpen: Bool = false
    @State private var expandedTopic: String? = nil
    
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

    private var beltTopicsUi: [BeltTopicUi] {
        let topicTitles = TopicsEngine.shared.topicTitlesFor(belt: selectedBelt)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { partial, item in
                if !partial.contains(item) {
                    partial.append(item)
                }
            }

        return topicTitles.map { title in
            let details = topicDetailsFor(belt: selectedBelt, topicTitle: title)
            let subCount = details.subTitles.count
            let itemCount = details.itemCount

            let subtitle: String? = {
                if subCount > 0 {
                    return "\(subCount) תתי נושאים • \(itemCount) תרגילים"
                } else {
                    return "\(itemCount) תרגילים"
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

    private var beltProgressRatio: Double {
        guard beltProgress.total > 0 else { return 0 }
        return Double(beltProgress.done) / Double(beltProgress.total)
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

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
                                    ForEach(beltTopicsUi, id: \.id) { entry in
                                        let topicTitle = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)

                                        let details = topicDetailsFor(
                                            belt: selectedBelt,
                                            topicTitle: topicTitle
                                        )

                                        let subTitles = details.subTitles
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty && $0 != topicTitle }

                                        let hasSubs = !subTitles.isEmpty
                                        let isExpanded = expandedTopic == topicTitle

                                        Button {
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
                                        } label: {
                                            VStack(spacing: 0) {
                                                HStack(spacing: 10) {
                                                    if hasSubs {
                                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                            .font(.system(size: 15, weight: .heavy))
                                                            .foregroundStyle(Color.white.opacity(0.95))
                                                    }

                                                    Spacer(minLength: 0)

                                                    VStack(alignment: .trailing, spacing: 4) {
                                                        Text(entry.title)
                                                            .font(.system(size: 18, weight: .heavy))
                                                            .foregroundStyle(Color.white)
                                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                                            .multilineTextAlignment(.trailing)

                                                        if let subtitle = entry.subtitle, !subtitle.isEmpty {
                                                            Text(subtitle)
                                                                .font(.system(size: 14, weight: .heavy))
                                                                .foregroundStyle(Color.white.opacity(0.92))
                                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                                .multilineTextAlignment(.trailing)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 16)

                                                if hasSubs && isExpanded {
                                                    VStack(spacing: 10) {
                                                        ForEach(subTitles, id: \.self) { sub in
                                                            let itemCount = ContentRepo.shared.getAllItemsFor(
                                                                belt: selectedBelt,
                                                                topicTitle: topicTitle,
                                                                subTopicTitle: sub
                                                            ).count

                                                            Button {
                                                                selectedExerciseRoute = BeltTopicExerciseRoute(
                                                                    belt: selectedBelt,
                                                                    topicTitle: topicTitle,
                                                                    forcedSubTopicTitle: sub
                                                                )
                                                            } label: {
                                                                HStack {
                                                                    VStack(alignment: .trailing, spacing: 4) {
                                                                        Text(sub)
                                                                            .font(.system(size: 16, weight: .heavy))
                                                                            .foregroundStyle(Color.white.opacity(0.98))
                                                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                                                            .multilineTextAlignment(.trailing)

                                                                        Text("\(itemCount) תרגילים")
                                                                            .font(.system(size: 13, weight: .heavy))
                                                                            .foregroundStyle(Color.white.opacity(0.88))
                                                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                                                            .multilineTextAlignment(.trailing)
                                                                    }

                                                                    Spacer(minLength: 0)
                                                                }
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 14)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                        .fill(Color.white.opacity(0.16))
                                                                )
                                                            }
                                                            .buttonStyle(.plain)
                                                        }

                                                        let directItems = ContentRepo.shared.getAllItemsFor(
                                                            belt: selectedBelt,
                                                            topicTitle: topicTitle,
                                                            subTopicTitle: nil
                                                        )

                                                        if !directItems.isEmpty {
                                                            Button {
                                                                selectedExerciseRoute = BeltTopicExerciseRoute(
                                                                    belt: selectedBelt,
                                                                    topicTitle: topicTitle
                                                                )
                                                            } label: {
                                                                HStack {
                                                                    Text("כל הנושא")
                                                                        .font(.system(size: 16, weight: .heavy))
                                                                        .foregroundStyle(Color.white.opacity(0.98))

                                                                    Spacer(minLength: 0)
                                                                }
                                                                .padding(.horizontal, 16)
                                                                .padding(.vertical, 14)
                                                                .background(
                                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                        .fill(Color.white.opacity(0.16))
                                                                )
                                                            }
                                                            .buttonStyle(.plain)
                                                        }
                                                    }
                                                    .padding(.horizontal, 14)
                                                    .padding(.bottom, 14)
                                                    .transition(.move(edge: .top).combined(with: .opacity))
                                                }
                                            }
                                            .background(
                                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                    .fill(BeltPaletteByBeltScreen.color(for: selectedBelt))
                                            )
                                        }
                                        .buttonStyle(.plain)
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
            .allowsHitTesting(!quickMenuOpen)
            
            VStack {
                Spacer()

                BeltArcPicker(
                    belts: belts,
                    selectedBelt: $selectedBelt
                )
                .frame(width: 330, height: 124)
                .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .zIndex(2.2)
            .allowsHitTesting(!quickMenuOpen)

            BeltQuickMenuOverlay(
                isPresented: $quickMenuOpen,
                beltTitle: "\(selectedBelt.heb)\nחגורה",
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
        .onAppear {
            guard !didInitializeSelectedBelt else { return }

            if belts.contains(belt) {
                selectedBelt = belt
            } else {
                selectedBelt = .orange
            }

            didInitializeSelectedBelt = true
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
    @Binding var isPresented: Bool

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
                    Spacer()

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
                            .background(Circle().fill(Color.black.opacity(0.35)))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .shadow(radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .zIndex(3)
                    .padding(.trailing, 18)
                    .padding(.bottom, 108)
                }

                if isOpen {
                    VStack(alignment: .leading, spacing: 12) {

                        QuickPill(title: "נקודות תורפה", systemImage: "exclamationmark.triangle.fill", onTap: { closeThen(onWeakPoints) })
                        QuickPill(title: "כל הרשימות", systemImage: "line.3.horizontal", onTap: { closeThen(onAllLists) })
                        QuickPill(title: "תרגול", systemImage: "figure.walk", onTap: { closeThen(onPractice) })
                        QuickPill(title: "מסך סיכום", systemImage: "list.bullet.clipboard", onTap: { closeThen(onSummary) })
                        QuickPill(title: "עוזר קולי", systemImage: "mic.fill", onTap: { closeThen(onVoice) })
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: 170, alignment: .center)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.95))
                        )
                        .shadow(radius: 6, y: 2)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
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

    private struct UiSubTopic: Identifiable, Hashable {
        let id: String
        let title: String
        let itemsCount: Int
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

                            ForEach(uiSubTopics) { subTopic in
                                SubjectPill(
                                    title: subTopic.title,
                                    subtitle: "\(subTopic.itemsCount) תרגילים",
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
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
                                    title: "כל התרגילים בנושא",
                                    subtitle: "\(directItems.count) תרגילים",
                                    fill: BeltPaletteByBeltScreen.color(for: belt),
                                    onTap: onPickAllTopic
                                )
                            } else if linkedSubjects.isEmpty && uiSubTopics.isEmpty && details.itemCount > 0 {
                                SubjectPill(
                                    title: "כל התרגילים בנושא",
                                    subtitle: "\(Int(details.itemCount)) תרגילים",
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
            KmiGradientBackground(forceTraineeStyle: false)

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

        // ✅ אם נכנסנו לתת־נושא ספציפי
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

        // ✅ אם אין תתי נושאים → כל התרגילים תחת הנושא
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

        // ✅ יש תתי נושאים אמיתיים
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
            KmiGradientBackground(forceTraineeStyle: false)

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
            KmiGradientBackground(forceTraineeStyle: false)

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
                KmiGradientBackground(forceTraineeStyle: false)

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
