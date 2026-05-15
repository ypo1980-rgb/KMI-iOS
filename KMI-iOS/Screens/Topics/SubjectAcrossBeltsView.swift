import SwiftUI
import Shared

struct SubjectAcrossBeltsView: View {

    let subject: KMI_iOS.SubjectTopic
    let forcedSectionTitle: String?

    init(subject: KMI_iOS.SubjectTopic, forcedSectionTitle: String? = nil) {
        self.subject = subject
        self.forcedSectionTitle = forcedSectionTitle
    }

    // סדר חגורות כמו אצלך באנדרואיד
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    @State private var selectedBelt: Belt = .orange

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
    private struct UiItem: Identifiable {
        let id: String
        let displayName: String
        let topicTitle: String
    }

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [UiItem]
    }

    // MARK: - Filtering helpers (כמו SubjectTopicContentView)
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hardSubjectId(for subject: KMI_iOS.SubjectTopic) -> String? {

        switch subject.id {

        case "topic_breakfalls_rolls", "rolls_breakfalls":
            return "topic_breakfalls_rolls"

        case "kicks":
            return "topic_kicks"

        case "releases":
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

        case "def_internal_punches":
            return "def_internal_punch"

        case "def_internal_kicks":
            return "def_internal_kick"

        case "def_external_punches":
            return "def_external_punch"

        case "def_external_kicks":
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
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(Color.purple.opacity(0.78))
            )
    }
    
    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 12) {
                                HStack(spacing: 12) {
                                    if isEnglish {
                                        heroIcon

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(uiSubjectTitle())
                                                .font(.system(size: 23, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.86))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)

                                            Text(heroSubtitleText())
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.52))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .multilineTextAlignment(.leading)
                                        }
                                    } else {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(uiSubjectTitle())
                                                .font(.system(size: 23, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.86))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .multilineTextAlignment(.trailing)
                                                .lineLimit(2)

                                            Text(heroSubtitleText())
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.52))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .multilineTextAlignment(.trailing)
                                        }

                                        heroIcon
                                    }
                                }

                                if !subject.description.isEmpty {
                                    Text(subject.description)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.56))
                                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                                        .multilineTextAlignment(primaryTextAlignment)
                                }

                                if let forcedSectionTitle,
                                   !forcedSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(displayTitleForForcedSection(forcedSectionTitle))
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundStyle(Color.purple.opacity(0.78))
                                        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                                        .multilineTextAlignment(primaryTextAlignment)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.purple.opacity(0.09))
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }

                        // ✅ קרוסלה אמיתית: Snap למרכז + מרכז מודגש
                        WhiteCard {
                            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
                                HStack(spacing: 10) {
                                    if isEnglish {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(tr("חגורות", "Belts"))
                                                .font(.system(size: 19, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.84))
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Text(tr("בחר חגורה להצגת התרגילים", "Choose a belt to view exercises"))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.50))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }

                                        Image(systemName: "circle.grid.3x3.fill")
                                            .font(.system(size: 17, weight: .heavy))
                                            .foregroundStyle(Color.purple.opacity(0.72))
                                            .frame(width: 36, height: 36)
                                            .background(Color.purple.opacity(0.10))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        Image(systemName: "circle.grid.3x3.fill")
                                            .font(.system(size: 17, weight: .heavy))
                                            .foregroundStyle(Color.purple.opacity(0.72))
                                            .frame(width: 36, height: 36)
                                            .background(Color.purple.opacity(0.10))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(tr("חגורות", "Belts"))
                                                .font(.system(size: 19, weight: .heavy))
                                                .foregroundStyle(Color.black.opacity(0.84))
                                                .frame(maxWidth: .infinity, alignment: .trailing)

                                            Text(tr("בחר חגורה להצגת התרגילים", "Choose a belt to view exercises"))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.black.opacity(0.50))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                    }
                                }

                                BeltCarousel(
                                    belts: belts,
                                    selectedBelt: $selectedBelt,
                                    isEnglish: isEnglish,
                                    hasContent: { b in !sections(for: b).isEmpty },
                                    onSelect: { b in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            proxy.scrollTo(beltAnchorId(b), anchor: .top)
                                        }
                                    }
                                )
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }

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

                                                ForEach(sec.items) { it in
                                                    NavigationLink {
                                                        ExerciseDetailView(
                                                            belt: belt,
                                                            topicTitle: it.topicTitle,
                                                            item: it.displayName
                                                        )
                                                    } label: {
                                                        BeltExerciseRowCard(
                                                            title: uiExerciseTitle(it.displayName),
                                                            accent: beltAccent(belt),
                                                            isEnglish: isEnglish
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 23, style: .continuous)
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
                                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                                        .stroke(beltAccent(belt).opacity(0.20), lineWidth: 1)
                                )
                                .shadow(color: beltAccent(belt).opacity(0.10), radius: 8, x: 0, y: 4)
                                .id(beltAnchorId(belt))
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .navigationTitle(tr("לפי נושא", "By Topic"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for b in belts {
                if !sections(for: b).isEmpty {
                    selectedBelt = b
                    break
                }
            }
        }
    }

    private func beltSectionHeader(_ belt: Belt, count: Int) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                beltHeaderIcon(belt)

                VStack(alignment: .leading, spacing: 3) {
                    Text(beltTitleText(belt))
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(exercisesCountText(count))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(beltTitleText(belt))
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(beltAccent(belt))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(exercisesCountText(count))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.52))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                beltHeaderIcon(belt)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private func beltHeaderIcon(_ belt: Belt) -> some View {
        Circle()
            .fill(beltAccent(belt).opacity(0.16))
            .frame(width: 38, height: 38)
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

private struct BeltExerciseRowCard: View {
    let title: String
    let accent: Color
    let isEnglish: Bool

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            if isEnglish {
                accentBar
                visualBlock
                titleBlock

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))
            } else {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))

                titleBlock
                visualBlock
                accentBar
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.93))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 4, x: 0, y: 2)
    }

    private var titleBlock: some View {
        VStack(alignment: stackAlignment, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.84))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .lineLimit(2)
        }
    }

    private var visualBlock: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.18),
                        accent.opacity(0.08),
                        Color.white.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "figure.martial.arts")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(accent)
            )
            .frame(width: 50, height: 44)
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(accent)
            .frame(width: 6, height: 44)
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
