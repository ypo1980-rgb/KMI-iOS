import SwiftUI
import Shared

// ✅ CONTENT-ONLY: אין כאן TopBar ואין כאן IconStrip ואין כאן DrawerContainer
struct BeltQuestionsByBeltView: View {
    
    let belt: Belt

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private func uiTopicTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func uiExerciseTitle(_ title: String) -> String {
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
            let subText = subTopicsCount == 1 ? "1 sub-topic" : "\(subTopicsCount) sub-topics"
            return "\(subText) • \(exercisesCountText(exercisesCount))"
        } else {
            return "\(subTopicsCount) תתי נושאים • \(exercisesCountText(exercisesCount))"
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
    
    private var beltProgressRatio: Double {
        guard beltProgress.total > 0 else { return 0 }
        return Double(beltProgress.done) / Double(beltProgress.total)
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
                if tab == .byBelt {
                    VStack {
                        Spacer()

                        BeltArcPicker(
                            belts: belts,
                            selectedBelt: $selectedBelt,
                            isEnglish: isEnglish
                        )
                        .frame(width: 330, height: 124)
                        .padding(.bottom, 22)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(2.2)
                    .allowsHitTesting(!quickMenuOpen)
                }
            }
            
            BeltQuickMenuOverlay(
                isPresented: $quickMenuOpen,
                isEnglish: isEnglish,
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_GLOBAL_SEARCH_PICK")
            )
        ) { notif in
            guard let key = notif.object as? String else { return }
            pickedExercise = ExerciseSelection.fromSearchKey(key)
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
                  tab = .byBelt
              }
          }
      )
      .padding(.horizontal, 18)
      .padding(.top, 10)

      GeometryReader { geo in
          WhiteCard {
              VStack(spacing: 12) {
                  Text(isEnglish ? "Belt Topics" : "נושאים בחגורה")
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

                                          VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                                              Text(uiTopicTitle(entry.title))
                                                  .font(.system(size: 18, weight: .heavy))
                                                  .foregroundStyle(Color.white)
                                                  .frame(
                                                      maxWidth: .infinity,
                                                      alignment: isEnglish ? .leading : .trailing
                                                  )
                                                  .multilineTextAlignment(isEnglish ? .leading : .trailing)
                                            

                                              if let subtitle = entry.subtitle, !subtitle.isEmpty {
                                                  Text(subtitle)
                                                      .font(.system(size: 14, weight: .heavy))
                                                      .foregroundStyle(Color.white.opacity(0.92))
                                                      .frame(
                                                          maxWidth: .infinity,
                                                          alignment: isEnglish ? .leading : .trailing
                                                      )
                                                      .multilineTextAlignment(isEnglish ? .leading : .trailing)
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
                                                          VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
                                                              Text(uiTopicTitle(sub))
                                                                  .font(.system(size: 16, weight: .heavy))
                                                                  .foregroundStyle(Color.white.opacity(0.98))
                                                                  .frame(
                                                                      maxWidth: .infinity,
                                                                      alignment: isEnglish ? .leading : .trailing
                                                                  )
                                                                  .multilineTextAlignment(isEnglish ? .leading : .trailing)

                                                              Text(exercisesCountText(itemCount))
                                                                  .font(.system(size: 13, weight: .heavy))
                                                                  .foregroundStyle(Color.white.opacity(0.88))
                                                                  .frame(
                                                                      maxWidth: .infinity,
                                                                      alignment: isEnglish ? .leading : .trailing
                                                                  )
                                                                  .multilineTextAlignment(isEnglish ? .leading : .trailing)
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
                                                          Text(isEnglish ? "Full topic" : "כל הנושא")
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
      }
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

#Preview {
    NavigationStack {
        // ⚠️ בפריוויו הזה עדיין אין KmiRootLayout,
        // אז תראה "בלי" הסרגל הגלובאלי (זה תקין לפריוויו).
        BeltQuestionsByBeltView(belt: .orange)
    }
}
