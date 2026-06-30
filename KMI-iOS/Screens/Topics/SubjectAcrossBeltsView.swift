import SwiftUI
import Shared

fileprivate enum ExerciseMarkState: String {
    case unmarked
    case know
    case dontKnow
}

struct SubjectAcrossBeltsView: View {

    let subject: KMI_iOS.SubjectTopic
    let forcedSectionTitle: String?

    init(subject: KMI_iOS.SubjectTopic, forcedSectionTitle: String? = nil) {
        self.subject = subject
        self.forcedSectionTitle = forcedSectionTitle
    }

    // סדר חגורות כמו אצלך באנדרואיד
    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
    @State private var selectedBelt: Belt = .orange
    @State private var exerciseMarks: [String: ExerciseMarkState] = [:]
    @State private var activeExerciseMenu: ExerciseMenuContext? = nil
    @State private var activeInfoExercise: ExerciseMenuContext? = nil
    @State private var activeNoteExercise: ExerciseMenuContext? = nil
    @State private var noteText: String = ""
    @State private var favoriteExerciseIds: Set<String> = []
    @State private var excludedExerciseIds: Set<String> = []
    
    // ✅ קטלוג מה-Shared (כמו בשאר המסכים)
    private let catalog = CatalogData.shared.data

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

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    // MARK: - Local UI models (במקום SubjectItemsResolver מה-KMP)
    private struct UiItem: Identifiable, Hashable {
        let id: String
        let displayName: String
        let topicTitle: String
    }

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [UiItem]
    }

    private struct ExerciseMenuContext: Identifiable, Hashable {
        let id: String
        let belt: Belt
        let item: UiItem

        init(belt: Belt, item: UiItem) {
            self.belt = belt
            self.item = item
            self.id = "\(belt.id)::\(item.topicTitle)::\(item.displayName)"
        }
    }
    
    // MARK: - Filtering helpers (כמו SubjectTopicContentView)
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hardSubjectId(for subject: KMI_iOS.SubjectTopic) -> String? {

        switch subject.id {

        case "topic_breakfalls_rolls", "rolls_breakfalls":
            return "topic_breakfalls_rolls"

        case "kicks", "kicks_hard", "topic_kicks":
            return "topic_kicks"

        case "releases", "releases_root":
            return "releases"

        // ✅ עבודת ידיים
        case "hands_strikes", "topic_hands", "punches":
            return "hands_strikes"

        case "hands_elbows":
            return "hands_elbows"

        case "hands_stick_rifle":
            return "hands_stick_rifle"

        case "hands_all":
            return "hands_all"

        case "knife_defense":
            return "knife_defense"

        case "gun_threat_defense":
            return "gun_threat_defense"

        case "stick_defense":
            return "stick_defense"

        case "def_internal_punch", "def_internal_punches":
            return "def_internal_punch"

        case "def_internal_kick", "def_internal_kicks":
            return "def_internal_kick"

        case "def_external_punch", "def_external_punches":
            return "def_external_punch"

        case "def_external_kick", "def_external_kicks":
            return "def_external_kick"

        default:
            return nil
        }
    }

    private func uiSubjectTitle() -> String {
        let cleanId = subject.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isEnglish else { return cleanTitle }

        if let resolvedFromId = KmiEnglishTitleResolver.englishTitle(for: cleanId) {
            return resolvedFromId
        }

        return KmiEnglishTitleResolver.title(for: cleanTitle, isEnglish: true)
    }

    private func uiSectionTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnglish else { return clean }

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
    }

    private func sectionDirectlyMatchesForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forcedClean: String
    ) -> Bool {
        let idClean = section.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleClean = section.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return idClean == forcedClean || titleClean == forcedClean
    }

    private func sectionTreeContainsForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forcedClean: String
    ) -> Bool {
        if sectionDirectlyMatchesForcedSelection(section, forcedClean: forcedClean) {
            return true
        }

        return section.subSections.contains {
            sectionTreeContainsForcedSelection($0, forcedClean: forcedClean)
        }
    }

    private func sectionMatchesForcedSelection(
        _ section: HardSectionsCatalog.Section,
        forced: String?
    ) -> Bool {
        guard let forced,
              !forced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return true
        }

        let forcedClean = forced.trimmingCharacters(in: .whitespacesAndNewlines)

        return sectionTreeContainsForcedSelection(section, forcedClean: forcedClean)
    }

    private func findForcedSection(
        in sections: [HardSectionsCatalog.Section],
        forcedClean: String
    ) -> HardSectionsCatalog.Section? {
        for section in sections {
            if sectionDirectlyMatchesForcedSelection(section, forcedClean: forcedClean) {
                return section
            }

            if let childMatch = findForcedSection(
                in: section.subSections,
                forcedClean: forcedClean
            ) {
                return childMatch
            }
        }

        return nil
    }

    private func displayTitleForForcedSection(_ forced: String) -> String {
        let clean = forced.trimmingCharacters(in: .whitespacesAndNewlines)

        if let hardId = hardSubjectId(for: subject),
           let hardSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: hardId),
           let match = findForcedSection(in: hardSections, forcedClean: clean) {
            return uiSectionTitle(match.title)
        }

        return uiSectionTitle(clean)
    }

    private func uiExerciseTitle(_ title: String) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func exercisesCountText(_ count: Int) -> String {
        if isEnglish {
            return "exercises \(count)"
        } else {
            return "\(count) תרגילים"
        }
    }

    private var hasAnyExercises: Bool {
        belts.contains { belt in
            !sections(for: belt).isEmpty
        }
    }

    private func emptyExercisesMessage() -> String {
        let subjectTitle = uiSubjectTitle()

        if let forcedSectionTitle,
           !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let sectionTitle = displayTitleForForcedSection(forcedSectionTitle)

            return isEnglish
            ? "No exercises found for \"\(subjectTitle) / \(sectionTitle)\""
            : "לא נמצאו תרגילים עבור \"\(subjectTitle) / \(sectionTitle)\""
        }

        return isEnglish
        ? "No exercises found for \"\(subjectTitle)\""
        : "לא נמצאו תרגילים עבור \"\(subjectTitle)\""
    }

    private var totalExercisesAcrossBelts: Int {
        belts.reduce(0) { partial, belt in
            partial + sections(for: belt).reduce(0) { $0 + $1.items.count }
        }
    }

    private var visibleBeltsCount: Int {
        belts.filter { !sections(for: $0).isEmpty }.count
    }

    private func heroSubtitleText() -> String {
        if isEnglish {
            return "\(exercisesCountText(totalExercisesAcrossBelts)) · \(visibleBeltsCount) belts"
        }

        return "\(exercisesCountText(totalExercisesAcrossBelts)) · \(visibleBeltsCount) חגורות"
    }

    private func subjectSymbolName() -> String {
        let id = subject.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = subject.titleHeb.trimmingCharacters(in: .whitespacesAndNewlines)

        if id.contains("internal") || title.contains("פנימ") {
            return "arrow.down.left.and.arrow.up.right"
        }

        if id.contains("external") || title.contains("חיצונ") {
            return "arrow.up.forward.and.arrow.down.backward"
        }

        if id.contains("knife") || title.contains("סכין") {
            return "shield.lefthalf.filled"
        }

        if id.contains("gun") || title.contains("אקדח") {
            return "scope"
        }

        if id.contains("stick") || title.contains("מקל") || title.contains("רובה") {
            return "figure.fencing"
        }

        if id.contains("release") || title.contains("שחרור") || title.contains("חביקה") {
            return "hand.raised.fill"
        }

        if id.contains("kick") || title.contains("בעיטה") {
            return "figure.kickboxing"
        }

        if id.contains("hand") || id.contains("punch") || title.contains("יד") || title.contains("מרפק") {
            return "hand.tap.fill"
        }

        return "list.bullet.rectangle.fill"
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
        let combined = (subTopicTitle ?? "") + " " + item

        if let hint = subject.subTopicHint, !hint.isEmpty {
            let ok = norm(subTopicTitle ?? "").contains(norm(hint)) || norm(item).contains(norm(hint))
            if !ok { return false }
        }

        if !subject.includeItemKeywords.isEmpty {
            if !containsAny(combined, keywords: subject.includeItemKeywords) { return false }
        }

        if !containsAll(combined, keywords: subject.requireAllItemKeywords) { return false }

        if !containsNone(combined, keywords: subject.excludeItemKeywords) { return false }

        return true
    }

    private func appendHardSectionTree(
        _ sec: HardSectionsCatalog.Section,
        belt: Belt,
        into out: inout [UiSection],
        parentPath: [String] = [],
        forcedClean: String? = nil
    ) {
        let currentPath = parentPath + [sec.title]

        let shouldIncludeCurrentSection: Bool = {
            guard let forcedClean,
                  !forcedClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return true
            }

            return sectionDirectlyMatchesForcedSelection(sec, forcedClean: forcedClean)
        }()

        let items = HardSectionsCatalog.shared.itemsFor(sec, belt: belt)

        if shouldIncludeCurrentSection, !items.isEmpty {
            let uiItems = items.map { raw in
                UiItem(
                    id: "\(belt.id)::\(sec.id)::\(raw)",
                    displayName: raw,
                    topicTitle: currentPath.joined(separator: " / ")
                )
            }

            out.append(
                UiSection(
                    id: "\(belt.id)::\(sec.id)",
                    title: sec.title,
                    items: uiItems
                )
            )
        }

        for child in sec.subSections {
            if let forcedClean,
               !forcedClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !sectionTreeContainsForcedSelection(child, forcedClean: forcedClean) {
                continue
            }

            appendHardSectionTree(
                child,
                belt: belt,
                into: &out,
                parentPath: currentPath,
                forcedClean: forcedClean
            )
        }
    }

    private func toSharedSubject(_ local: KMI_iOS.SubjectTopic) -> Shared.SubjectTopic {
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
    
    private func sections(for belt: Belt) -> [UiSection] {

        if let hardId = hardSubjectId(for: subject),
           let hardSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: hardId),
           !hardSections.isEmpty {

            let filteredHardSections: [HardSectionsCatalog.Section]
            if let forcedSectionTitle, !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                filteredHardSections = hardSections.filter {
                    sectionMatchesForcedSelection($0, forced: forcedSectionTitle)
                }
            } else {
                filteredHardSections = hardSections
            }

            var hardOut: [UiSection] = []

            let forcedClean = forcedSectionTitle?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for sec in filteredHardSections {
                appendHardSectionTree(
                    sec,
                    belt: belt,
                    into: &hardOut,
                    forcedClean: forcedClean
                )
            }

            return hardOut
        }

        let sharedSubject = toSharedSubject(subject)

        let rawSections = SubjectItemsResolver.shared
            .resolveBySubject(belt: belt, subject: sharedSubject)

        let uiSections: [SubjectItemsResolver.UiSection]
        if let forcedSectionTitle, !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let forcedClean = forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)

            uiSections = rawSections.filter { section in
                section.title.trimmingCharacters(in: .whitespacesAndNewlines) == forcedClean
            }
        } else {
            uiSections = rawSections
        }

        var out: [UiSection] = []

        for sec in uiSections {
            let items = sec.items

            if !items.isEmpty {
                let uiItems = items.enumerated().map { index, item in
                    UiItem(
                        id: "\(belt.id)::\(sec.title)::\(index)::\(item.displayName)",
                        displayName: item.displayName,
                        topicTitle: sec.title
                    )
                }

                out.append(
                    UiSection(
                        id: "\(belt.id)::\(sec.title)",
                        title: sec.title,
                        items: uiItems
                    )
                )
            }
        }

        return out
    }

    private var heroIcon: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.20),
                        Color.purple.opacity(0.08),
                        Color.white.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 58, height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.purple.opacity(0.20), lineWidth: 1)
            )
            .overlay(
                Image(systemName: subjectSymbolName())
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Color.purple.opacity(0.78))
            )
    }
    
    var body: some View {
        ZStack {
            KmiAppBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {

               
                        if !hasAnyExercises {
                            WhiteCard {
                                VStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.purple.opacity(0.16),
                                                    Color.purple.opacity(0.06),
                                                    Color.white.opacity(0.92)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 58, height: 54)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                                .stroke(Color.purple.opacity(0.16), lineWidth: 1)
                                        )
                                        .overlay(
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .font(.system(size: 24, weight: .heavy))
                                                .foregroundStyle(Color.purple.opacity(0.72))
                                        )

                                    Text(tr("לא נמצאו תרגילים", "No exercises found"))
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)

                                    Text(emptyExercisesMessage())
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.58))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 10)
                                }
                                .padding(.vertical, 20)
                                .padding(.horizontal, 14)
                            }
                        }

                        ForEach(belts, id: \.self) { belt in

                            let secs = sections(for: belt)

                            if !secs.isEmpty {

                                VStack(spacing: 12) {

                                    beltSectionHeader(
                                        belt,
                                        count: secs.reduce(0) { $0 + $1.items.count }
                                    )

                                    VStack(spacing: 10) {
                                        ForEach(secs) { sec in
                                            VStack(spacing: 8) {
                                                if secs.count > 1 {
                                                    sectionTitlePill(
                                                        sec.title,
                                                        accent: beltAccent(belt)
                                                    )
                                                }

                                                ForEach(Array(sec.items.enumerated()), id: \.element.id) { index, it in
                                                    HStack(spacing: 8) {
                                                        Button {
                                                            toggleMark(
                                                                belt: belt,
                                                                item: it
                                                            )
                                                        } label: {
                                                            ExerciseMarkCircle(
                                                                state: markState(
                                                                    belt: belt,
                                                                    item: it
                                                                ),
                                                                accent: beltAccent(belt)
                                                            )
                                                        }
                                                        .buttonStyle(.plain)

                                                        BeltExerciseRowCard(
                                                            numberText: tr("מס׳ \(index + 1)", "No. \(index + 1)"),
                                                            title: uiExerciseTitle(it.displayName),
                                                            accent: beltAccent(belt),
                                                            isEnglish: isEnglish,
                                                            isFavorite: isFavorite(belt: belt, item: it),
                                                            isExcluded: isExcluded(belt: belt, item: it),
                                                            hasNote: !loadNote(belt: belt, item: it).isEmpty,
                                                            onInfoTap: {
                                                                activeExerciseMenu = ExerciseMenuContext(
                                                                    belt: belt,
                                                                    item: it
                                                                )
                                                            },
                                                            destination: {
                                                                ExerciseDetailView(
                                                                    belt: belt,
                                                                    topicTitle: it.topicTitle,
                                                                    item: it.displayName
                                                                )
                                                            }
                                                        )
                                                    }
                                                    .environment(\.layoutDirection, .leftToRight)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    beltCardFill(belt),
                                                    Color.white.opacity(0.94)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(beltAccent(belt).opacity(0.18), lineWidth: 1)
                                )
                                .shadow(color: beltAccent(belt).opacity(0.08), radius: 6, x: 0, y: 3)
                                .id(beltAnchorId(belt))
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 22)
                    }
                }
            }
        }
            .environment(\.layoutDirection, screenLayoutDirection)
            .onAppear {
                NotificationCenter.default.post(
                    name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                    object: uiSubjectTitle()
                )

                var loadedFavorites = Set<String>()
                var loadedExcluded = Set<String>()

                for b in belts {
                    loadedFavorites.formUnion(loadStringSet(favoritesStorageKey(for: b)))
                    loadedExcluded.formUnion(loadStringSet(excludedStorageKey(for: b)))

                    if !sections(for: b).isEmpty {
                        selectedBelt = b
                        break
                    }
                }

                favoriteExerciseIds = loadedFavorites
                excludedExerciseIds = loadedExcluded
            }
            .onDisappear {
            NotificationCenter.default.post(
                name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
                object: ""
            )
        }
        .navigationDestination(item: $activeInfoExercise) { context in
            ExerciseDetailView(
                belt: context.belt,
                topicTitle: context.item.topicTitle,
                item: context.item.displayName
            )
        }
        .sheet(item: $activeNoteExercise) { context in
            ExerciseNoteSheet(
                title: uiExerciseTitle(context.item.displayName),
                noteText: $noteText,
                isEnglish: isEnglish,
                onSave: {
                    saveNote(
                        belt: context.belt,
                        item: context.item,
                        value: noteText
                    )
                }
            )
        }
        .overlay {
            if let activeExerciseMenu {
                exerciseActionMenu(
                    context: activeExerciseMenu
                )
                .zIndex(999)
            }
        }
            }

    private var screenTopTitleBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 44)

            Text(uiSubjectTitle())
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(Color(red: 0.08, green: 0.11, blue: 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
    
        private func exerciseActionMenu(
            context: ExerciseMenuContext
        ) -> some View {
            ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    activeExerciseMenu = nil
                }

            VStack(spacing: 0) {
                exerciseMenuRow(title: tr("מידע", "Info")) {
                    activeExerciseMenu = nil
                    activeInfoExercise = context
                }

                exerciseMenuDivider

                exerciseMenuRow(
                    title: isFavorite(
                        belt: context.belt,
                        item: context.item
                    )
                    ? tr("הסר ממועדפים", "Remove from favorites")
                    : tr("הוסף למועדפים", "Add to favorites")
                ) {
                    toggleFavorite(
                        belt: context.belt,
                        item: context.item
                    )
                    activeExerciseMenu = nil
                }
                
                exerciseMenuDivider

                exerciseMenuRow(
                    title: isExcluded(
                        belt: context.belt,
                        item: context.item
                    )
                    ? tr("בטל החרגה מהתרגול", "Remove from excluded")
                    : tr("החרג מהתרגול", "Exclude from practice")
                ) {
                    toggleExcluded(
                        belt: context.belt,
                        item: context.item
                    )
                    activeExerciseMenu = nil
                }
                
                exerciseMenuDivider

                exerciseMenuRow(
                    title: loadNote(
                        belt: context.belt,
                        item: context.item
                    ).isEmpty
                    ? tr("הוסף הערה לתרגיל", "Add exercise note")
                    : tr("ערוך הערה לתרגיל", "Edit exercise note")
                ) {
                    noteText = loadNote(
                        belt: context.belt,
                        item: context.item
                    )
                    activeExerciseMenu = nil
                    activeNoteExercise = context
                }
            }
            .frame(width: 176)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color(red: 0.96, green: 0.94, blue: 0.98),
                                Color.white.opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func exerciseMenuRow(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
                .background(Color.white.opacity(0.001))
        }
        .buttonStyle(.plain)
    }

    private var exerciseMenuDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(height: 1)
    }
    
    private func beltSectionHeader(_ belt: Belt, count: Int) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if isEnglish {
                    beltHeaderIcon(belt)

                    Text(beltTitleText(belt))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(exercisesCountText(count))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                } else {
                    Text(exercisesCountText(count))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))

                    Text(beltTitleText(belt))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    beltHeaderIcon(belt)
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            Text(tr("←→ הזז לצד כדי לראות עוד נתונים ←→", "←→ Swipe sideways to see more data ←→"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    beltStatBox(
                        title: tr("יודע", "Know"),
                        value: "\(markCount(belt: belt, state: .know))",
                        fill: Color(red: 0.46, green: 0.78, blue: 0.55)
                    )

                    beltStatBox(
                        title: tr("לא יודע", "Don't know"),
                        value: "\(markCount(belt: belt, state: .dontKnow))",
                        fill: Color(red: 0.94, green: 0.58, blue: 0.38)
                    )

                    beltStatBox(
                        title: tr("מועדפים", "Favorites"),
                        value: "\(favoriteCount(belt: belt))",
                        fill: Color(red: 0.88, green: 0.45, blue: 0.66)
                    )

                    beltStatBox(
                        title: tr("מוחרגים", "Excluded"),
                        value: "\(excludedCount(belt: belt))",
                        fill: Color(red: 0.86, green: 0.42, blue: 0.50)
                    )
                    
                    beltStatBox(
                        title: tr("לא סומן", "Unmarked"),
                        value: "\(unmarkedCount(belt: belt))",
                        fill: Color(red: 0.84, green: 0.36, blue: 0.50)
                    )
                }
                .padding(.horizontal, 2)
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private func beltStatBox(
        title: String,
        value: String,
        fill: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 70)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(fill.opacity(0.78))
        )
    }

    private func beltHeaderIcon(_ belt: Belt) -> some View {
        Circle()
            .fill(beltAccent(belt).opacity(0.16))
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(beltAccent(belt).opacity(0.22), lineWidth: 1)
            )
            .overlay(
                Text(beltShortBadgeText(belt))
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(beltAccent(belt))
                    .minimumScaleFactor(0.75)
            )
    }

    private func beltShortBadgeText(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return isEnglish ? "W" : "ל"
        case .yellow:
            return isEnglish ? "Y" : "צ"
        case .orange:
            return isEnglish ? "O" : "כ"
        case .green:
            return isEnglish ? "G" : "י"
        case .blue:
            return isEnglish ? "B" : "כח"
        case .brown:
            return isEnglish ? "BR" : "ח"
        case .black:
            return isEnglish ? "BL" : "ש"
        default:
            return isEnglish ? "B" : "ח"
        }
    }

    private func sectionTitlePill(_ title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(accent)

                Text(uiSectionTitle(title))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.64))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            } else {
                Text(uiSectionTitle(title))
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.64))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "folder.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
    }

    private func beltAnchorId(_ belt: Belt) -> String {
        "belt::\(belt.id)"
    }

    private func beltCardFill(_ belt: Belt) -> Color {
        switch belt {
        case .yellow:
            return Color(red: 1.00, green: 0.97, blue: 0.86)
        case .orange:
            return Color(red: 0.99, green: 0.93, blue: 0.84)
        case .green:
            return Color(red: 0.91, green: 0.97, blue: 0.91)
        case .blue:
            return Color(red: 0.90, green: 0.95, blue: 1.00)
        case .brown:
            return Color(red: 0.95, green: 0.91, blue: 0.86)
        case .black:
            return Color(red: 0.90, green: 0.90, blue: 0.92)
        default:
            return Color.white.opacity(0.94)
        }
    }

    private func beltAccent(_ belt: Belt) -> Color {
        switch belt {
        case .yellow:
            return Color(red: 0.95, green: 0.82, blue: 0.18)
        case .orange:
            return Color(red: 0.96, green: 0.62, blue: 0.16)
        case .green:
            return Color(red: 0.22, green: 0.76, blue: 0.35)
        case .blue:
            return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:
            return Color(red: 0.57, green: 0.38, blue: 0.24)
        case .black:
            return Color(red: 0.42, green: 0.42, blue: 0.46)
        default:
            return Color.black.opacity(0.25)
        }
    }

    private func markKey(
        belt: Belt,
        item: UiItem
    ) -> String {
        let topic = item.topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = item.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.subject.mark.\(belt.id).\(topic).\(title)"
    }
    
    private func markState(
        belt: Belt,
        item: UiItem
    ) -> ExerciseMarkState {
        let key = markKey(belt: belt, item: item)

        if let state = exerciseMarks[key] {
            return state
        }

        if let raw = UserDefaults.standard.string(forKey: key),
           let savedState = ExerciseMarkState(rawValue: raw) {
            return savedState
        }

        return .unmarked
    }
    
    private func toggleMark(
        belt: Belt,
        item: UiItem
    ) {
        let key = markKey(belt: belt, item: item)
        let current = markState(belt: belt, item: item)

        let nextState: ExerciseMarkState

        switch current {
        case .unmarked:
            nextState = .know
        case .know:
            nextState = .dontKnow
        case .dontKnow:
            nextState = .unmarked
        }

        exerciseMarks[key] = nextState

        if nextState == .unmarked {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(nextState.rawValue, forKey: key)
        }
    }
    
    private func allItemsForBelt(_ belt: Belt) -> [UiItem] {
        sections(for: belt).flatMap { $0.items }
    }

    private func markCount(
        belt: Belt,
        state: ExerciseMarkState
    ) -> Int {
        allItemsForBelt(belt).filter { item in
            markState(belt: belt, item: item) == state
        }.count
    }

    private func unmarkedCount(
        belt: Belt
    ) -> Int {
        markCount(belt: belt, state: .unmarked)
    }

    private func exerciseId(
        belt: Belt,
        item: UiItem
    ) -> String {
        markKey(belt: belt, item: item)
    }

    private func isFavorite(
        belt: Belt,
        item: UiItem
    ) -> Bool {
        let id = exerciseId(belt: belt, item: item)
        return favoriteExerciseIds.contains(id) ||
        loadStringSet(favoritesStorageKey(for: belt)).contains(id)
    }

    private func isExcluded(
        belt: Belt,
        item: UiItem
    ) -> Bool {
        let id = exerciseId(belt: belt, item: item)
        return excludedExerciseIds.contains(id) ||
        loadStringSet(excludedStorageKey(for: belt)).contains(id)
    }
    
    private func favoritesStorageKey(for belt: Belt) -> String {
        "kmi.subject.favorites.\(belt.id)"
    }

    private func excludedStorageKey(for belt: Belt) -> String {
        "kmi.subject.excluded.\(belt.id)"
    }

    private func noteStorageKey(
        belt: Belt,
        item: UiItem
    ) -> String {
        "kmi.subject.note.\(exerciseId(belt: belt, item: item))"
    }

    private func loadNote(
        belt: Belt,
        item: UiItem
    ) -> String {
        UserDefaults.standard.string(
            forKey: noteStorageKey(belt: belt, item: item)
        ) ?? ""
    }

    private func saveNote(
        belt: Belt,
        item: UiItem,
        value: String
    ) {
        let key = noteStorageKey(belt: belt, item: item)
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(clean, forKey: key)
        }
    }
    
    private func loadStringSet(_ key: String) -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(values)
    }

    private func saveStringSet(_ values: Set<String>, key: String) {
        UserDefaults.standard.set(Array(values), forKey: key)
    }
    
    private func toggleFavorite(
        belt: Belt,
        item: UiItem
    ) {
        let id = exerciseId(belt: belt, item: item)
        let key = favoritesStorageKey(for: belt)

        var values = loadStringSet(key)
        values.formSymmetricDifference([id])

        favoriteExerciseIds = values
        saveStringSet(values, key: key)
    }
    
    private func toggleExcluded(
        belt: Belt,
        item: UiItem
    ) {
        let id = exerciseId(belt: belt, item: item)
        let key = excludedStorageKey(for: belt)

        var values = loadStringSet(key)
        values.formSymmetricDifference([id])

        excludedExerciseIds = values
        saveStringSet(values, key: key)
    }
    
    private func favoriteCount(
        belt: Belt
    ) -> Int {
        let saved = loadStringSet(favoritesStorageKey(for: belt))

        return allItemsForBelt(belt).filter { item in
            let id = exerciseId(belt: belt, item: item)
            return favoriteExerciseIds.contains(id) || saved.contains(id)
        }.count
    }

    private func excludedCount(
        belt: Belt
    ) -> Int {
        let saved = loadStringSet(excludedStorageKey(for: belt))

        return allItemsForBelt(belt).filter { item in
            let id = exerciseId(belt: belt, item: item)
            return excludedExerciseIds.contains(id) || saved.contains(id)
        }.count
    }
    
    private func beltTitleText(_ belt: Belt) -> String {
        switch belt {
        case .white:
            return isEnglish ? "White Belt" : "חגורה לבנה"
        case .yellow:
            return isEnglish ? "Yellow Belt" : "חגורה צהובה"
        case .orange:
            return isEnglish ? "Orange Belt" : "חגורה כתומה"
        case .green:
            return isEnglish ? "Green Belt" : "חגורה ירוקה"
        case .blue:
            return isEnglish ? "Blue Belt" : "חגורה כחולה"
        case .brown:
            return isEnglish ? "Brown Belt" : "חגורה חומה"
        case .black:
            return isEnglish ? "Black Belt" : "חגורה שחורה"
        default:
            return isEnglish ? "Belt" : "חגורה"
        }
    }
}

private struct BeltExerciseRowCard<Destination: View>: View {
    let numberText: String
    let title: String
    let accent: Color
    let isEnglish: Bool
    let isFavorite: Bool
    let isExcluded: Bool
    let hasNote: Bool
    let onInfoTap: () -> Void
    let destination: () -> Destination
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    var body: some View {
        ZStack(alignment: isEnglish ? .topLeading : .topTrailing) {
            HStack(spacing: 8) {
                if isEnglish {
                    infoButton
                    titleNavigation
                } else {
                    titleNavigation
                    infoButton
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 5)
            
            exerciseNumberBadge
                .padding(isEnglish ? .leading : .trailing, 38)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isExcluded ? Color.white.opacity(0.72) : Color.white.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 4, x: 0, y: 2)
    }
    
    private var exerciseNumberBadge: some View {
        Text(numberText)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color.black.opacity(0.78))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.96))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            )
    }
    
    private var infoButton: some View {
        Button {
            onInfoTap()
        } label: {
            ExerciseInfoCircle()
        }
        .buttonStyle(.plain)
    }
    
    private var titleNavigation: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 5) {
                if isEnglish {
                    statusBadges
                    
                    Text(title)
                        .font(.system(size: 13.8, weight: .heavy))
                        .foregroundStyle(isExcluded ? Color.black.opacity(0.42) : Color.black.opacity(0.84))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                } else {
                    Text(title)
                        .font(.system(size: 13.8, weight: .heavy))
                        .foregroundStyle(isExcluded ? Color.black.opacity(0.42) : Color.black.opacity(0.84))
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    
                    statusBadges
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusBadges: some View {
        HStack(spacing: 3) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.orange.opacity(0.88))
            }

            if isExcluded {
                Image(systemName: "slash.circle.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.red.opacity(0.78))
            }

            if hasNote {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.blue.opacity(0.78))
            }
        }
    }
}

private struct ExerciseNoteSheet: View {
    let title: String
    @Binding var noteText: String
    let isEnglish: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    
        var body: some View {
            NavigationStack {
                VStack(spacing: 14) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)

                    TextEditor(text: $noteText)
                        .frame(minHeight: 180)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    Spacer()
                }
                .padding(18)
                .background(KmiAppBackground())
                .navigationTitle(isEnglish ? "Exercise note" : "הערה לתרגיל")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEnglish ? "Save" : "שמור") {
                            onSave()
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button(isEnglish ? "Close" : "סגור") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
private struct ExerciseInfoCircle: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.46))
                .frame(width: 24, height: 24)

            Image(systemName: "info")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

private struct ExerciseMarkCircle: View {
    let state: ExerciseMarkState
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundFill)
                .frame(width: 27, height: 27)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1.4)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

            if state == .know {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }

            if state == .dontKnow {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
            }
        }
    }

    private var backgroundFill: Color {
        switch state {
        case .unmarked:
            return Color.white
        case .know:
            return accent
        case .dontKnow:
            return Color.red.opacity(0.82)
        }
    }

    private var borderColor: Color {
        switch state {
        case .unmarked:
            return Color.black.opacity(0.18)
        case .know:
            return accent.opacity(0.75)
        case .dontKnow:
            return Color.red.opacity(0.70)
        }
    }
}

// MARK: - Belt carousel (Snap + Center highlight)
private struct BeltCarousel: View {

    let belts: [Belt]
    @Binding var selectedBelt: Belt
    let isEnglish: Bool
    let hasContent: (Belt) -> Bool
    let onSelect: (Belt) -> Void

    @State private var scrollId: Belt?

    var body: some View {
        GeometryReader { outer in
            let midX = outer.frame(in: .global).midX

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: -10) {   // ✅ חפיפה (כמו גלגל)
                    ForEach(belts, id: \.self) { b in
                        BeltWheelItem(
                            belt: b,
                            selectedBelt: $selectedBelt,
                            enabled: hasContent(b),
                            midX: midX,
                            isEnglish: isEnglish
                        ) {
                            selectedBelt = b
                            scrollId = b
                            onSelect(b)
                        }
                        .id(b)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 86) // ✅ מקום ל"קשת"
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollId, anchor: .center)
            .onAppear { scrollId = selectedBelt }
            .onChange(of: selectedBelt) { _, newValue in scrollId = newValue }
        }
        .frame(height: 90)
    }
}

// MARK: - Single item with arc effect
private struct BeltWheelItem: View {

    let belt: Belt
    @Binding var selectedBelt: Belt
    let enabled: Bool
    let midX: CGFloat
    let isEnglish: Bool
    let onTap: () -> Void

    private var isSelected: Bool { selectedBelt == belt }

    var body: some View {
        GeometryReader { geo in
            let x = geo.frame(in: .global).midX
            let dist = abs(x - midX)

            // ✅ נורמליזציה של המרחק (0 במרכז, 1+ בצד)
            let t = min(dist / 160.0, 1.0)

            // ✅ מרכז גדול, צדדים קטנים
            let scale = (1.18 - (t * 0.35))

            // ✅ קשת: צדדים "עולים" למעלה
            let y = -(t * 16.0)

            Button {
                guard enabled else { return }
                onTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(beltColor(belt).opacity(isSelected ? 1.0 : 0.92))
                        .shadow(color: Color.black.opacity(isSelected ? 0.22 : 0.14),
                                radius: isSelected ? 10 : 7,
                                x: 0, y: isSelected ? 5 : 4)

                    // טבעת דקה כמו באנדרואיד
                    Circle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                    Text(beltShortTitle(belt))
                        .font(
                            isEnglish
                            ? (isSelected ? .subheadline.weight(.heavy) : .caption.weight(.bold))
                            : (isSelected ? .headline.weight(.heavy) : .subheadline.weight(.bold))
                        )
                        .foregroundStyle(textColor(for: belt))
                        .minimumScaleFactor(0.82)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
                .frame(width: 60, height: 60)
                .opacity(enabled ? 1.0 : 0.30)
                .scaleEffect(scale)
                .offset(y: y)
                .animation(.easeInOut(duration: 0.16), value: isSelected)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
        .frame(width: 64, height: 86) // ✅ רוחב קטן + גובה לקשת
    }

    private func beltShortTitle(_ b: Belt) -> String {
        switch b {
        case .white:
            return isEnglish ? "WHT" : "לבן"

        case .yellow:
            return isEnglish ? "YLW" : "צהוב"

        case .orange:
            return isEnglish ? "ORG" : "כתום"

        case .green:
            return isEnglish ? "GRN" : "ירוק"

        case .blue:
            return isEnglish ? "BLU" : "כחול"

        case .brown:
            return isEnglish ? "BRN" : "חום"

        case .black:
            return isEnglish ? "BLK" : "שחור"

        default:
            return b.heb
        }
    }

    private func beltColor(_ b: Belt) -> Color {
        switch b {
        case .white:  return Color.white
        case .yellow: return Color(red: 0.98, green: 0.84, blue: 0.25)
        case .orange: return Color(red: 0.98, green: 0.62, blue: 0.20)
        case .green:  return Color(red: 0.20, green: 0.75, blue: 0.35)
        case .blue:   return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:  return Color(red: 0.55, green: 0.38, blue: 0.24)
        case .black:  return Color(red: 0.15, green: 0.15, blue: 0.16)
        default:      return Color.gray
        }
    }

    private func textColor(for b: Belt) -> Color {
        // טקסט כהה על לבן/צהוב/כתום, לבן על כחול/חום/שחור/ירוק
        switch b {
        case .white, .yellow, .orange:
            return Color.black.opacity(0.82)
        default:
            return Color.white.opacity(0.92)
        }
    }
}
