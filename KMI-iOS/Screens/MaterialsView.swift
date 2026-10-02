import SwiftUI
import UIKit
import Shared
import AVFoundation
import Combine

/*
 * מעדכן את ממשק המשתמש לפי סיום ההקראה בפועל,
 * ללא חישוב משוער לפי אורך הטקסט.
 */
private final class MaterialsSpeechDelegate:
    NSObject,
    ObservableObject,
    AVSpeechSynthesizerDelegate {

    var onFinish: (() -> Void)?

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinish?()
        }
    }
}

struct MaterialsView: View {
    let belt: Belt
    let topicTitle: String
    let subTopicTitle: String?

    @Environment(\.colorScheme)
    private var colorScheme
    
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    /*
     * מקור האמת לתפקיד הפעיל.
     *
     * AppStorage מעדכן את MaterialsView מיד כאשר המשתמש
     * עובר בין מצב מאמן למצב מתאמן.
     */
    @AppStorage("user_role")
    private var storedActiveUserRole: String = ""

    @AppStorage("role")
    private var storedLegacyUserRole: String = ""

    /*
     * מפתחות התאימות שבהם משתמש
     * גם ה-Router / AuthViewModel.
     */
    @AppStorage("userRole")
    private var storedCamelCaseUserRole: String = ""

    @AppStorage("profile_role")
    private var storedProfileUserRole: String = ""

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

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var onSummary: (Belt, String, String?) -> Void = { _, _, _ in }
    var onPractice: (Belt, String) -> Void = { _, _ in }
    var onOpenSubscription: () -> Void = {}

    /*
     * מקביל לפרמטר isCoach באנדרואיד.
     *
     * נעשה בו שימוש רק כאשר עדיין לא נשמר תפקיד פעיל.
     */
    var isCoach: Bool = false

    private var hasFullAccessForPractice: Bool {
        let defaults = UserDefaults.standard
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)

        let accessUntil = Int64(defaults.integer(forKey: "sub_access_until"))

        return defaults.bool(forKey: "has_full_access") ||
        defaults.bool(forKey: "full_access") ||
        defaults.bool(forKey: "subscription_active") ||
        defaults.bool(forKey: "is_subscribed") ||
        defaults.bool(forKey: "google_subscription_verified") ||
        accessUntil > nowMillis
    }

    private var isPracticeLocked: Bool {
        !hasFullAccessForPractice
    }

    /*
     * סדר העדיפויות זהה לאנדרואיד:
     *
     * 1. user_role — התפקיד הפעיל.
     * 2. role — מפתח ישן לצורך תאימות.
     * 3. isCoach — הערך שהמסך המארח העביר.
     */
    private var effectiveIsCoach: Bool {

        func normalizedRole(
            _ value: String
        ) -> String {

            value
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()
        }

        let roles = [
            storedActiveUserRole,
            storedLegacyUserRole,
            storedCamelCaseUserRole,
            storedProfileUserRole
        ]
        .map(normalizedRole)
        .filter {
            !$0.isEmpty
        }

        let coachRoles:
            Set<String> = [

                "coach",
                "trainer",
                "instructor",
                "מאמן",
                "coach_user",
                "kmi_coach"
            ]

        let traineeRoles:
            Set<String> = [

                "trainee",
                "student",
                "מתאמן"
            ]

        /*
         * כמו ב-ContentView:
         * אם אחד ממקורות התפקיד אומר Coach,
         * הוא גובר על fallback ישן.
         */
        if roles.contains(
            where: {
                coachRoles.contains($0)
            }
        ) {
            return true
        }

        if roles.contains(
            where: {
                traineeRoles.contains($0)
            }
        ) {
            return false
        }

        return isCoach
    }

    fileprivate enum RowMark: String {
        case mastered
        case partiallyKnown
        case unknown
    }

    /*
     * סטטוסי המאמן נשמרים בנפרד לחלוטין
     * מסימוני יודע / לא יודע של המתאמן.
     */
    fileprivate enum CoachMaterialStatus: String, CaseIterable {
        case notTaught = "not_taught"
        case taught = "taught"
        case practiced = "practiced"
        case needsReinforcement = "needs_reinforcement"
    }

    fileprivate struct CoachMaterialProgress:
        Equatable {

        let selectedStatuses:
            Set<CoachMaterialStatus>

        let updatedAtByStatus:
            [CoachMaterialStatus: Int64]

        init(
            selectedStatuses:
                Set<CoachMaterialStatus> = [],
            updatedAtByStatus:
                [CoachMaterialStatus: Int64] = [:]
        ) {

            self.selectedStatuses =
                selectedStatuses

            self.updatedAtByStatus =
                updatedAtByStatus
        }

        func isSelected(
            _ status: CoachMaterialStatus
        ) -> Bool {

            selectedStatuses
                .contains(
                    status
                )
        }

        func updatedAt(
            for status:
                CoachMaterialStatus
        ) -> Int64 {

            updatedAtByStatus[
                status
            ] ?? 0
        }

        /*
         * תאימות לקוד הישן.
         *
         * אם נבחרו שני סטטוסים,
         * מחזירים את המתקדם יותר
         * רק כ-fallback למקומות שעוד
         * משתמשים ב-progress.status.
         */
        var status:
            CoachMaterialStatus {

            if selectedStatuses
                .contains(
                    .needsReinforcement
                ) {

                return .needsReinforcement
            }

            if selectedStatuses
                .contains(
                    .practiced
                ) {

                return .practiced
            }

            if selectedStatuses
                .contains(
                    .taught
                ) {

                return .taught
            }

            return .notTaught
        }

        var updatedAt:
            Int64 {

            updatedAt(
                for:
                    status
            )
        }
    }

    private struct ExerciseRow: Identifiable, Hashable {
        let id: String
        let canonicalId: String
        let statusId: String
        let rawItem: String
        let displayName: String
    }

    @State private var favorites: Set<String> = []
    @State private var excluded: Set<String> = []
    @State private var marks: [String: RowMark?] = [:]

    /*
     * זמן העדכון האחרון של סטטוס המתאמן.
     *
     * זהה למבנה Android:
     * trainee_material_updated_at_<belt>_<topicKey>_<statusId>
     */
    @State private var traineeUpdatedAtStates:
        [String: Int64] = [:]

    /*
     * מפת סטטוסים נפרדת למצב מאמן.
     *
     * המפתח הוא statusId הקנוני של התרגיל.
     */
    @State private var coachProgressStates:
        [String: CoachMaterialProgress] = [:]

    @State private var notes: [String: String] = [:]

    @State private var selectedInfoRow: ExerciseRow? = nil
    @State private var selectedNoteRow: ExerciseRow? = nil
    @State private var noteDraft: String = ""

    @State private var refreshToken = UUID()

    @State private var toastMessage: String? = nil
    @State private var showResetConfirmation: Bool = false

    /*
     * פתיחת כרטיס ההערה הכללית של
     * הנושא או תת־הנושא הנוכחי.
     */
    @State private var showGeneralNote: Bool = false

    @State private var generatedPdfURL: URL? = nil
    @State private var showPdfShareSheet: Bool = false

    @State private var speechSynth = AVSpeechSynthesizer()
    @StateObject private var speechDelegate =
        MaterialsSpeechDelegate()

    @State private var isSpeakingExplanation: Bool = false

    @State private var openedNestedSubTopic: String? = nil

    private var topicUi: String {
        let clean = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "כללי" : clean
    }

    private var subTopicUi: String? {
        guard let subTopicTitle else { return nil }
        let clean = subTopicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func normalizedMaterialTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isDefenseLevelOneTitle(_ value: String) -> Bool {
        let clean = normalizedMaterialTitle(value)

        return clean == "הגנות נגד מכות" ||
        clean == "הגנות נגד בעיטות" ||
        clean == "הגנות - סכין"
    }

    private var materialRootTopic: String {
        if subTopicUi == nil && isDefenseLevelOneTitle(topicUi) {
            return "הגנות"
        }

        return topicUi
    }

    private var materialParentSubTopic: String? {
        if let subTopicUi {
            return subTopicUi
        }

        if isDefenseLevelOneTitle(topicUi) {
            return topicUi
        }

        return nil
    }

    private var effectiveSubTopicUi: String? {
        openedNestedSubTopic ?? materialParentSubTopic
    }

    private var topicKey: String {
        guard let materialParentSubTopic else {
            return materialRootTopic
        }

        if let openedNestedSubTopic,
           !openedNestedSubTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(materialRootTopic)__\(materialParentSubTopic)__\(openedNestedSubTopic)"
        }

        return "\(materialRootTopic)__\(materialParentSubTopic)"
    }

    private var scopeKey: String {
        "\(belt.id)||\(materialRootTopic)||\(materialParentSubTopic ?? "")||\(openedNestedSubTopic ?? "")"
    }

    /*
     * ההערה הכללית של הנושא שמוצג כרגע.
     *
     * סדר העדיפויות:
     * 1. תת־נושא פנימי.
     * 2. תת־נושא רגיל.
     * 3. נושא ראשי.
     *
     * תוכן ההערה מגיע מ־ContentRepo המשותף,
     * שהוא מקור האמת גם ל־Android וגם ל־iOS.
     */
    private var currentGeneralNote: String? {
        let repository = ContentRepo.shared
        let note: String?

        if let openedNestedSubTopic {
            let cleanNestedSubTopic = openedNestedSubTopic
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanNestedSubTopic.isEmpty,
               let materialParentSubTopic {
                note = repository.getNestedSubTopicGeneralNote(
                    belt: belt,
                    topicTitle: materialRootTopic
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    subTopicTitle: materialParentSubTopic
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    nestedSubTopicTitle: cleanNestedSubTopic
                )
            } else {
                note = nil
            }
        } else if let materialParentSubTopic {
            note = repository.getSubTopicGeneralNote(
                belt: belt,
                topicTitle: materialRootTopic
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                subTopicTitle: materialParentSubTopic
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else {
            note = repository.getTopicGeneralNote(
                belt: belt,
                topicTitle: materialRootTopic
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let cleanNote = note?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cleanNote, !cleanNote.isEmpty else {
            return nil
        }

        return cleanNote
    }

    private func normalizeStatusPart(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func canonicalIdForStorage(rawItem: String) -> String {
        let item = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(belt.id)||\(materialRootTopic)||\(effectiveSubTopicUi ?? "")||\(item)"
    }

    private func statusIdForStorage(index: Int, rawItem: String) -> String {
        let cleanItem = normalizeStatusPart(rawItem)
        return "status_\(belt.id)_\(topicKey)_\(index)_\(cleanItem)"
    }

    private var materialItems: [String] {
        let cleanRootTopic = materialRootTopic
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let materialParentSubTopic {
            let cleanParentSubTopic = materialParentSubTopic
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let openedNestedSubTopic,
               !openedNestedSubTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let nestedItems = ContentRepo.shared.getNestedItemsFor(
                    belt: belt,
                    topicTitle: cleanRootTopic,
                    subTopicTitle: cleanParentSubTopic,
                    nestedSubTopicTitle: openedNestedSubTopic
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
                .removingDuplicatesKeepingOrder()

                if !nestedItems.isEmpty {
                    return nestedItems
                }
            }

            let nestedTitles = ContentRepo.shared.getNestedSubTopicTitles(
                belt: belt,
                topicTitle: cleanRootTopic,
                subTopicTitle: cleanParentSubTopic
            )
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
            }
            .removingDuplicatesKeepingOrder()

            if !nestedTitles.isEmpty {
                let nestedItems = nestedTitles.flatMap { nestedTitle in
                    ContentRepo.shared.getNestedItemsFor(
                        belt: belt,
                        topicTitle: cleanRootTopic,
                        subTopicTitle: cleanParentSubTopic,
                        nestedSubTopicTitle: nestedTitle
                    )
                }
                .removingDuplicatesKeepingOrder()

                if !nestedItems.isEmpty {
                    return nestedItems
                }
            }

            let parentItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanRootTopic,
                subTopicTitle: cleanParentSubTopic
            )
            .removingDuplicatesKeepingOrder()

            if !parentItems.isEmpty {
                return parentItems
            }

            let originalTopicItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: topicUi,
                subTopicTitle: subTopicUi
            )
            .removingDuplicatesKeepingOrder()

            if !originalTopicItems.isEmpty {
                return originalTopicItems
            }

            let parentAsTopicItems = ContentRepo.shared.getAllItemsFor(
                belt: belt,
                topicTitle: cleanParentSubTopic,
                subTopicTitle: nil
            )
            .removingDuplicatesKeepingOrder()

            if !parentAsTopicItems.isEmpty {
                return parentAsTopicItems
            }
        }

        let rootItems = ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: cleanRootTopic,
            subTopicTitle: nil
        )
        .removingDuplicatesKeepingOrder()

        if !rootItems.isEmpty {
            return rootItems
        }

        return ContentRepo.shared.getAllItemsFor(
            belt: belt,
            topicTitle: topicUi,
            subTopicTitle: subTopicUi
        )
        .removingDuplicatesKeepingOrder()
    }

    private var rows: [ExerciseRow] {
        var seenStatusIds = Set<String>()

        return materialItems
            .enumerated()
            .map { index, raw in
                let canonical = canonicalIdForStorage(rawItem: raw)
                let status = statusIdForStorage(index: index, rawItem: raw)

                return ExerciseRow(
                    id: status,
                    canonicalId: canonical,
                    statusId: status,
                    rawItem: raw,
                    displayName: displayName(for: raw)
                )
            }
            .filter { row in
                seenStatusIds.insert(row.statusId).inserted
            }
    }

    private var headerTitle: String {
        /*
         * התאמה לאנדרואיד:
         *
         * נושא רגיל       -> שם הנושא
         * תת־נושא         -> שם תת־הנושא
         * תת־נושא פנימי   -> שם הרמה הפנימית בלבד
         */
        if let openedNestedSubTopic {
            let cleanNested =
                openedNestedSubTopic
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            if !cleanNested.isEmpty {
                return KmiEnglishTitleResolver.title(
                    for: cleanNested,
                    isEnglish: isEnglish
                )
            }
        }

        if let subTopicUi {
            let cleanSubTopic =
                subTopicUi
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

            if !cleanSubTopic.isEmpty {
                return KmiEnglishTitleResolver.title(
                    for: cleanSubTopic,
                    isEnglish: isEnglish
                )
            }
        }

        return KmiEnglishTitleResolver.title(
            for: topicUi,
            isEnglish: isEnglish
        )
    }

    private var masteredCount: Int {
        rows.filter {
            currentMark(
                for:
                    $0.statusId
            ) == .mastered
        }
        .count
    }

    private var partiallyKnownCount: Int {
        rows.filter {
            currentMark(
                for:
                    $0.statusId
            ) == .partiallyKnown
        }
        .count
    }

    private var unknownCount: Int {
        rows.filter {
            currentMark(
                for:
                    $0.statusId
            ) == .unknown
        }
        .count
    }

    private var unmarkedCount: Int {
        rows.filter {
            currentMark(
                for:
                    $0.statusId
            ) == nil
        }
        .count
    }

    /*
     * תרגיל שלא נשמר עבורו סטטוס מאמן
     * נחשב כברירת מחדל "לא נלמד".
     */
    private var coachNotTaughtCount:
        Int {

        rows.filter {
            row in

            currentCoachProgress(
                for:
                    row.statusId
            )
            .selectedStatuses
            .isEmpty
        }
        .count
    }

    private var coachTaughtCount:
        Int {

        rows.filter {
            row in

            currentCoachProgress(
                for:
                    row.statusId
            )
            .isSelected(
                .taught
            )
        }
        .count
    }

    private var coachPracticedCount:
        Int {

        rows.filter {
            row in

            currentCoachProgress(
                for:
                    row.statusId
            )
            .isSelected(
                .practiced
            )
        }
        .count
    }

    private var coachNeedsReinforcementCount:
        Int {

        rows.filter {
            row in

            currentCoachProgress(
                for:
                    row.statusId
            )
            .isSelected(
                .needsReinforcement
            )
        }
        .count
    }

    var body: some View {
        ZStack {
            KmiAppBackground()

            VStack(spacing: 0) {
                /*
                 * מציגים את האייקון רק כאשר קיימת
                 * הערה אמיתית במאגר המשותף.
                 */
                if currentGeneralNote != nil {

                    HStack {

                        if !isEnglish {
                            Spacer(
                                minLength:
                                    0
                            )
                        }

                        Button {

                            showGeneralNote =
                                true

                        } label: {

                            HStack(
                                spacing:
                                    7
                            ) {

                                Image(
                                    systemName:
                                        "info.circle.fill"
                                )
                                .kmiIconSize(
                                    18
                                )

                                Text(
                                    tr(
                                        "דגשים כלליים",
                                        "General notes"
                                    )
                                )
                                .kmiTypography(
                                    .action
                                )
                            }
                            .foregroundStyle(
                                KmiAppTheme
                                    .secondary(
                                        for:
                                            colorScheme
                                    )
                            )
                            .padding(
                                .horizontal,
                                13
                            )
                            .frame(
                                height:
                                    36
                            )
                            .background {

                                Capsule()
                                    .fill(
                                        KmiAppTheme
                                            .secondaryContainer(
                                                for:
                                                    colorScheme
                                            )
                                            .opacity(
                                                0.55
                                            )
                                    )
                            }
                            .overlay {

                                Capsule()
                                    .stroke(
                                        KmiAppTheme
                                            .secondary(
                                                for:
                                                    colorScheme
                                            )
                                            .opacity(
                                                0.35
                                            ),
                                        lineWidth:
                                            1
                                    )
                            }
                        }
                        .buttonStyle(
                            .plain
                        )
                        .accessibilityLabel(
                            tr(
                                "הצג דגשים כלליים",
                                "Show general notes"
                            )
                        )

                        if isEnglish {
                            Spacer(
                                minLength:
                                    0
                            )
                        }
                    }
                    .padding(
                        .horizontal,
                        16
                    )
                    .padding(
                        .top,
                        7
                    )
                    .padding(
                        .bottom,
                        3
                    )
                    .environment(
                        \.layoutDirection,
                        screenLayoutDirection
                    )
                    .background(
                        KmiAppBackground()
                    )
                }

                MaterialsBeltHeader(
                    belt:
                        belt,
                    count:
                        rows.count,
                    isEnglish:
                        isEnglish
                )

                MaterialsStatsHeader(
                    masteredCount:
                        masteredCount,
                    partiallyKnownCount:
                        partiallyKnownCount,
                    unknownCount:
                        unknownCount,
                    unmarkedCount:
                        unmarkedCount,
                    coachNotTaughtCount:
                        coachNotTaughtCount,
                    coachTaughtCount:
                        coachTaughtCount,
                    coachPracticedCount:
                        coachPracticedCount,
                    coachNeedsReinforcementCount:
                        coachNeedsReinforcementCount,
                    isCoach:
                        effectiveIsCoach,
                    isEnglish:
                        isEnglish
                )

                Rectangle()
                    .fill(
                        BeltPaletteByMaterials
                            .color(
                                for:
                                    belt
                            )
                            .opacity(
                                0.75
                            )
                    )
                    .frame(
                        height:
                            2
                    )

                ScrollView {
                    VStack(spacing: 0) {
                        if rows.isEmpty {
                            MaterialsEmptyStateView(
                                belt: belt,
                                title: headerTitle,
                                isEnglish: isEnglish
                            )
                            .padding(.horizontal, 14)
                            .padding(.top, 18)
                            .padding(.bottom, 18)
                        } else {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                MaterialsExerciseRow(
                                    title: row.displayName,
                                    beltColor:
                                        BeltPaletteByMaterials.color(
                                            for: belt
                                        ),
                                    isFavorite:
                                        favorites.contains(
                                            row.canonicalId
                                        ),
                                    isExcluded:
                                        excluded.contains(
                                            row.canonicalId
                                        ),
                                    mark:
                                        currentMark(
                                            for: row.statusId
                                        ),
                                    traineeUpdatedAt:
                                        currentTraineeUpdatedAt(
                                            for:
                                                row.statusId
                                        ),
                                    coachProgress:
                                        currentCoachProgress(
                                            for: row.statusId
                                        ),
                                    hasNote:
                                        !(
                                            notes[row.canonicalId]?
                                                .trimmingCharacters(
                                                    in: .whitespacesAndNewlines
                                                )
                                                .isEmpty
                                            ?? true
                                        ),
                                    isCoach: effectiveIsCoach,
                                    isEnglish: isEnglish,
                                    onToggleFavorite: {
                                        toggleFavorite(row)
                                    },
                                    onToggleExcluded: {
                                        toggleExcluded(
                                            row.canonicalId
                                        )
                                    },
                                    onShowInfo: {
                                        selectedInfoRow = row
                                    },
                                    onEditNote: {
                                        noteDraft =
                                            notes[row.canonicalId]
                                            ?? ""

                                        selectedNoteRow = row
                                    },
                                    onSelectTraineeStatus: {
                                        selectedStatus in

                                        saveTraineeMark(
                                            selectedStatus,
                                            for:
                                                row
                                        )
                                    },
                                    onSelectCoachStatus: {
                                        selectedStatus in

                                        saveCoachProgress(
                                            selectedStatus,
                                            for: row.statusId
                                        )
                                    }
                                )

                                if idx != rows.count - 1 {
                                    Rectangle()
                                        .fill(
                                            KmiAppTheme
                                                .outlineVariant(
                                                    for:
                                                        colorScheme
                                                )
                                        )
                                        .frame(
                                            height:
                                                1
                                        )
                                        .padding(
                                            .horizontal,
                                            14
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .id(refreshToken)
                }
                .background(
                    KmiAppBackground()
                )

                MaterialsBottomBar(
                    belt: belt,
                    isEnglish: isEnglish,
                    isPracticeLocked: isPracticeLocked,
                    onPractice: {
                        if isPracticeLocked {
                            onOpenSubscription()
                        } else {
                            /*
                             * כמו באנדרואיד, מסך התרגול מקבל
                             * את הנושא המקורי שהמשתמש פתח.
                             */
                            onPractice(
                                belt,
                                topicUi
                            )
                        }
                    },
                    onSummary: {
                        /*
                         * התאמה לחתימה באנדרואיד:
                         * onSummary(belt, topicUi, subTopicFilter)
                         */
                        onSummary(
                            belt,
                            topicUi,
                            subTopicUi
                        )
                    },
                    onReset: {
                        showResetConfirmation = true
                    }
                )
            }

            if let toastMessage {
                MaterialsToastView(message: toastMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 136)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            speechDelegate.onFinish = {
                isSpeakingExplanation = false
            }

            speechSynth.delegate = speechDelegate
            loadState()
        }
        .onDisappear {
            speechSynth.stopSpeaking(at: .immediate)
            speechSynth.delegate = nil
            speechDelegate.onFinish = nil
            isSpeakingExplanation = false
        }
        .onChange(of: scopeKey) { _, _ in
            loadState()
        }
        /*
         * אין להאזין כאן לכל שינוי ב־UserDefaults.
         *
         * loadState מבצעת בעצמה כתיבות לצורך מיגרציה
         * וסנכרון עם התרגול האקראי. האזנה כללית לכל
         * כתיבה יוצרת לולאת loadState אינסופית.
         *
         * user_role ו־role מנוהלים באמצעות AppStorage
         * ולכן מעבר בין מאמן למתאמן נשאר ריאקטיבי.
         */
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard let shareRequest = notification.object as? NSMutableDictionary else {
                return
            }

            shareRequest["handled"] = true
            createAndShareMaterialsPdf()
        }
        .sheet(isPresented: $showGeneralNote) {
            if let currentGeneralNote {
                MaterialsGeneralNoteSheet(
                    title: headerTitle,
                    note: currentGeneralNote,
                    isEnglish: isEnglish,
                    accentColor: BeltPaletteByMaterials.color(
                        for: belt
                    ),
                    onClose: {
                        showGeneralNote = false
                    }
                )
                .presentationDetents([
                    PresentationDetent.fraction(0.62),
                    PresentationDetent.large
                ])
                .presentationDragIndicator(
                    Visibility.visible
                )
            }
        }
        .confirmationDialog(
            effectiveIsCoach
                ? tr(
                    "לאפס את כל סטטוסי המאמן בנושא הזה?",
                    "Reset all coach statuses for this topic?"
                )
                : tr(
                    "לאפס את כל הסימונים בנושא הזה?",
                    "Reset all marks for this topic?"
                ),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                effectiveIsCoach
                    ? tr(
                        "אפס סטטוסים, מועדפים, החרגות והערות",
                        "Reset statuses, favorites, exclusions and notes"
                    )
                    : tr(
                        "אפס סימונים, מועדפים, החרגות והערות",
                        "Reset marks, favorites, exclusions and notes"
                    ),
                role: .destructive
            ) {
                resetCurrentScope()
            }

            Button(
                tr("ביטול", "Cancel"),
                role: .cancel
            ) { }
        } message: {
            Text(
                tr(
                    "הפעולה תמחק את הנתונים המקומיים ששמרת עבור הנושא הנוכחי בלבד.",
                    "This will delete the local data saved for the current topic only."
                )
            )
        }
        .sheet(item: $selectedInfoRow) { row in
            MaterialsInfoSheet(
                title: row.displayName,
                text: explanationText(for: row),
                isFavorite: favorites.contains(row.canonicalId),
                isSpeaking: isSpeakingExplanation,
                isEnglish: isEnglish,
                accentColor: BeltPaletteByMaterials.color(for: belt),
                onClose: {
                    speechSynth.stopSpeaking(at: .immediate)
                    isSpeakingExplanation = false
                    selectedInfoRow = nil
                },
                onToggleFavorite: {
                    toggleFavorite(row)
                },
                onSpeak: {
                    toggleSpeak(explanationText(for: row))
                },
                onEditNote: {
                    speechSynth.stopSpeaking(at: .immediate)
                    isSpeakingExplanation = false

                    noteDraft = notes[row.canonicalId] ?? ""
                    selectedInfoRow = nil

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        selectedNoteRow = row
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedNoteRow) { row in
            MaterialsPremiumNoteSheet(
                title: row.displayName,
                noteText: $noteDraft,
                isEnglish: isEnglish,
                onCancel: {
                    selectedNoteRow = nil
                },
                onSave: {
                    saveNote(noteDraft, for: row.canonicalId)
                    selectedNoteRow = nil
                },
                onDelete: {
                    noteDraft = ""
                    saveNote("", for: row.canonicalId)
                    selectedNoteRow = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPdfShareSheet) {
            if let generatedPdfURL {
                MaterialsPdfShareSheet(items: [generatedPdfURL])
            }
        }
    }
    
    private struct MaterialsEmptyStateView:
        View {

        @Environment(\.colorScheme)
        private var colorScheme

        let belt: Belt
        let title: String
        let isEnglish: Bool

        private var textAlignment:
            TextAlignment {

            isEnglish
                ? .leading
                : .trailing
        }

        private var frameAlignment:
            Alignment {

            isEnglish
                ? .leading
                : .trailing
        }

        private var accentColor:
            Color {

            BeltPaletteByMaterials
                .color(
                    for:
                        belt
                )
        }

        var body: some View {

            VStack(
                spacing:
                    14
            ) {

                ZStack {

                    Circle()
                        .fill(
                            accentColor
                                .opacity(
                                    colorScheme == .dark
                                        ? 0.18
                                        : 0.12
                                )
                        )
                        .frame(
                            width:
                                72,
                            height:
                                72
                        )

                    Circle()
                        .stroke(
                            accentColor
                                .opacity(
                                    0.24
                                ),
                            lineWidth:
                                1
                        )
                        .frame(
                            width:
                                72,
                            height:
                                72
                        )

                    Image(
                        systemName:
                            "doc.text.magnifyingglass"
                    )
                    .kmiIconSize(
                        28
                    )
                    .foregroundStyle(
                        accentColor
                    )
                }

                VStack(
                    alignment:
                        isEnglish
                            ? .leading
                            : .trailing,
                    spacing:
                        6
                ) {

                    Text(
                        isEnglish
                            ? "No material found"
                            : "לא נמצא חומר להצגה"
                    )
                    .kmiTypography(
                        .sectionTitle
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurface(
                                for:
                                    colorScheme
                            )
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )

                    Text(
                        title
                    )
                    .kmiTypography(
                        .cardTitle
                    )
                    .foregroundStyle(
                        accentColor
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )

                    Text(
                        isEnglish
                            ? "This topic is connected to the content repository, but no exercises were returned for this belt and topic."
                            : "הנושא מחובר למאגר התוכן, אך לא נמצאו תרגילים עבור החגורה והנושא הנוכחיים."
                    )
                    .kmiTypography(
                        .secondary
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                    )
                    .lineSpacing(
                        3
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )
                }
            }
            .padding(
                .horizontal,
                18
            )
            .padding(
                .vertical,
                24
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .fill(
                    KmiAppTheme
                        .surface(
                            for:
                                colorScheme
                        )
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .stroke(
                    accentColor
                        .opacity(
                            0.20
                        ),
                    lineWidth:
                        1
                )
            }
            .environment(
                \.layoutDirection,
                isEnglish
                    ? .leftToRight
                    : .rightToLeft
            )
        }
    }
    
    // MARK: - Helpers

    private func displayName(for rawItem: String) -> String {
        var text = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            materialRootTopic,
            materialParentSubTopic,
            effectiveSubTopicUi,
            topicUi,
            subTopicUi
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .removingDuplicatesKeepingOrder()

        for prefix in prefixes {
            if text.hasPrefix("\(prefix)::") {
                text = String(text.dropFirst("\(prefix)::".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–—: "))
            }
        }

        let clean = text
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return KmiEnglishTitleResolver.title(for: clean, isEnglish: isEnglish)
    }

    private func explanationText(for row: ExerciseRow) -> String {
        let txt = KmiExerciseExplanationResolverIOS.shared.get(
            belt: belt,
            topic: materialRootTopic,
            item: row.rawItem,
            isEnglish: isEnglish
        )

        let clean = txt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if clean.isEmpty {
            return tr(
                "לא נמצא הסבר לתרגיל זה.",
                "No explanation was found for this exercise."
            )
        }

        return clean
    }
    
    private let practiceFavoritesKey =
        "practice_favorites"

    private func normalizedFavoriteValue(
        _ value: String
    ) -> String {
        value
            .replacingOccurrences(
                of: "\u{200F}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{200E}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
            .replacingOccurrences(
                of: "–",
                with: "-"
            )
            .replacingOccurrences(
                of: "—",
                with: "-"
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    private func practiceFavoriteAliases(
        for row: ExerciseRow
    ) -> Set<String> {
        [
            row.rawItem,
            row.displayName,
            row.canonicalId
        ]
        .map(
            normalizedFavoriteValue
        )
        .filter {
            !$0.isEmpty
        }
        .reduce(
            into: Set<String>()
        ) { result, value in
            result.insert(value)
        }
    }

    private func updatePracticeFavorites(
        for row: ExerciseRow,
        isFavorite: Bool
    ) {
        let defaults =
            UserDefaults.standard

        var storedValues =
            defaults.stringArray(
                forKey:
                    practiceFavoritesKey
            ) ?? []

        let aliases =
            practiceFavoriteAliases(
                for: row
            )

        storedValues.removeAll {
            storedValue in

            aliases.contains(
                normalizedFavoriteValue(
                    storedValue
                )
            )
        }

        if isFavorite {
            let cleanItem =
                row.rawItem
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            if !cleanItem.isEmpty {
                storedValues.append(
                    cleanItem
                )
            }
        }

        var seen =
            Set<String>()

        let uniqueValues =
            storedValues.filter {
                value in

                let key =
                    normalizedFavoriteValue(
                        value
                    )

                guard !key.isEmpty else {
                    return false
                }

                return seen
                    .insert(key)
                    .inserted
            }

        defaults.set(
            uniqueValues,
            forKey:
                practiceFavoritesKey
        )
    }
    
    private func favoriteKey(for id: String) -> String {
        "favorite.\(id)"
    }

    private func excludedKey(for id: String) -> String {
        "excluded.\(id)"
    }

    private func markKey(for id: String) -> String {
        "mark.\(id)"
    }

    private func noteKey(for id: String) -> String {
        "note.\(id)"
    }

    private func traineeUpdatedAtKey(
        for statusId: String
    ) -> String {

        [
            "trainee_material_updated_at",
            belt.id,
            topicKey,
            statusId
        ]
        .joined(
            separator:
                "_"
        )
    }

    private func loadTraineeUpdatedAt(
        for statusId: String
    ) -> Int64 {

        Int64(
            UserDefaults.standard.double(
                forKey:
                    traineeUpdatedAtKey(
                        for:
                            statusId
                    )
            )
        )
    }

    private func currentTraineeUpdatedAt(
        for statusId: String
    ) -> Int64 {

        traineeUpdatedAtStates[
            statusId
        ] ?? 0
    }

    // MARK: - Random Practice Status Bridge

    /// משתמש בדיוק באותה נורמליזציה שבה משתמש
    /// RandomPracticeView עבור מזהה תרגיל.
    private func normalizedPracticeId(
        _ item: String
    ) -> String {
        item
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "\u{200F}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{200E}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
            .replacingOccurrences(
                of: " ",
                with: "_"
            )
            .lowercased()
    }

    /// משתמש בדיוק באותה נורמליזציה שבה משתמש
    /// RandomPracticeView עבור שם הנושא.
    private var practiceTopicStorageId: String {
        materialRootTopic
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: " ",
                with: "_"
            )
    }

    private var practiceStatusStoragePrefix: String {
        "random_practice_status_\(belt.id)_\(practiceTopicStorageId)"
    }

    private var practiceWrongStorageKey: String {
        "random_practice_wrong_\(belt.id)_\(practiceTopicStorageId)"
    }

    private func practiceStatusKey(
        for rawItem: String
    ) -> String {
        "\(practiceStatusStoragePrefix)_\(normalizedPracticeId(rawItem))"
    }

    /*
     * מפתח נפרד לסטטוס המאמן.
     *
     * המבנה זהה למבנה שנקבע באנדרואיד:
     * coach_material_progress_<belt>_<topic>_<statusId>
     */
    private func coachProgressKey(
        for statusId: String
    ) -> String {
        [
            "coach_material_progress",
            belt.id,
            topicKey,
            statusId
        ]
        .joined(separator: "_")
    }

    private func loadCoachProgress(
        for statusId: String
    ) -> CoachMaterialProgress {

        let defaults =
            UserDefaults.standard

        let key =
            coachProgressKey(
                for:
                    statusId
            )

        let selectableStatuses:
            [CoachMaterialStatus] = [

                .taught,
                .practiced,
                .needsReinforcement
            ]

        var selectedStatuses =
            Set<CoachMaterialStatus>()

        var updatedAtByStatus:
            [CoachMaterialStatus: Int64] = [:]

        for status in
            selectableStatuses {

            let selectedKey =
                "\(key)_\(status.rawValue)_selected"

            let updatedAtKey =
                "\(key)_\(status.rawValue)_updated_at"

            if defaults.bool(
                forKey:
                    selectedKey
            ) {

                selectedStatuses.insert(
                    status
                )
            }

            let updatedAt =
                Int64(
                    defaults.double(
                        forKey:
                            updatedAtKey
                    )
                )

            if updatedAt > 0 {

                updatedAtByStatus[
                    status
                ] = updatedAt
            }
        }

        /*
         * המבנה החדש כבר קיים.
         */
        if !selectedStatuses.isEmpty {

            return CoachMaterialProgress(
                selectedStatuses:
                    selectedStatuses,
                updatedAtByStatus:
                    updatedAtByStatus
            )
        }

        /*
         * תאימות לנתונים מהמבנה הישן:
         *
         * <key>_status
         * <key>_updated_at
         */
        let legacyRawStatus =
            defaults.string(
                forKey:
                    "\(key)_status"
            )

        let legacyStatus =
            legacyRawStatus
                .flatMap {
                    CoachMaterialStatus(
                        rawValue:
                            $0
                    )
                }
                ?? .notTaught

        let legacyUpdatedAt =
            Int64(
                defaults.double(
                    forKey:
                        "\(key)_updated_at"
                )
            )

        if legacyStatus !=
            .notTaught {

            return CoachMaterialProgress(
                selectedStatuses: [
                    legacyStatus
                ],
                updatedAtByStatus:
                    legacyUpdatedAt > 0
                    ? [
                        legacyStatus:
                            legacyUpdatedAt
                    ]
                    : [:]
            )
        }

        return CoachMaterialProgress()
    }

    private func currentCoachProgress(
        for statusId: String
    ) -> CoachMaterialProgress {

        coachProgressStates[
            statusId
        ]
        ?? CoachMaterialProgress()
    }

    private func saveCoachProgress(
        _ status: CoachMaterialStatus,
        for statusId: String
    ) {

        let defaults =
            UserDefaults.standard

        let key =
            coachProgressKey(
                for:
                    statusId
            )

        let current =
            coachProgressStates[
                statusId
            ]
            ?? loadCoachProgress(
                for:
                    statusId
            )

        /*
         * NOT_TAUGHT =
         * אין שום סטטוס מסומן.
         */
        if status == .notTaught {

            coachProgressStates[
                statusId
            ] = CoachMaterialProgress()

            for selectableStatus in [
                CoachMaterialStatus.taught,
                .practiced,
                .needsReinforcement
            ] {

                defaults.removeObject(
                    forKey:
                        "\(key)_\(selectableStatus.rawValue)_selected"
                )

                defaults.removeObject(
                    forKey:
                        "\(key)_\(selectableStatus.rawValue)_updated_at"
                )
            }

            defaults.removeObject(
                forKey:
                    "\(key)_status"
            )

            defaults.removeObject(
                forKey:
                    "\(key)_updated_at"
            )

            refreshToken =
                UUID()

            return
        }

        var nextSelected =
            current.selectedStatuses

        var nextDates =
            current.updatedAtByStatus

        if nextSelected
            .contains(
                status
            ) {

            /*
             * לחיצה חוזרת =
             * ביטול הסטטוס הזה בלבד.
             */
            nextSelected.remove(
                status
            )

            nextDates.removeValue(
                forKey:
                    status
            )

        } else {

            /*
             * Android:
             * מותר לבחור עד שני סטטוסים.
             */
            guard
                nextSelected.count < 2
            else {

                toastMessage =
                    tr(
                        "ניתן לבחור עד 2 סטטוסים.",
                        "You can select up to 2 statuses."
                    )

                return
            }

            nextSelected.insert(
                status
            )

            nextDates[
                status
            ] =
                Int64(
                    Date()
                        .timeIntervalSince1970
                    * 1000
                )
        }

        let nextProgress =
            CoachMaterialProgress(
                selectedStatuses:
                    nextSelected,
                updatedAtByStatus:
                    nextDates
            )

        coachProgressStates[
            statusId
        ] = nextProgress

        for selectableStatus in [
            CoachMaterialStatus.taught,
            .practiced,
            .needsReinforcement
        ] {

            let selected =
                nextSelected.contains(
                    selectableStatus
                )

            let selectedKey =
                "\(key)_\(selectableStatus.rawValue)_selected"

            let updatedAtKey =
                "\(key)_\(selectableStatus.rawValue)_updated_at"

            if selected {

                defaults.set(
                    true,
                    forKey:
                        selectedKey
                )

                defaults.set(
                    Double(
                        nextDates[
                            selectableStatus
                        ] ?? 0
                    ),
                    forKey:
                        updatedAtKey
                )

            } else {

                defaults.removeObject(
                    forKey:
                        selectedKey
                )

                defaults.removeObject(
                    forKey:
                        updatedAtKey
                )
            }
        }

        /*
         * לאחר שמירה בפורמט החדש
         * מסירים את הפורמט הישן.
         */
        defaults.removeObject(
            forKey:
                "\(key)_status"
        )

        defaults.removeObject(
            forKey:
                "\(key)_updated_at"
        )

        refreshToken =
            UUID()
    }

    private func practiceMark(
        for row: ExerciseRow
    ) -> RowMark? {
        let raw = UserDefaults.standard
            .string(
                forKey: practiceStatusKey(
                    for: row.rawItem
                )
            )?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        switch raw {

        case "known":
            return .mastered

        case "partial",
             "partially_known",
             "partiallyknown":
            return .partiallyKnown

        case "unknown":
            return .unknown

        default:
            return nil
        }
    }

    /// מעדכן גם את סטטוס התרגיל הבודד וגם את
    /// רשימת התרגילים שמקבלים משקל גבוה בתרגול.
    private func savePracticeMark(
        _ mark: RowMark?,
        for row: ExerciseRow
    ) {
        let defaults = UserDefaults.standard
        let statusKey = practiceStatusKey(
            for: row.rawItem
        )

        var wrongItems = Set(
            defaults.stringArray(
                forKey: practiceWrongStorageKey
            ) ?? []
        )

        switch mark {

        case .mastered:
            defaults.set(
                "known",
                forKey:
                    statusKey
            )

            wrongItems.remove(
                row.rawItem
            )

        case .partiallyKnown:
            defaults.set(
                "partial",
                forKey:
                    statusKey
            )

            /*
             * חלקית עדיין צריך להישאר
             * ברשימת התרגילים לחזרה.
             */
            wrongItems.insert(
                row.rawItem
            )

        case .unknown:
            defaults.set(
                "unknown",
                forKey:
                    statusKey
            )

            wrongItems.insert(
                row.rawItem
            )

        case nil:
            defaults.removeObject(
                forKey:
                    statusKey
            )

            wrongItems.remove(
                row.rawItem
            )
        }

        defaults.set(
            Array(wrongItems).sorted(),
            forKey: practiceWrongStorageKey
        )
    }

    private func loadState() {
        var loadedFavorites =
            Set<String>()

        var loadedExcluded =
            Set<String>()

        var loadedMarks:
            [String: RowMark?] = [:]

        var loadedTraineeUpdatedAt:
            [String: Int64] = [:]

        var loadedCoachProgress:
            [String: CoachMaterialProgress] = [:]

        var loadedNotes:
            [String: String] = [:]

        let storedPracticeFavorites =
            Set(
                (
                    UserDefaults.standard
                        .stringArray(
                            forKey:
                                practiceFavoritesKey
                        ) ?? []
                )
                .map(
                    normalizedFavoriteValue
                )
                .filter {
                    !$0.isEmpty
                }
            )

        for row in rows {
            let isCanonicalFavorite =
                UserDefaults.standard
                    .bool(
                        forKey:
                            favoriteKey(
                                for:
                                    row.canonicalId
                            )
                    )

            let isPracticeFavorite =
                !practiceFavoriteAliases(
                    for: row
                )
                .isDisjoint(
                    with:
                        storedPracticeFavorites
                )

            if isCanonicalFavorite ||
                isPracticeFavorite {
                loadedFavorites.insert(
                    row.canonicalId
                )

                /*
                 * מבצעים migration שקט לפורמט
                 * הקנוני של MaterialsView.
                 */
                UserDefaults.standard.set(
                    true,
                    forKey:
                        favoriteKey(
                            for:
                                row.canonicalId
                        )
                )
            }

            if UserDefaults.standard.bool(forKey: excludedKey(for: row.canonicalId)) {
                loadedExcluded.insert(row.canonicalId)
            }

            if let raw = UserDefaults.standard.string(
                forKey: markKey(
                    for: row.statusId
                )
            ),
               let storedMark = RowMark(
                    rawValue: raw
               ) {
                /*
                 * חומרי החגורה הם המקור הראשון כאשר
                 * כבר קיים בהם סימון.
                 */
                loadedMarks[row.statusId] =
                    storedMark

                /*
                 * מעבירים את המצב גם לתרגול האקראי,
                 * כדי ליישר נתונים ישנים שנשמרו רק
                 * בפורמט של MaterialsView.
                 */
                savePracticeMark(
                    storedMark,
                    for: row
                )
            } else if let storedPracticeMark =
                        practiceMark(for: row) {
                /*
                 * אם התרגיל סומן מתוך התרגול האקראי,
                 * מציגים את אותו סימון בחומרי החגורה.
                 */
                loadedMarks[row.statusId] =
                    storedPracticeMark

                /*
                 * מבצעים מיגרציה לפורמט הקבוע של
                 * MaterialsView בלי למחוק את הפורמט
                 * שנדרש לתרגול האקראי.
                 */
                UserDefaults.standard.set(
                    storedPracticeMark.rawValue,
                    forKey: markKey(
                        for: row.statusId
                    )
                )
            } else {
                loadedMarks[row.statusId] = nil
            }

            let traineeUpdatedAt =
                loadTraineeUpdatedAt(
                    for:
                        row.statusId
                )

            if traineeUpdatedAt > 0 {

                loadedTraineeUpdatedAt[
                    row.statusId
                ] = traineeUpdatedAt
            }

            
            loadedCoachProgress[row.statusId] =
                loadCoachProgress(
                    for: row.statusId
                )

            loadedNotes[row.canonicalId] =
                UserDefaults.standard.string(
                    forKey: noteKey(
                        for: row.canonicalId
                    )
                ) ?? ""
        }

        favorites = loadedFavorites
        excluded = loadedExcluded
        marks = loadedMarks
        traineeUpdatedAtStates = loadedTraineeUpdatedAt
        coachProgressStates = loadedCoachProgress
        notes = loadedNotes
    }

    private func showToast(_ message: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeOut(duration: 0.18)) {
            toastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeIn(duration: 0.18)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func toggleFavorite(
        _ row: ExerciseRow
    ) {
        let id =
            row.canonicalId

        if favorites.contains(id) {
            favorites.remove(id)

            UserDefaults.standard.set(
                false,
                forKey:
                    favoriteKey(
                        for: id
                    )
            )

            updatePracticeFavorites(
                for: row,
                isFavorite: false
            )

            showToast(
                tr(
                    "הוסר מהמועדפים.",
                    "Removed from favorites."
                )
            )
        } else {
            favorites.insert(id)

            UserDefaults.standard.set(
                true,
                forKey:
                    favoriteKey(
                        for: id
                    )
            )

            updatePracticeFavorites(
                for: row,
                isFavorite: true
            )

            showToast(
                tr(
                    "נוסף למועדפים.",
                    "Added to favorites."
                )
            )
        }

        refreshToken = UUID()
    }

    private func toggleExcluded(_ id: String) {
        if excluded.contains(id) {
            excluded.remove(id)
            UserDefaults.standard.set(false, forKey: excludedKey(for: id))
            showToast(tr("בוטלה ההחרגה – התרגיל יחזור לתרגול.", "Exclusion canceled. The exercise will return to practice."))
        } else {
            excluded.insert(id)
            UserDefaults.standard.set(true, forKey: excludedKey(for: id))
            showToast(tr("התרגיל הוחרג – לא יופיע בתרגול הנושא.", "Exercise excluded. It will not appear in this topic practice."))
        }
    }

    private func currentMark(for id: String) -> RowMark? {
        if let value = marks[id] {
            return value
        }
        return nil
    }

    private func saveTraineeMark(
        _ selectedMark: RowMark?,
        for row: ExerciseRow
    ) {

        let materialsKey =
            markKey(
                for:
                    row.statusId
            )

        marks[
            row.statusId
        ] = selectedMark

        let updatedAtKey =
            traineeUpdatedAtKey(
                for:
                    row.statusId
            )

        if let selectedMark {

            let updatedAt =
                Int64(
                    Date()
                        .timeIntervalSince1970
                    * 1000
                )

            traineeUpdatedAtStates[
                row.statusId
            ] = updatedAt

            UserDefaults.standard.set(
                Double(
                    updatedAt
                ),
                forKey:
                    updatedAtKey
            )

            UserDefaults.standard.set(
                selectedMark.rawValue,
                forKey:
                    materialsKey
            )

            savePracticeMark(
                selectedMark,
                for:
                    row
            )

            switch selectedMark {

            case .mastered:
                showToast(
                    tr(
                        "סומן כיודע.",
                        "Marked as known."
                    )
                )

            case .partiallyKnown:
                showToast(
                    tr(
                        "סומן כיודע חלקית.",
                        "Marked as partially known."
                    )
                )

            case .unknown:
                showToast(
                    tr(
                        "סומן כלא יודע.",
                        "Marked as unknown."
                    )
                )
            }

        } else {

            traineeUpdatedAtStates.removeValue(
                forKey:
                    row.statusId
            )

            UserDefaults.standard.removeObject(
                forKey:
                    updatedAtKey
            )

            UserDefaults.standard.removeObject(
                forKey:
                    materialsKey
            )

            savePracticeMark(
                nil,
                for:
                    row
            )

            showToast(
                tr(
                    "הסימון הוסר.",
                    "Mark removed."
                )
            )
        }

        refreshToken =
            UUID()
    }

    private func saveNote(_ text: String, for id: String) {
        notes[id] = text
        let key = noteKey(for: id)
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            showToast(tr("ההערה נמחקה.", "Note deleted."))
        } else {
            UserDefaults.standard.set(clean, forKey: key)
            showToast(tr("ההערה נשמרה.", "Note saved."))
        }

        refreshToken = UUID()
    }

    private func pdfStatusText(
        for row: ExerciseRow
    ) -> String {

        if effectiveIsCoach {

            let progress =
                currentCoachProgress(
                    for:
                        row.statusId
                )

            let selected =
                progress
                    .selectedStatuses

            if selected.isEmpty {

                return tr(
                    "לא נלמד",
                    "Not taught"
                )
            }

            var labels:
                [String] = []

            if selected.contains(
                .taught
            ) {

                labels.append(
                    tr(
                        "נלמד",
                        "Taught"
                    )
                )
            }

            if selected.contains(
                .practiced
            ) {

                labels.append(
                    tr(
                        "תורגל",
                        "Practiced"
                    )
                )
            }

            if selected.contains(
                .needsReinforcement
            ) {

                labels.append(
                    tr(
                        "נדרש חיזוק",
                        "Needs reinforcement"
                    )
                )
            }

            return labels.joined(
                separator:
                    " + "
            )
        }

        switch currentMark(
            for:
                row.statusId
        ) {

        case .mastered:

            return tr(
                "יודע",
                "Known"
            )

        case .partiallyKnown:

            return tr(
                "יודע חלקית",
                "Partially known"
            )

        case .unknown:

            return tr(
                "לא יודע",
                "Unknown"
            )

        case nil:

            return tr(
                "לא סומן",
                "Not marked"
            )
        }
    }

    private func createAndShareMaterialsPdf() {
        let pdfItems = rows.enumerated().map { index, row in
            MaterialsPdfItemIOS(
                number: index + 1,
                title: row.displayName,
                status: pdfStatusText(for: row),
                isFavorite: favorites.contains(row.canonicalId),
                isExcluded: excluded.contains(row.canonicalId),
                hasNote: !(notes[row.canonicalId]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty ?? true)
            )
        }

        do {
            generatedPdfURL = try MaterialsPdfGeneratorIOS.create(
                belt: belt,
                topicTitle: headerTitle,
                items: pdfItems,
                isEnglish: isEnglish
            )

            showPdfShareSheet = true
        } catch {
            generatedPdfURL = nil

            showToast(
                tr(
                    "לא ניתן היה ליצור את קובץ ה־PDF.",
                    "The PDF file could not be created."
                )
            )
        }
    }

    private func resetCurrentScope() {
        speechSynth.stopSpeaking(at: .immediate)
        isSpeakingExplanation = false

        let keysToRemove =
            rows.flatMap {
                row -> [String] in

                let progressKey =
                    coachProgressKey(
                        for:
                            row.statusId
                    )

                let coachStatusKeys =
                    [
                        CoachMaterialStatus.taught,
                        .practiced,
                        .needsReinforcement
                    ]
                    .flatMap {
                        status in

                        [
                            "\(progressKey)_\(status.rawValue)_selected",
                            "\(progressKey)_\(status.rawValue)_updated_at"
                        ]
                    }

                return [
                    favoriteKey(
                        for:
                            row.canonicalId
                    ),
                    excludedKey(
                        for:
                            row.canonicalId
                    ),
                    markKey(
                        for:
                            row.statusId
                    ),
                    traineeUpdatedAtKey(
                        for:
                            row.statusId
                    ),
                    practiceStatusKey(
                        for:
                            row.rawItem
                    ),
                    noteKey(
                        for:
                            row.canonicalId
                    ),

                    /*
                     * legacy coach storage
                     */
                    "\(progressKey)_status",
                    "\(progressKey)_updated_at"
                ]
                + coachStatusKeys
            }

        /*
         * קודם מעדכנים את ממשק המשתמש.
         * כך כל הסימונים והסטטוסים נעלמים מיד.
         */
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            selectedInfoRow = nil
            selectedNoteRow = nil
            noteDraft = ""

            favorites.removeAll()
            excluded.removeAll()
            marks.removeAll()
            traineeUpdatedAtStates.removeAll()
            coachProgressStates.removeAll()
            notes.removeAll()

            refreshToken = UUID()
        }

        showToast(
            effectiveIsCoach
                ? tr(
                    "סטטוסי המאמן בנושא אופסו בהצלחה.",
                    "Coach statuses reset successfully."
                )
                : tr(
                    "הנושא אופס בהצלחה.",
                    "Topic reset successfully."
                )
        )

        /*
         * המחיקה מהאחסון מתבצעת לאחר
         * שממשק המשתמש כבר התאפס.
         */
        DispatchQueue.global(
            qos: .utility
        ).async {

            let defaults =
                UserDefaults.standard

            keysToRemove.forEach {
                key in

                defaults.removeObject(
                    forKey:
                        key
                )
            }

            /*
             * מסירים מרשימת החזרה של Random Practice
             * רק את התרגילים ששייכים לנושא הנוכחי.
             */
            let currentRawItems =
                Set(
                    rows.map(
                        \.rawItem
                    )
                )

            var wrongItems =
                Set(
                    defaults.stringArray(
                        forKey:
                            practiceWrongStorageKey
                    ) ?? []
                )

            wrongItems.subtract(
                currentRawItems
            )

            defaults.set(
                Array(
                    wrongItems
                )
                .sorted(),
                forKey:
                    practiceWrongStorageKey
            )
        }
    }

    private func toggleSpeak(_ text: String) {
        if isSpeakingExplanation {
            speechSynth.stopSpeaking(at: .immediate)
            isSpeakingExplanation = false
            showToast(tr("ההקראה נעצרה.", "Speech stopped."))
            return
        }

        speechSynth.stopSpeaking(at: .immediate)

        let clean = text
            .replacingOccurrences(of: "•", with: ".")
            .replacingOccurrences(of: "/", with: ".")
            .replacingOccurrences(of: "K.M.I", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "KMI", with: isEnglish ? "K M I" : "קיי אם איי")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            isSpeakingExplanation = false
            return
        }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: isEnglish ? "en-US" : "he-IL")
        utterance.rate = isEnglish ? 0.46 : 0.43

        isSpeakingExplanation = true
        speechSynth.speak(utterance)
    }
}

private struct MaterialsToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .kmiFont(size: 13.5, weight: .bold)
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.24).opacity(0.94))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Header

private struct MaterialsBeltHeader:
    View {

    let belt: Belt
    let count: Int
    let isEnglish: Bool

    private var beltTitle:
        String {

        if isEnglish {

            switch belt {

            case .yellow:
                return "Yellow Belt"

            case .orange:
                return "Orange Belt"

            case .green:
                return "Green Belt"

            case .blue:
                return "Blue Belt"

            case .brown:
                return "Brown Belt"

            case .black:
                return "Black Belt"

            case .white:
                return "White Belt"

            default:
                return belt.en
            }

        } else {

            switch belt {

            case .yellow:
                return "חגורה צהובה"

            case .orange:
                return "חגורה כתומה"

            case .green:
                return "חגורה ירוקה"

            case .blue:
                return "חגורה כחולה"

            case .brown:
                return "חגורה חומה"

            case .black:
                return "חגורה שחורה"

            case .white:
                return "חגורה לבנה"

            default:
                return belt.heb
            }
        }
    }

    private var beltTitleColor:
        Color {

        if belt == .white {

            return KmiAppTheme
                .sectionHeaderContentColor
        }

        return BeltPaletteByMaterials
            .color(
                for:
                    belt
            )
    }

    private var countText:
        String {

        if isEnglish {

            return count == 1
                ? "1 exercise"
                : "\(count) exercises"
        }

        /*
         * זהה כרגע למקור האמת באנדרואיד.
         */
        return "\(count) תרגילים"
    }

    var body: some View {

        VStack(
            spacing:
                1
        ) {

            Text(
                beltTitle
            )
            .kmiTypography(
                .sectionTitle
            )
            .fontWeight(
                .black
            )
            .foregroundStyle(
                beltTitleColor
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .center
            )
            .multilineTextAlignment(
                .center
            )
            .lineLimit(
                1
            )

            Text(
                countText
            )
            .kmiTypography(
                .caption
            )
            .fontWeight(
                .bold
            )
            .foregroundStyle(
                KmiAppTheme
                    .sectionHeaderContentColor
                    .opacity(
                        0.92
                    )
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    .center
            )
            .multilineTextAlignment(
                .center
            )
            .lineLimit(
                1
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            minHeight:
                50
        )
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            6
        )
        .background(
            KmiAppTheme
                .sectionHeaderBrush
        )
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
    }
}

private struct MaterialsStatsHeader:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let masteredCount: Int
    let partiallyKnownCount: Int
    let unknownCount: Int
    let unmarkedCount: Int

    let coachNotTaughtCount: Int
    let coachTaughtCount: Int
    let coachPracticedCount: Int
    let coachNeedsReinforcementCount: Int

    let isCoach: Bool
    let isEnglish: Bool

    var body: some View {

        HStack(
            spacing:
                7
        ) {

            if isCoach {

                statCard(
                    title:
                        isEnglish
                            ? "Unmarked"
                            : "לא סומן",
                    value:
                        coachNotTaughtCount,
                    accent:
                        KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Taught"
                            : "נלמד",
                    value:
                        coachTaughtCount,
                    accent:
                        KmiAppTheme
                            .success(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Practiced"
                            : "תורגל",
                    value:
                        coachPracticedCount,
                    accent:
                        KmiAppTheme
                            .primary(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Reinforce"
                            : "לחיזוק",
                    value:
                        coachNeedsReinforcementCount,
                    accent:
                        KmiAppTheme
                            .warning(
                                for:
                                    colorScheme
                            )
                )

            } else {

                statCard(
                    title:
                        isEnglish
                            ? "Unmarked"
                            : "לא סומן",
                    value:
                        unmarkedCount,
                    accent:
                        KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Known"
                            : "יודע",
                    value:
                        masteredCount,
                    accent:
                        KmiAppTheme
                            .success(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Partial"
                            : "חלקית",
                    value:
                        partiallyKnownCount,
                    accent:
                        KmiAppTheme
                            .warning(
                                for:
                                    colorScheme
                            )
                )

                statCard(
                    title:
                        isEnglish
                            ? "Unknown"
                            : "לא יודע",
                    value:
                        unknownCount,
                    accent:
                        KmiAppTheme
                            .error(
                                for:
                                    colorScheme
                            )
                )
            }
        }
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
        .padding(
            .leading,
            6
        )
        .padding(
            .trailing,
            6
        )
        .padding(
            .top,
            3
        )
        .padding(
            .bottom,
            6
        )
        .background(
            KmiAppTheme
                .surfaceVariant(
                    for:
                        colorScheme
                )
                .opacity(
                    0.55
                )
        )
    }

    private func statCard(
        title: String,
        value: Int,
        accent: Color
    ) -> some View {

        VStack(
            spacing:
                0
        ) {

            Rectangle()
                .fill(
                    accent
                )
                .frame(
                    height:
                        3
                )

            VStack(
                spacing:
                    1
            ) {

                Spacer(
                    minLength:
                        2
                )

                Text(
                    "\(value)"
                )
                .kmiTypography(
                    .action
                )
                .fontWeight(
                    .heavy
                )
                .foregroundStyle(
                    KmiAppTheme
                        .onSurface(
                            for:
                                colorScheme
                        )
                )
                .lineLimit(
                    1
                )

                Text(
                    title
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    .bold
                )
                .foregroundStyle(
                    colorScheme == .dark
                        ? KmiAppTheme
                            .onSurface(
                                for:
                                    colorScheme
                            )
                        : accent
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.70
                )

                Spacer(
                    minLength:
                        2
                )
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .background(
                accent.opacity(
                    colorScheme == .dark
                        ? 0.10
                        : 0.08
                )
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .frame(
            height:
                58
        )
        .background(
            KmiAppTheme
                .surface(
                    for:
                        colorScheme
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
        )
        .overlay {

            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
            .stroke(
                accent.opacity(
                    colorScheme == .dark
                        ? 0.55
                        : 0.24
                ),
                lineWidth:
                    1
            )
        }
    }
}


// MARK: - Row

private struct MaterialsExerciseRow: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    let title: String
    let beltColor: Color
    let isFavorite: Bool
    let isExcluded: Bool
    
    let mark: MaterialsView.RowMark?
    
    let traineeUpdatedAt:
    Int64
    
    let coachProgress:
    MaterialsView.CoachMaterialProgress
    
    let hasNote: Bool
    let isCoach: Bool
    let isEnglish: Bool
    
    let onToggleFavorite: () -> Void
    let onToggleExcluded: () -> Void
    let onShowInfo: () -> Void
    let onEditNote: () -> Void
    
    let onSelectTraineeStatus:
    (MaterialsView.RowMark?) -> Void
    
    let onSelectCoachStatus:
    (MaterialsView.CoachMaterialStatus) -> Void
    
    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private var rowOpacity:
    Double {
        
        isExcluded
        ? 0.56
        : 1.0
    }
    
    private var rowBorderColor:
    Color {
        
        if isExcluded {
            
            return KmiAppTheme
                .outline(
                    for:
                        colorScheme
                )
                .opacity(
                    0.34
                )
        }
        
        if !isCoach {
            
            if mark == .mastered {
                
                return KmiAppTheme
                    .success(
                        for:
                            colorScheme
                    )
                    .opacity(
                        0.34
                    )
            }
            
            if mark == .partiallyKnown {
                
                return KmiAppTheme
                    .warning(
                        for:
                            colorScheme
                    )
                    .opacity(
                        0.34
                    )
            }
            
            if mark == .unknown {
                
                return KmiAppTheme
                    .error(
                        for:
                            colorScheme
                    )
                    .opacity(
                        0.32
                    )
            }
        }
        
        if isFavorite || hasNote {
            
            return beltColor
                .opacity(
                    0.30
                )
        }
        
        return KmiAppTheme
            .outlineVariant(
                for:
                    colorScheme
            )
    }
    
    var body: some View {
        
        VStack(
            spacing:
                3
        ) {
            
            titleBlock
            
            if isCoach {
                
                GeometryReader {
                    geometry in
                    
                    let buttonWidth =
                    max(
                        0,
                        (
                            geometry.size.width
                            - 12
                        ) / 4
                    )
                    
                    HStack(
                        spacing:
                            4
                    ) {
                        
                        if isEnglish {
                            
                            MaterialsCoachStatusSelector(
                                progress:
                                    coachProgress,
                                buttonWidth:
                                    buttonWidth,
                                isEnglish:
                                    isEnglish,
                                onSelect:
                                    onSelectCoachStatus
                            )
                            
                            menuButton(
                                width:
                                    buttonWidth
                            )
                            
                        } else {
                            
                            menuButton(
                                width:
                                    buttonWidth
                            )
                            
                            MaterialsCoachStatusSelector(
                                progress:
                                    coachProgress,
                                buttonWidth:
                                    buttonWidth,
                                isEnglish:
                                    isEnglish,
                                onSelect:
                                    onSelectCoachStatus
                            )
                        }
                    }
                    .environment(
                        \.layoutDirection,
                         .leftToRight
                    )
                }
                .frame(
                    height:
                        40
                )
                
            } else {
                
                GeometryReader {
                    geometry in
                    
                    let buttonWidth =
                    max(
                        0,
                        (
                            geometry.size.width
                            - 12
                        ) / 4
                    )
                    
                    HStack(
                        spacing:
                            4
                    ) {
                        
                        if isEnglish {
                            
                            MaterialsTraineeStatusSelector(
                                mark:
                                    mark,
                                updatedAt:
                                    traineeUpdatedAt,
                                buttonWidth:
                                    buttonWidth,
                                isEnglish:
                                    isEnglish,
                                onSelect:
                                    onSelectTraineeStatus
                            )
                            
                            menuButton(
                                width:
                                    buttonWidth
                            )
                            
                        } else {
                            
                            menuButton(
                                width:
                                    buttonWidth
                            )
                            
                            MaterialsTraineeStatusSelector(
                                mark:
                                    mark,
                                updatedAt:
                                    traineeUpdatedAt,
                                buttonWidth:
                                    buttonWidth,
                                isEnglish:
                                    isEnglish,
                                onSelect:
                                    onSelectTraineeStatus
                            )
                        }
                    }
                    .environment(
                        \.layoutDirection,
                         .leftToRight
                    )
                }
                .frame(
                    height:
                        40
                )
            }
        }
        .padding(
            .horizontal,
            4
        )
        .padding(
            .vertical,
            5
        )
        .frame(
            maxWidth:
                    .infinity
        )
        .background {
            
            RoundedRectangle(
                cornerRadius:
                    15,
                style:
                        .continuous
            )
            .fill(
                KmiAppTheme
                    .surface(
                        for:
                            colorScheme
                    )
                    .opacity(
                        0.94
                    )
            )
        }
        .overlay {
            
            RoundedRectangle(
                cornerRadius:
                    15,
                style:
                        .continuous
            )
            .stroke(
                rowBorderColor,
                lineWidth:
                    1
            )
        }
        .opacity(
            rowOpacity
        )
        .contentShape(
            Rectangle()
        )
    }
    
    private var titleBlock: some View {
        
        HStack(
            spacing:
                6
        ) {
            
            if isEnglish {
                
                titleButton
                
                if isFavorite {
                    statusMiniLabel(
                        text:
                            "Favorite",
                        systemName:
                            "star.fill",
                        color:
                            Color.orange.opacity(
                                0.90
                            )
                    )
                }
                
                if hasNote {
                    statusMiniLabel(
                        text:
                            "Note",
                        systemName:
                            "note.text",
                        color:
                            Color.blue.opacity(
                                0.84
                            )
                    )
                }
                
                if isExcluded {
                    statusMiniLabel(
                        text:
                            "Excluded",
                        systemName:
                            "minus.circle.fill",
                        color:
                            Color.gray.opacity(
                                0.82
                            )
                    )
                }
                
            } else {
                
                if isExcluded {
                    statusMiniLabel(
                        text:
                            "מוחרג",
                        systemName:
                            "minus.circle.fill",
                        color:
                            Color.gray.opacity(
                                0.82
                            )
                    )
                }
                
                if hasNote {
                    statusMiniLabel(
                        text:
                            "הערה",
                        systemName:
                            "note.text",
                        color:
                            Color.blue.opacity(
                                0.84
                            )
                    )
                }
                
                if isFavorite {
                    statusMiniLabel(
                        text:
                            "מועדף",
                        systemName:
                            "star.fill",
                        color:
                            Color.orange.opacity(
                                0.90
                            )
                    )
                }
                
                titleButton
            }
        }
        .environment(
            \.layoutDirection,
             .leftToRight
        )
        .padding(
            .horizontal,
            6
        )
        .padding(
            .top,
            2
        )
        .frame(
            maxWidth:
                    .infinity
        )
    }
    
    private var titleButton:
    some View {
        
        Button {
            
            onShowInfo()
            
        } label: {
            
            Text(
                title
            )
            .kmiTypography(
                .body
            )
            .fontWeight(
                .semibold
            )
            .foregroundStyle(
                isExcluded
                ? KmiAppTheme
                    .onSurfaceVariant(
                        for:
                            colorScheme
                    )
                    .opacity(
                        0.55
                    )
                : KmiAppTheme
                    .onSurface(
                        for:
                            colorScheme
                    )
            )
            .multilineTextAlignment(
                textAlignment
            )
            .lineLimit(
                3
            )
            .minimumScaleFactor(
                0.82
            )
            .frame(
                maxWidth:
                        .infinity,
                alignment:
                    frameAlignment
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            isEnglish
            ? "Open explanation for \(title)"
            : "פתח הסבר עבור \(title)"
        )
    }
    
    private func statusMiniLabel(
        text: String,
        systemName: String,
        color: Color
    ) -> some View {
        
        HStack(
            spacing:
                3
        ) {
            
            Image(
                systemName:
                    systemName
            )
            .kmiIconSize(
                10
            )
            
            Text(
                text
            )
            .kmiTypography(
                .caption
            )
            .fontWeight(
                .heavy
            )
            .lineLimit(
                1
            )
        }
        .foregroundStyle(
            Color.white
        )
        .padding(
            .horizontal,
            7
        )
        .padding(
            .vertical,
            4
        )
        .background {
            
            Capsule()
                .fill(
                    color
                )
        }
    }
    
    private func menuButton(
        width: CGFloat
    ) -> some View {
        
        Menu {
            
            Button {
                
                onShowInfo()
                
            } label: {
                
                Label(
                    isEnglish
                    ? "Detailed explanation"
                    : "הסבר מפורט",
                    systemImage:
                        "info.circle.fill"
                )
            }
            
            Button {
                
                onToggleFavorite()
                
            } label: {
                
                Label(
                    isFavorite
                    ? (
                        isEnglish
                        ? "Remove from favorites"
                        : "הסר ממועדפים"
                    )
                    : (
                        isEnglish
                        ? "Add to favorites"
                        : "הוסף למועדפים"
                    ),
                    systemImage:
                        isFavorite
                    ? "star.slash.fill"
                    : "star.fill"
                )
            }
            
            Button {
                
                onEditNote()
                
            } label: {
                
                Label(
                    hasNote
                    ? (
                        isEnglish
                        ? "Edit note"
                        : "ערוך הערה"
                    )
                    : (
                        isEnglish
                        ? "Add note"
                        : "הוסף הערה"
                    ),
                    systemImage:
                        hasNote
                    ? "note.text"
                    : "square.and.pencil"
                )
            }
            
            Button {
                
                onToggleExcluded()
                
            } label: {
                
                Label(
                    isExcluded
                    ? (
                        isEnglish
                        ? "Include exercise"
                        : "החזר תרגיל"
                    )
                    : (
                        isEnglish
                        ? "Exclude exercise"
                        : "החרג תרגיל"
                    ),
                    systemImage:
                        isExcluded
                    ? "arrow.uturn.backward.circle.fill"
                    : "nosign"
                )
            }
            
        } label: {
            
            VStack(
                spacing:
                    1
            ) {
                
                Image(
                    systemName:
                        "info.circle.fill"
                )
                .kmiIconSize(
                    12
                )
                
                Text(
                    isEnglish
                    ? "Info"
                    : "מידע"
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    .heavy
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.75
                )
            }
            .foregroundStyle(
                KmiAppTheme
                    .onPrimary(
                        for:
                            colorScheme
                    )
            )
            .frame(
                width:
                    width,
                height:
                    40
            )
            .background {
                
                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                            .continuous
                )
                .fill(
                    KmiAppTheme
                        .primary(
                            for:
                                colorScheme
                        )
                )
            }
            .overlay {
                
                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                            .continuous
                )
                .stroke(
                    KmiAppTheme
                        .onPrimary(
                            for:
                                colorScheme
                        )
                        .opacity(
                            0.16
                        ),
                    lineWidth:
                        0.7
                )
            }
            .overlay(
                alignment:
                        .topTrailing
            ) {
                
                if
                    isFavorite ||
                        isExcluded ||
                        hasNote {
                    
                    Circle()
                        .fill(
                            statusDotColor
                        )
                        .frame(
                            width:
                                8,
                            height:
                                8
                        )
                        .overlay {
                            
                            Circle()
                                .stroke(
                                    KmiAppTheme
                                        .surface(
                                            for:
                                                colorScheme
                                        ),
                                    lineWidth:
                                        1
                                )
                        }
                        .offset(
                            x:
                                2,
                            y:
                                -2
                        )
                }
            }
        }
        .buttonStyle(
            .plain
        )
        .frame(
            width:
                width,
            height:
                40
        )
    }
    
    private var statusDotColor:
    Color {
        
        if isExcluded {
            
            return KmiAppTheme
                .error(
                    for:
                        colorScheme
                )
        }
        
        if hasNote {
            
            return KmiAppTheme
                .secondary(
                    for:
                        colorScheme
                )
        }
        
        if isFavorite {
            
            return KmiAppTheme
                .warning(
                    for:
                        colorScheme
                )
        }
        
        return Color.clear
    }
}

private struct MaterialsCoachStatusSelector:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let progress:
        MaterialsView.CoachMaterialProgress

    let buttonWidth:
        CGFloat

    let isEnglish: Bool

    let onSelect:
        (MaterialsView.CoachMaterialStatus) -> Void

    private let statuses:
        [MaterialsView.CoachMaterialStatus] = [
            .taught,
            .practiced,
            .needsReinforcement
        ]

    var body: some View {

        HStack(
            spacing:
                4
        ) {

            ForEach(
                statuses,
                id:
                    \.rawValue
            ) { status in

                statusButton(
                    status
                )
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
    }

    private func statusButton(
        _ status:
            MaterialsView.CoachMaterialStatus
    ) -> some View {

        let selected =
            progress.isSelected(
                status
            )

        let canSelect =
            selected ||
            progress.selectedStatuses.count < 2

        let activeColor =
            color(
                for:
                    status
            )

        return Button {

            if canSelect {

                onSelect(
                    status
                )
            }

        } label: {

            VStack(
                spacing:
                    1
            ) {

                Text(
                    label(
                        for:
                            status
                    )
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    selected
                        ? .heavy
                        : .bold
                )
                .foregroundStyle(
                    selected
                        ? activeColor
                        : KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.70
                )

                if selected {

                    let dateValue =
                        progress.updatedAt(
                            for:
                                status
                        )

                    if dateValue > 0 {

                        Text(
                            formattedDate(
                                dateValue
                            )
                        )
                        .kmiTypography(
                            .caption
                        )
                        .foregroundStyle(
                            activeColor.opacity(
                                0.88
                            )
                        )
                        .lineLimit(
                            1
                        )
                        .minimumScaleFactor(
                            0.72
                        )
                    }
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                        .continuous
                )
                .fill(
                    activeColor.opacity(
                        selected
                            ? (
                                colorScheme == .dark
                                    ? 0.18
                                    : 0.10
                            )
                            : (
                                colorScheme == .dark
                                    ? 0.08
                                    : 0.05
                            )
                    )
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                        .continuous
                )
                .stroke(
                    activeColor.opacity(
                        selected
                            ? 0.46
                            : 0.16
                    ),
                    lineWidth:
                        selected
                            ? 0.9
                            : 0.7
                )
            }
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            !canSelect
        )
        .opacity(
            canSelect
                ? 1.0
                : 0.55
        )
        .frame(
            width:
                buttonWidth,
            height:
                40
        )
        .accessibilityLabel(
            label(
                for:
                    status
            )
        )
    }

    private func label(
        for status:
            MaterialsView.CoachMaterialStatus
    ) -> String {

        switch status {

        case .taught:

            return isEnglish
                ? "Taught"
                : "נלמד"

        case .practiced:

            return isEnglish
                ? "Practiced"
                : "תורגל"

        case .needsReinforcement:

            return isEnglish
                ? "Reinforce"
                : "חיזוק"

        case .notTaught:

            return isEnglish
                ? "Not taught"
                : "לא נלמד"
        }
    }

    private func color(
        for status:
            MaterialsView.CoachMaterialStatus
    ) -> Color {

        switch status {

        case .taught:

            return Color(
                red:
                    47 / 255,
                green:
                    155 / 255,
                blue:
                    78 / 255
            )

        case .practiced:

            return KmiAppTheme
                .primary(
                    for:
                        colorScheme
                )

        case .needsReinforcement:

            return Color(
                red:
                    185 / 255,
                green:
                    107 / 255,
                blue:
                    18 / 255
            )

        case .notTaught:

            return KmiAppTheme
                .onSurfaceVariant(
                    for:
                        colorScheme
                )
        }
    }

    private func formattedDate(
        _ millis: Int64
    ) -> String {

        let date =
            Date(
                timeIntervalSince1970:
                    TimeInterval(
                        millis
                    ) / 1000
            )

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "dd/MM/yy"

        return formatter.string(
            from:
                date
        )
    }
}

private struct MaterialsTraineeStatusSelector:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let mark:
        MaterialsView.RowMark?

    let updatedAt:
        Int64

    let buttonWidth:
        CGFloat

    let isEnglish: Bool

    let onSelect:
        (MaterialsView.RowMark?) -> Void

    private let statuses:
        [MaterialsView.RowMark] = [
            .mastered,
            .partiallyKnown,
            .unknown
        ]

    var body: some View {

        HStack(
            spacing:
                4
        ) {

            ForEach(
                statuses,
                id:
                    \.rawValue
            ) { status in

                statusButton(
                    status
                )
            }
        }
        .frame(
            maxWidth:
                .infinity
        )
    }

    private func statusButton(
        _ status:
            MaterialsView.RowMark
    ) -> some View {

        let selected =
            mark == status

        let activeColor =
            color(
                for:
                    status
            )

        return Button {

            onSelect(
                selected
                    ? nil
                    : status
            )

        } label: {

            VStack(
                spacing:
                    1
            ) {

                Text(
                    label(
                        for:
                            status
                    )
                )
                .kmiTypography(
                    .caption
                )
                .fontWeight(
                    selected
                        ? .heavy
                        : .bold
                )
                .foregroundStyle(
                    selected
                        ? activeColor
                        : KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.70
                )

                if selected &&
                    updatedAt > 0 {

                    Text(
                        formattedDate(
                            updatedAt
                        )
                    )
                    .kmiTypography(
                        .caption
                    )
                    .foregroundStyle(
                        activeColor.opacity(
                            0.88
                        )
                    )
                    .lineLimit(
                        1
                    )
                    .minimumScaleFactor(
                        0.72
                    )
                }
            }
            .frame(
                maxWidth:
                    .infinity,
                maxHeight:
                    .infinity
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                        .continuous
                )
                .fill(
                    activeColor.opacity(
                        selected
                            ? (
                                colorScheme == .dark
                                    ? 0.18
                                    : 0.10
                            )
                            : (
                                colorScheme == .dark
                                    ? 0.08
                                    : 0.05
                            )
                    )
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        7,
                    style:
                        .continuous
                )
                .stroke(
                    activeColor.opacity(
                        selected
                            ? 0.46
                            : 0.16
                    ),
                    lineWidth:
                        selected
                            ? 0.9
                            : 0.7
                )
            }
        }
        .buttonStyle(
            .plain
        )
        .frame(
            width:
                buttonWidth,
            height:
                40
        )
        .accessibilityLabel(
            label(
                for:
                    status
            )
        )
    }

    private func label(
        for status:
            MaterialsView.RowMark
    ) -> String {

        switch status {

        case .mastered:

            return isEnglish
                ? "Known"
                : "יודע"

        case .partiallyKnown:

            return isEnglish
                ? "Partly"
                : "חלקית"

        case .unknown:

            return isEnglish
                ? "Unknown"
                : "לא יודע"
        }
    }

    private func color(
        for status:
            MaterialsView.RowMark
    ) -> Color {

        switch status {

        case .mastered:

            return Color(
                red:
                    47 / 255,
                green:
                    155 / 255,
                blue:
                    78 / 255
            )

        case .partiallyKnown:

            return Color(
                red:
                    185 / 255,
                green:
                    107 / 255,
                blue:
                    18 / 255
            )

        case .unknown:

            return Color(
                red:
                    198 / 255,
                green:
                    79 / 255,
                blue:
                    85 / 255
            )
        }
    }

    private func formattedDate(
        _ millis: Int64
    ) -> String {

        let date =
            Date(
                timeIntervalSince1970:
                    TimeInterval(
                        millis
                    ) / 1000
            )

        let formatter =
            DateFormatter()

        formatter.dateFormat =
            "dd/MM/yy"

        return formatter.string(
            from:
                date
        )
    }
}

// MARK: - Premium Note Sheet

private struct MaterialsPremiumNoteSheet:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let title: String

    @Binding
    var noteText: String

    let isEnglish: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    private var textAlignment:
        TextAlignment {

        isEnglish
            ? .leading
            : .trailing
    }

    private var frameAlignment:
        Alignment {

        isEnglish
            ? .leading
            : .trailing
    }

    private var hasNote:
        Bool {

        !noteText
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
    }

    var body: some View {

        ZStack {

            KmiAppBackground()

            VStack(
                spacing:
                    16
            ) {

                VStack(
                    alignment:
                        isEnglish
                            ? .leading
                            : .trailing,
                    spacing:
                        6
                ) {

                    Text(
                        isEnglish
                            ? "Exercise Note"
                            : "הערה על התרגיל"
                    )
                    .kmiTypography(
                        .sectionTitle
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onBackground(
                                for:
                                    colorScheme
                            )
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )

                    Text(
                        title
                    )
                    .kmiTypography(
                        .secondary
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurfaceVariant(
                                for:
                                    colorScheme
                            )
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )
                }

                TextEditor(
                    text:
                        $noteText
                )
                .kmiTypography(
                    .body
                )
                .foregroundStyle(
                    KmiAppTheme
                        .onSurface(
                            for:
                                colorScheme
                        )
                )
                .scrollContentBackground(
                    .hidden
                )
                .padding(
                    12
                )
                .frame(
                    minHeight:
                        180
                )
                .background {

                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                    .fill(
                        KmiAppTheme
                            .surface(
                                for:
                                    colorScheme
                            )
                    )
                }
                .overlay {

                    RoundedRectangle(
                        cornerRadius:
                            18,
                        style:
                            .continuous
                    )
                    .stroke(
                        KmiAppTheme
                            .outlineVariant(
                                for:
                                    colorScheme
                            ),
                        lineWidth:
                            1
                    )
                }
                .multilineTextAlignment(
                    textAlignment
                )

                HStack(
                    spacing:
                        10
                ) {

                    Button {

                        onCancel()

                    } label: {

                        Text(
                            isEnglish
                                ? "Cancel"
                                : "ביטול"
                        )
                        .kmiTypography(
                            .action
                        )
                        .foregroundStyle(
                            KmiAppTheme
                                .primary(
                                    for:
                                        colorScheme
                                )
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(
                            height:
                                48
                        )
                        .background {

                            RoundedRectangle(
                                cornerRadius:
                                    16,
                                style:
                                    .continuous
                            )
                            .fill(
                                KmiAppTheme
                                    .surfaceVariant(
                                        for:
                                            colorScheme
                                    )
                            )
                        }
                    }
                    .buttonStyle(
                        .plain
                    )

                    Button {

                        onSave()

                    } label: {

                        Text(
                            isEnglish
                                ? "Save"
                                : "שמור"
                        )
                        .kmiTypography(
                            .action
                        )
                        .foregroundStyle(
                            KmiAppTheme
                                .onPrimary(
                                    for:
                                        colorScheme
                                )
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(
                            height:
                                48
                        )
                        .background {

                            RoundedRectangle(
                                cornerRadius:
                                    16,
                                style:
                                    .continuous
                            )
                            .fill(
                                KmiAppTheme
                                    .primary(
                                        for:
                                            colorScheme
                                    )
                            )
                        }
                    }
                    .buttonStyle(
                        .plain
                    )
                }

                if hasNote {

                    Button {

                        onDelete()

                    } label: {

                        Label(
                            isEnglish
                                ? "Delete note"
                                : "מחק הערה",
                            systemImage:
                                "trash.fill"
                        )
                        .kmiTypography(
                            .action
                        )
                        .foregroundStyle(
                            KmiAppTheme
                                .error(
                                    for:
                                        colorScheme
                                )
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .padding(
                            .vertical,
                            8
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }

                Spacer(
                    minLength:
                        0
                )
            }
            .padding(
                .horizontal,
                20
            )
            .padding(
                .top,
                22
            )
            .padding(
                .bottom,
                16
            )
        }
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
    }
}

// MARK: - General note sheet

private struct MaterialsGeneralNoteSheet:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let note: String
    let isEnglish: Bool
    let accentColor: Color
    let onClose: () -> Void

    private var textAlignment:
        TextAlignment {

        isEnglish
            ? .leading
            : .trailing
    }

    private var frameAlignment:
        Alignment {

        isEnglish
            ? .leading
            : .trailing
    }

    var body: some View {

        ZStack {

            KmiAppBackground()

            VStack(
                spacing:
                    14
            ) {

                Capsule()
                    .fill(
                        KmiAppTheme
                            .outline(
                                for:
                                    colorScheme
                            )
                            .opacity(
                                0.24
                            )
                    )
                    .frame(
                        width:
                            42,
                        height:
                            5
                    )
                    .padding(
                        .top,
                        7
                    )

                ZStack {

                    Circle()
                        .fill(
                            accentColor
                                .opacity(
                                    0.12
                                )
                        )
                        .frame(
                            width:
                                46,
                            height:
                                46
                        )

                    Circle()
                        .stroke(
                            accentColor
                                .opacity(
                                    0.30
                                ),
                            lineWidth:
                                1
                        )
                        .frame(
                            width:
                                46,
                            height:
                                46
                        )

                    Image(
                        systemName:
                            "info.circle.fill"
                    )
                    .kmiIconSize(
                        23
                    )
                    .foregroundStyle(
                        accentColor
                    )
                }

                Text(
                    isEnglish
                        ? "General notes"
                        : "דגשים כלליים"
                )
                .kmiTypography(
                    .sectionTitle
                )
                .foregroundStyle(
                    KmiAppTheme
                        .onBackground(
                            for:
                                colorScheme
                        )
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        frameAlignment
                )
                .multilineTextAlignment(
                    textAlignment
                )

                Text(
                    title
                )
                .kmiTypography(
                    .cardTitle
                )
                .foregroundStyle(
                    accentColor
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        frameAlignment
                )
                .multilineTextAlignment(
                    textAlignment
                )

                ScrollView {

                    Text(
                        note
                    )
                    .kmiTypography(
                        .body
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurface(
                                for:
                                    colorScheme
                            )
                    )
                    .lineSpacing(
                        5
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .padding(
                        16
                    )
                    .background {

                        RoundedRectangle(
                            cornerRadius:
                                18,
                            style:
                                .continuous
                        )
                        .fill(
                            KmiAppTheme
                                .surface(
                                    for:
                                        colorScheme
                                )
                        )
                    }
                    .overlay {

                        RoundedRectangle(
                            cornerRadius:
                                18,
                            style:
                                .continuous
                        )
                        .stroke(
                            KmiAppTheme
                                .outlineVariant(
                                    for:
                                        colorScheme
                                ),
                            lineWidth:
                                1
                        )
                    }
                }

                Button {

                    onClose()

                } label: {

                    Text(
                        isEnglish
                            ? "Close"
                            : "סגור"
                    )
                    .kmiTypography(
                        .action
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onPrimary(
                                for:
                                    colorScheme
                            )
                    )
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height:
                            48
                    )
                    .background {

                        RoundedRectangle(
                            cornerRadius:
                                16,
                            style:
                                .continuous
                        )
                        .fill(
                            KmiAppTheme
                                .primary(
                                    for:
                                        colorScheme
                                )
                        )
                    }
                }
                .buttonStyle(
                    .plain
                )
            }
            .padding(
                .horizontal,
                20
            )
            .padding(
                .bottom,
                18
            )
        }
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
    }
}

// MARK: - Info sheet

private struct MaterialsInfoSheet:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let text: String
    let isFavorite: Bool
    let isSpeaking: Bool
    let isEnglish: Bool
    let accentColor: Color

    let onClose: () -> Void
    let onToggleFavorite: () -> Void
    let onSpeak: () -> Void
    let onEditNote: () -> Void

    private var textAlignment:
        TextAlignment {

        isEnglish
            ? .leading
            : .trailing
    }

    private var frameAlignment:
        Alignment {

        isEnglish
            ? .leading
            : .trailing
    }

    var body: some View {

        ZStack {

            KmiAppBackground()

            VStack(
                spacing:
                    14
            ) {

                HStack(
                    spacing:
                        10
                ) {

                    if isEnglish {

                        titleBlock
                        closeButton

                    } else {

                        closeButton
                        titleBlock
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )

                ScrollView {

                    Text(
                        materialsFormattedExplanation(
                            text
                        )
                    )
                    .kmiTypography(
                        .body
                    )
                    .foregroundStyle(
                        KmiAppTheme
                            .onSurface(
                                for:
                                    colorScheme
                            )
                    )
                    .lineSpacing(
                        5
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            frameAlignment
                    )
                    .padding(
                        16
                    )
                    .background {

                        RoundedRectangle(
                            cornerRadius:
                                18,
                            style:
                                .continuous
                        )
                        .fill(
                            KmiAppTheme
                                .surface(
                                    for:
                                        colorScheme
                                )
                        )
                    }
                    .overlay {

                        RoundedRectangle(
                            cornerRadius:
                                18,
                            style:
                                .continuous
                        )
                        .stroke(
                            KmiAppTheme
                                .outlineVariant(
                                    for:
                                        colorScheme
                                ),
                            lineWidth:
                                1
                        )
                    }
                }

                VStack(
                    spacing:
                        10
                ) {

                    HStack(
                        spacing:
                            10
                    ) {

                        MaterialsInfoActionButton(
                            title:
                                isSpeaking
                                    ? (
                                        isEnglish
                                            ? "Stop"
                                            : "עצור"
                                    )
                                    : (
                                        isEnglish
                                            ? "Speak"
                                            : "הקראה"
                                    ),
                            systemName:
                                isSpeaking
                                    ? "stop.fill"
                                    : "speaker.wave.2.fill",
                            fill:
                                isSpeaking
                                    ? KmiAppTheme
                                        .error(
                                            for:
                                                colorScheme
                                        )
                                    : KmiAppTheme
                                        .primary(
                                            for:
                                                colorScheme
                                        ),
                            onTap:
                                onSpeak
                        )

                        MaterialsInfoActionButton(
                            title:
                                isFavorite
                                    ? (
                                        isEnglish
                                            ? "Favorited"
                                            : "מועדף"
                                    )
                                    : (
                                        isEnglish
                                            ? "Favorite"
                                            : "הוסף למועדפים"
                                    ),
                            systemName:
                                isFavorite
                                    ? "star.fill"
                                    : "star",
                            fill:
                                KmiAppTheme
                                    .warning(
                                        for:
                                            colorScheme
                                    ),
                            onTap:
                                onToggleFavorite
                        )
                    }

                    MaterialsInfoActionButton(
                        title:
                            isEnglish
                                ? "Edit / add note"
                                : "ערוך / הוסף הערה",
                        systemName:
                            "note.text",
                        fill:
                            accentColor,
                        onTap:
                            onEditNote
                    )
                }
            }
            .padding(
                .horizontal,
                18
            )
            .padding(
                .top,
                18
            )
            .padding(
                .bottom,
                16
            )
        }
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
    }

    private var titleBlock:
        some View {

        VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing:
                7
        ) {

            Text(
                title
            )
            .kmiTypography(
                .sectionTitle
            )
            .foregroundStyle(
                KmiAppTheme
                    .onBackground(
                        for:
                            colorScheme
                    )
            )
            .multilineTextAlignment(
                textAlignment
            )
            .lineLimit(
                3
            )
            .minimumScaleFactor(
                0.76
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    frameAlignment
            )

            Label(
                isEnglish
                    ? "Detailed explanation"
                    : "הסבר מפורט",
                systemImage:
                    "doc.text.fill"
            )
            .kmiTypography(
                .caption
            )
            .foregroundStyle(
                KmiAppTheme
                    .onSurfaceVariant(
                        for:
                            colorScheme
                    )
            )
            .frame(
                maxWidth:
                    .infinity,
                alignment:
                    frameAlignment
            )
        }
    }

    private var closeButton:
        some View {

        Button {

            onClose()

        } label: {

            ZStack {

                Circle()
                    .fill(
                        KmiAppTheme
                            .surface(
                                for:
                                    colorScheme
                            )
                    )
                    .frame(
                        width:
                            38,
                        height:
                            38
                    )

                Circle()
                    .stroke(
                        KmiAppTheme
                            .outlineVariant(
                                for:
                                    colorScheme
                            ),
                        lineWidth:
                            1
                    )
                    .frame(
                        width:
                            38,
                        height:
                            38
                    )

                Image(
                    systemName:
                        "xmark"
                )
                .kmiIconSize(
                    13
                )
                .foregroundStyle(
                    KmiAppTheme
                        .onSurface(
                            for:
                                colorScheme
                        )
                )
            }
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            isEnglish
                ? "Close"
                : "סגור"
        )
    }
}

private struct MaterialsInfoActionButton:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let systemName: String
    let fill: Color
    let onTap: () -> Void

    @State
    private var pressed:
        Bool = false

    private var contentColor:
        Color {

        fill.luminance < 0.56
            ? Color.white
            : KmiAppTheme
                .onSurface(
                    for:
                        colorScheme
                )
    }

    var body: some View {

        Button {

            withAnimation(
                .easeOut(
                    duration:
                        0.10
                )
            ) {

                pressed =
                    true
            }

            onTap()

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now() + 0.14
                ) {

                    withAnimation(
                        .easeOut(
                            duration:
                                0.12
                        )
                    ) {

                        pressed =
                            false
                    }
                }

        } label: {

            HStack(
                spacing:
                    8
            ) {

                Image(
                    systemName:
                        systemName
                )
                .kmiIconSize(
                    14
                )

                Text(
                    title
                )
                .kmiTypography(
                    .action
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.78
                )
            }
            .foregroundStyle(
                contentColor
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    48
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .fill(
                    fill
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .stroke(
                    KmiAppTheme
                        .outlineVariant(
                            for:
                                colorScheme
                        )
                        .opacity(
                            0.45
                        ),
                    lineWidth:
                        1
                )
            }
            .scaleEffect(
                pressed
                    ? 0.96
                    : 1.0
            )
        }
        .buttonStyle(
            .plain
        )
    }
}

// MARK: - Bottom bar

private struct MaterialsBottomBar:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let belt: Belt
    let isEnglish: Bool
    let isPracticeLocked: Bool

    let onPractice: () -> Void
    let onSummary: () -> Void
    let onReset: () -> Void

    private var beltColor:
        Color {

        BeltPaletteByMaterials
            .color(
                for:
                    belt
            )
    }

    var body: some View {

        VStack(
            spacing:
                10
        ) {

            HStack(
                spacing:
                    10
            ) {

                if isEnglish {

                    practiceButton
                    resetButton

                } else {

                    resetButton
                    practiceButton
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            MaterialsActionButton(
                title:
                    isEnglish
                        ? "Summary"
                        : "סיכום",
                fill:
                    KmiAppTheme
                        .primary(
                            for:
                                colorScheme
                        ),
                systemImage:
                    "chart.bar.doc.horizontal",
                onTap:
                    onSummary
            )
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .top,
            8
        )
        .padding(
            .bottom,
            8
        )
        .background {

            KmiAppTheme
                .surface(
                    for:
                        colorScheme
                )
                .ignoresSafeArea(
                    edges:
                        .bottom
                )
        }
        .overlay(
            alignment:
                .top
        ) {

            Rectangle()
                .fill(
                    KmiAppTheme
                        .outlineVariant(
                            for:
                                colorScheme
                        )
                )
                .frame(
                    height:
                        1
                )
        }
    }

    private var practiceButton:
        some View {

        MaterialsActionButton(
            title:
                isEnglish
                    ? "Practice"
                    : "תרגול",
            fill:
                isPracticeLocked
                    ? KmiAppTheme
                        .warning(
                            for:
                                colorScheme
                        )
                    : beltColor,
            systemImage:
                isPracticeLocked
                    ? "lock.fill"
                    : "figure.martial.arts",
            onTap:
                onPractice
        )
    }

    private var resetButton:
        some View {

        MaterialsActionButton(
            title:
                isEnglish
                    ? "Reset"
                    : "איפוס",
            fill:
                KmiAppTheme
                    .error(
                        for:
                            colorScheme
                    ),
            systemImage:
                "arrow.counterclockwise",
            onTap:
                onReset
        )
    }
}

private struct MaterialsActionButton:
    View {

    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let fill: Color
    let systemImage: String?
    let onTap: () -> Void

    @State
    private var pressed:
        Bool = false

    private var contentColor:
        Color {

        fill.luminance < 0.50
            ? Color.white
            : KmiAppTheme
                .onSurface(
                    for:
                        colorScheme
                )
    }

    var body: some View {

        Button {

            withAnimation(
                .easeOut(
                    duration:
                        0.10
                )
            ) {

                pressed =
                    true
            }

            onTap()

            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now() + 0.14
                ) {

                    withAnimation(
                        .easeOut(
                            duration:
                                0.12
                        )
                    ) {

                        pressed =
                            false
                    }
                }

        } label: {

            HStack(
                spacing:
                    7
            ) {

                if let systemImage {

                    Image(
                        systemName:
                            systemImage
                    )
                    .kmiIconSize(
                        15
                    )
                }

                Text(
                    title
                )
                .kmiTypography(
                    .action
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.78
                )
                .multilineTextAlignment(
                    .center
                )
            }
            .foregroundStyle(
                contentColor
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    44
            )
            .background {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .fill(
                    fill
                )
            }
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        16,
                    style:
                        .continuous
                )
                .stroke(
                    Color.white
                        .opacity(
                            fill.luminance < 0.50
                                ? 0.20
                                : 0.10
                        ),
                    lineWidth:
                        1
                )
            }
            .scaleEffect(
                pressed
                    ? 0.97
                    : 1.0
            )
        }
        .buttonStyle(
            .plain
        )
    }
}

private func materialsFormattedExplanation(
    _ source: String
) -> AttributedString {

    var result =
        AttributedString()

    var remaining =
        source[...]

    let redStart =
        "[[RED_BOLD]]"

    let redEnd =
        "[[/RED_BOLD]]"

    let blueStart =
        "[[BLUE_BOLD]]"

    let blueEnd =
        "[[/BLUE_BOLD]]"

    while !remaining.isEmpty {

        let redRange =
            remaining.range(
                of:
                    redStart
            )

        let blueRange =
            remaining.range(
                of:
                    blueStart
            )

        let nextRange:
            Range<String.Index>?

        let color:
            Color

        let closingTag:
            String

        switch (
            redRange,
            blueRange
        ) {

        case let (
            .some(red),
            .some(blue)
        ):

            if red.lowerBound <
                blue.lowerBound {

                nextRange =
                    red

                color =
                    .red

                closingTag =
                    redEnd

            } else {

                nextRange =
                    blue

                color =
                    Color(
                        red:
                            0.10,
                        green:
                            0.42,
                        blue:
                            0.92
                    )

                closingTag =
                    blueEnd
            }

        case let (
            .some(red),
            .none
        ):

            nextRange =
                red

            color =
                .red

            closingTag =
                redEnd

        case let (
            .none,
            .some(blue)
        ):

            nextRange =
                blue

            color =
                Color(
                    red:
                        0.10,
                    green:
                        0.42,
                    blue:
                        0.92
                )

            closingTag =
                blueEnd

        case (
            .none,
            .none
        ):

            result.append(
                AttributedString(
                    String(
                        remaining
                    )
                )
            )

            remaining =
                remaining[
                    remaining.endIndex...
                ]

            continue
        }

        guard
            let nextRange
        else {
            break
        }

        let plainText =
            remaining[
                ..<nextRange.lowerBound
            ]

        result.append(
            AttributedString(
                String(
                    plainText
                )
            )
        )

        let markedStart =
            nextRange.upperBound

        let markedRemainder =
            remaining[
                markedStart...
            ]

        guard
            let closingRange =
                markedRemainder
                    .range(
                        of:
                            closingTag
                    )
        else {

            result.append(
                AttributedString(
                    String(
                        remaining[
                            nextRange.lowerBound...
                        ]
                    )
                )
            )

            break
        }

        var highlighted =
            AttributedString(
                String(
                    markedRemainder[
                        ..<closingRange.lowerBound
                    ]
                )
            )

        highlighted
            .foregroundColor =
                color

        highlighted
            .font =
                .system(
                    size:
                        16.2,
                    weight:
                        .bold
                )

        result.append(
            highlighted
        )

        remaining =
            markedRemainder[
                closingRange.upperBound...
            ]
    }

    return result
}

// MARK: - Palette

private enum BeltPaletteByMaterials {
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
}

#Preview {
    NavigationStack {
        MaterialsView(
            belt: .orange,
            topicTitle: "שחרורים",
            subTopicTitle: nil
        )
    }
}

struct MaterialsPdfItemIOS:
    Hashable {
    let number: Int
    let title: String
    let status: String
    let isFavorite: Bool
    let isExcluded: Bool
    let hasNote: Bool

    init(
        number: Int,
        title: String,
        status: String,
        isFavorite: Bool,
        isExcluded: Bool,
        hasNote: Bool
    ) {
        self.number = number
        self.title = title
        self.status = status
        self.isFavorite = isFavorite
        self.isExcluded = isExcluded
        self.hasNote = hasNote
    }
}

enum MaterialsPdfGeneratorIOS {

    static func create(
        belt: Belt,
        topicTitle: String,
        items: [MaterialsPdfItemIOS],
        isEnglish: Bool
    ) throws -> URL {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: pageWidth,
            height: pageHeight
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let fileName = "materials_\(Int(Date().timeIntervalSince1970)).pdf"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try renderer.writePDF(to: fileURL) { context in
            let firstPageCapacity = 6
            let nextPageCapacity = 8

            let totalPages: Int = {
                if items.count <= firstPageCapacity {
                    return 1
                }

                let remaining = items.count - firstPageCapacity
                return 1 + Int(ceil(Double(remaining) / Double(nextPageCapacity)))
            }()

            var itemIndex = 0

            for pageNumber in 1...totalPages {
                context.beginPage()

                drawHeader(
                    context: context.cgContext,
                    pageBounds: pageBounds,
                    topicTitle: topicTitle,
                    isEnglish: isEnglish
                )

                var currentY: CGFloat = 136

                if pageNumber == 1 {
                    currentY = drawSummary(
                        context: context.cgContext,
                        pageBounds: pageBounds,
                        top: currentY,
                        items: items,
                        isEnglish: isEnglish
                    )
                } else {
                    drawText(
                        isEnglish ? "Exercises list" : "רשימת תרגילים",
                        in: CGRect(
                            x: 24,
                            y: currentY,
                            width: pageWidth - 48,
                            height: 24
                        ),
                        font: .systemFont(ofSize: 17, weight: .bold),
                        color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
                        alignment: .center
                    )

                    currentY += 34
                }

                let capacity = pageNumber == 1
                    ? firstPageCapacity
                    : nextPageCapacity

                if items.isEmpty {
                    drawRoundedBox(
                        context: context.cgContext,
                        rect: CGRect(
                            x: 24,
                            y: currentY,
                            width: pageWidth - 48,
                            height: 92
                        ),
                        fill: UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
                        stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
                    )

                    drawText(
                        isEnglish
                        ? "No exercises to display"
                        : "אין תרגילים להצגה",
                        in: CGRect(
                            x: 40,
                            y: currentY + 28,
                            width: pageWidth - 80,
                            height: 32
                        ),
                        font: .systemFont(ofSize: 17, weight: .bold),
                        color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
                        alignment: .center
                    )
                } else {
                    for _ in 0..<capacity {
                        guard itemIndex < items.count else { break }

                        currentY = drawItem(
                            context: context.cgContext,
                            pageBounds: pageBounds,
                            item: items[itemIndex],
                            top: currentY,
                            isEnglish: isEnglish,
                            alternate: itemIndex.isMultiple(of: 2)
                        )

                        itemIndex += 1
                    }
                }

                drawFooter(
                    context: context.cgContext,
                    pageBounds: pageBounds,
                    pageNumber: pageNumber,
                    totalPages: totalPages,
                    isEnglish: isEnglish
                )
            }
        }

        return fileURL
    }

    private static func drawHeader(
        context: CGContext,
        pageBounds: CGRect,
        topicTitle: String,
        isEnglish: Bool
    ) {
        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageBounds)

        let navy = UIColor(
            red: 2 / 255,
            green: 43 / 255,
            blue: 74 / 255,
            alpha: 1
        )

        context.setFillColor(navy.cgColor)

        let headerPath = UIBezierPath()
        headerPath.move(to: CGPoint(x: pageBounds.width, y: 0))
        headerPath.addLine(to: CGPoint(x: pageBounds.width, y: 122))
        headerPath.addLine(to: CGPoint(x: 178, y: 122))
        headerPath.addLine(to: CGPoint(x: 238, y: 0))
        headerPath.close()
        headerPath.fill()

        drawLogo(
            context: context,
            center: CGPoint(x: 78, y: 58),
            radius: 42
        )

        drawText(
            isEnglish ? "Belt exercises" : "תרגילים לפי חגורה",
            in: CGRect(
                x: 250,
                y: 28,
                width: pageBounds.width - 284,
                height: 38
            ),
            font: .systemFont(ofSize: 28, weight: .bold),
            color: .white,
            alignment: isEnglish ? .left : .right
        )

        drawText(
            String(topicTitle.prefix(52)),
            in: CGRect(
                x: 250,
                y: 68,
                width: pageBounds.width - 284,
                height: 28
            ),
            font: .systemFont(ofSize: 14, weight: .regular),
            color: .white,
            alignment: isEnglish ? .left : .right
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        drawText(
            "\(isEnglish ? "Generated:" : "תאריך הפקה:") \(formatter.string(from: Date()))",
            in: CGRect(
                x: 24,
                y: 130,
                width: pageBounds.width - 48,
                height: 18
            ),
            font: .systemFont(ofSize: 9),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )
    }

    private static func drawSummary(
        context: CGContext,
        pageBounds: CGRect,
        top: CGFloat,
        items: [MaterialsPdfItemIOS],
        isEnglish: Bool
    ) -> CGFloat {
        let knownTitle =
            isEnglish ? "Known" : "יודע"

        let partiallyKnownTitle =
            isEnglish
            ? "Partially known"
            : "יודע חלקית"

        let unknownTitle =
            isEnglish ? "Unknown" : "לא יודע"

        let notTaughtTitle =
            isEnglish ? "Not taught" : "לא נלמד"

        let taughtTitle =
            isEnglish ? "Taught" : "נלמד"

        let practicedTitle =
            isEnglish ? "Practiced" : "תורגל"

        let reinforcementTitle =
            isEnglish
            ? "Needs reinforcement"
            : "נדרש חיזוק"

        /*
         * מזהים את סוג הדוח לפי הסטטוסים
         * שכבר הוכנסו לפריטי ה־PDF.
         */
        let coachStatusTitles: Set<String> = [
            notTaughtTitle,
            taughtTitle,
            practicedTitle,
            reinforcementTitle
        ]

        let isCoachReport =
            items.contains { item in
                coachStatusTitles.contains(
                    item.status
                )
            }

        /*
         * מחשבים את כל הספירות לפני יצירת המחרוזות.
         *
         * כך אין ביטויי filter שנשברים על כמה
         * שורות בתוך String interpolation.
         */
        let knownCount =
            items.filter { item in
                item.status == knownTitle
            }.count

        let partiallyKnownCount =
            items.filter { item in
                item.status == partiallyKnownTitle
            }.count

        let unknownCount =
            items.filter { item in
                item.status == unknownTitle
            }.count

        let notTaughtCount =
            items.filter { item in
                item.status == notTaughtTitle
            }.count

        let taughtCount =
            items.filter { item in
                item.status == taughtTitle
            }.count

        let practicedCount =
            items.filter { item in
                item.status == practicedTitle
            }.count

        let reinforcementCount =
            items.filter { item in
                item.status == reinforcementTitle
            }.count

        let favoritesCount =
            items.filter { item in
                item.isFavorite
            }.count

        let excludedCount =
            items.filter { item in
                item.isExcluded
            }.count

        let notesCount =
            items.filter { item in
                item.hasNote
            }.count

        let stats: [(String, String)]

        if isCoachReport {
            stats = [
                (
                    String(practicedCount),
                    practicedTitle
                ),
                (
                    String(reinforcementCount),
                    isEnglish
                        ? "Reinforce"
                        : "נדרש חיזוק"
                ),
                (
                    String(taughtCount),
                    taughtTitle
                ),
                (
                    String(notTaughtCount),
                    notTaughtTitle
                ),
                (
                    String(favoritesCount),
                    isEnglish
                        ? "Favorites"
                        : "מועדפים"
                ),
                (
                    String(excludedCount),
                    isEnglish
                        ? "Excluded"
                        : "מוחרגים"
                )
            ]
        } else {
            stats = [
                (
                    String(items.count),
                    isEnglish
                        ? "Exercises"
                        : "תרגילים"
                ),
                (
                    String(knownCount),
                    knownTitle
                ),
                (
                    String(partiallyKnownCount),
                    isEnglish
                        ? "Partial"
                        : "חלקית"
                ),
                (
                    String(unknownCount),
                    unknownTitle
                ),
                (
                    String(favoritesCount),
                    isEnglish
                        ? "Favorites"
                        : "מועדפים"
                ),
                (
                    String(notesCount),
                    isEnglish
                        ? "Notes"
                        : "הערות"
                )
            ]
        }

        let container = CGRect(
            x: 24,
            y: top,
            width: pageBounds.width - 48,
            height: 120
        )

        drawRoundedBox(
            context: context,
            rect: container,
            fill: UIColor(red: 234 / 255, green: 246 / 255, blue: 1, alpha: 1),
            stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
        )

        drawText(
            isEnglish ? "Exercises summary" : "סיכום תרגילים",
            in: CGRect(
                x: container.minX + 18,
                y: container.minY + 12,
                width: container.width - 36,
                height: 24
            ),
            font: .systemFont(ofSize: 17, weight: .bold),
            color: UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )

        let boxWidth = (container.width - 38) / 3

        for (index, stat) in stats.enumerated() {
            let row = index / 3
            let column = index % 3

            let rect = CGRect(
                x: container.minX + 12 + CGFloat(column) * (boxWidth + 7),
                y: container.minY + 45 + CGFloat(row) * 34,
                width: boxWidth,
                height: 28
            )

            drawRoundedBox(
                context: context,
                rect: rect,
                fill: UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
                stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1),
                radius: 9
            )

            drawText(
                stat.0,
                in: CGRect(
                    x: rect.minX,
                    y: rect.minY + 2,
                    width: rect.width,
                    height: 13
                ),
                font: .systemFont(ofSize: 12, weight: .bold),
                color: UIColor(red: 2 / 255, green: 43 / 255, blue: 74 / 255, alpha: 1),
                alignment: .center
            )

            drawText(
                stat.1,
                in: CGRect(
                    x: rect.minX,
                    y: rect.minY + 14,
                    width: rect.width,
                    height: 12
                ),
                font: .systemFont(ofSize: 8.5),
                color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
                alignment: .center
            )
        }

        return top + 144
    }

    private static func drawItem(
        context: CGContext,
        pageBounds: CGRect,
        item: MaterialsPdfItemIOS,
        top: CGFloat,
        isEnglish: Bool,
        alternate: Bool
    ) -> CGFloat {
        let rect = CGRect(
            x: 24,
            y: top,
            width: pageBounds.width - 48,
            height: 74
        )

        drawRoundedBox(
            context: context,
            rect: rect,
            fill: alternate
            ? UIColor(red: 234 / 255, green: 246 / 255, blue: 1, alpha: 1)
            : UIColor(red: 244 / 255, green: 250 / 255, blue: 1, alpha: 1),
            stroke: UIColor(red: 191 / 255, green: 213 / 255, blue: 232 / 255, alpha: 1)
        )

        let numberRect = CGRect(
            x: isEnglish ? rect.minX + 18 : rect.maxX - 50,
            y: rect.minY + 20,
            width: 30,
            height: 30
        )

        context.setFillColor(
            UIColor(red: 12 / 255, green: 78 / 255, blue: 130 / 255, alpha: 1).cgColor
        )
        context.fillEllipse(in: numberRect)

        drawText(
            "\(item.number)",
            in: numberRect.offsetBy(dx: 0, dy: 6),
            font: .systemFont(ofSize: 11, weight: .bold),
            color: .white,
            alignment: .center
        )

        let textX = isEnglish
            ? numberRect.maxX + 14
            : rect.minX + 22

        let textWidth = rect.width - 90

        drawText(
            item.title,
            in: CGRect(
                x: textX,
                y: rect.minY + 12,
                width: textWidth,
                height: 30
            ),
            font: .systemFont(ofSize: 13, weight: .bold),
            color: UIColor(red: 15 / 255, green: 23 / 255, blue: 42 / 255, alpha: 1),
            alignment: isEnglish ? .left : .right
        )

        let statusColor: UIColor = {
            if item.status == (
                isEnglish ? "Known" : "יודע"
            ) || item.status == (
                isEnglish ? "Taught" : "נלמד"
            ) {
                return UIColor(
                    red: 47 / 255,
                    green: 155 / 255,
                    blue: 78 / 255,
                    alpha: 1
                )
            }

            if item.status == (
                isEnglish ? "Practiced" : "תורגל"
            ) {
                return UIColor(
                    red: 52 / 255,
                    green: 120 / 255,
                    blue: 212 / 255,
                    alpha: 1
                )
            }

            if item.status == (
                isEnglish
                    ? "Partially known"
                    : "יודע חלקית"
            ) {
                return UIColor(
                    red: 185 / 255,
                    green: 107 / 255,
                    blue: 18 / 255,
                    alpha: 1
                )
            }

            if item.status == (
                isEnglish
                    ? "Needs reinforcement"
                    : "נדרש חיזוק"
            ) || item.status == (
                isEnglish ? "Unknown" : "לא יודע"
            ) {
                return UIColor(
                    red: 242 / 255,
                    green: 140 / 255,
                    blue: 40 / 255,
                    alpha: 1
                )
            }

            return UIColor(
                red: 80 / 255,
                green: 100 / 255,
                blue: 120 / 255,
                alpha: 1
            )
        }()

        drawText(
            item.status,
            in: CGRect(
                x: textX,
                y: rect.minY + 45,
                width: textWidth,
                height: 18
            ),
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: statusColor,
            alignment: isEnglish ? .left : .right
        )

        var tags: [String] = []

        if item.isFavorite {
            tags.append(isEnglish ? "Favorite" : "מועדף")
        }

        if item.isExcluded {
            tags.append(isEnglish ? "Excluded" : "מוחרג")
        }

        if item.hasNote {
            tags.append(isEnglish ? "Note" : "הערה")
        }

        drawText(
            tags.isEmpty ? "—" : tags.joined(separator: " · "),
            in: CGRect(
                x: rect.minX + 18,
                y: rect.minY + 48,
                width: rect.width - 36,
                height: 16
            ),
            font: .systemFont(ofSize: 9.5),
            color: item.isExcluded
            ? UIColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255, alpha: 1)
            : UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: isEnglish ? .right : .left
        )

        return rect.maxY + 8
    }

    private static func drawFooter(
        context: CGContext,
        pageBounds: CGRect,
        pageNumber: Int,
        totalPages: Int,
        isEnglish: Bool
    ) {
        let footerY: CGFloat = 804

        context.setStrokeColor(
            UIColor(red: 2 / 255, green: 43 / 255, blue: 74 / 255, alpha: 1).cgColor
        )
        context.setLineWidth(2)
        context.move(to: CGPoint(x: 0, y: footerY))
        context.addLine(to: CGPoint(x: pageBounds.width, y: footerY))
        context.strokePath()

        drawLogo(
            context: context,
            center: CGPoint(x: 38, y: footerY + 22),
            radius: 13
        )

        drawText(
            "Together We Protect",
            in: CGRect(
                x: 58,
                y: footerY + 14,
                width: 150,
                height: 18
            ),
            font: .systemFont(ofSize: 8.5),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .left
        )

        drawText(
            isEnglish
            ? "Page \(pageNumber) of \(totalPages)"
            : "עמוד \(pageNumber) מתוך \(totalPages)",
            in: CGRect(
                x: 210,
                y: footerY + 14,
                width: 175,
                height: 18
            ),
            font: .systemFont(ofSize: 8.5),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .center
        )

        drawText(
            "Krav Maga Israel\nwww.kmi.org.il",
            in: CGRect(
                x: pageBounds.width - 180,
                y: footerY + 8,
                width: 150,
                height: 30
            ),
            font: .systemFont(ofSize: 8),
            color: UIColor(red: 80 / 255, green: 100 / 255, blue: 120 / 255, alpha: 1),
            alignment: .right
        )
    }

    private static func drawLogo(
        context: CGContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let navy = UIColor(
            red: 2 / 255,
            green: 43 / 255,
            blue: 74 / 255,
            alpha: 1
        )

        context.setFillColor(navy.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(
            in: CGRect(
                x: center.x - radius + 4,
                y: center.y - radius + 4,
                width: (radius - 4) * 2,
                height: (radius - 4) * 2
            )
        )

        drawText(
            "KAMI",
            in: CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.28,
                width: radius * 2,
                height: radius * 0.60
            ),
            font: .systemFont(
                ofSize: max(radius * 0.42, 7),
                weight: .bold
            ),
            color: navy,
            alignment: .center
        )
    }

    private static func drawRoundedBox(
        context: CGContext,
        rect: CGRect,
        fill: UIColor,
        stroke: UIColor,
        radius: CGFloat = 12
    ) {
        let path = UIBezierPath(
            roundedRect: rect,
            cornerRadius: radius
        )

        fill.setFill()
        path.fill()

        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail

        (text as NSString).draw(
            with: rect,
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}

private struct MaterialsPdfShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}

private extension Color {
    var luminance: Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }
}

private extension Array where Element: Hashable {
    func removingDuplicatesKeepingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

