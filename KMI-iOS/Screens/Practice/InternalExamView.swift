import SwiftUI
import Shared
import FirebaseAuth
import FirebaseFirestore

struct InternalExamView: View {
    let belt: Belt

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var coach = CoachService.shared
    @State private var currentBelt: Belt
    @State private var selectedExamBranch = ""
    @State private var selectedExamGroup = ""
    @State private var isSavingExamDraft = false
    @State private var isCheckingExamDraft = false
    @State private var showLegacyExamImport = false
    @State private var traineeName: String = ""
    @State private var isTypingNewTraineeName = false
    @State private var recentTrainees: [String] = []
    @State private var showPickTraineeDialog = false
    @State private var showResumeDialog = false

    @State private var pendingLoadedDraft: [String: Int] = [:]
    @State private var resumeCheckedKey: String? = nil
    @State private var hasUnsavedChanges = false
    @State private var showTraineeNameBox = true
    @State private var showExitDialog = false
    @State private var showExamActionAlert = false
    @State private var examActionMessage: String = ""
    @State private var shouldDismissAfterExamAction = false
    @State private var isSavingFinalResult = false
    @State private var hasStartedExam = false
    @State private var showExamArchiveSheet = false
    @State private var completedExamResults: [StoredCompletedInternalExamResult] = []
    @State private var isLoadingExamArchive = false

    @State private var examResultToDelete:
        StoredCompletedInternalExamResult? = nil

    @State private var isDeletingExamResult = false

    @State private var marksMap: [String: Int] = [:]
    @State private var expandedTopic: String? = nil
    @State private var expandedExamSubTopic: Int? = nil

    @State private var examShareItems: [Any] = []
    @State private var showExamShareSheet = false
    @State private var isCreatingExamPDF = false

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    init(belt: Belt) {
        self.belt = belt
        _currentBelt = State(initialValue: belt)
    }

    @State private var selectedSavedTraineeName: String? = nil

    private var shouldShowContinueExamButton: Bool {
        let name = traineeName.trimmed()

        let selectedFromList =
            !name.isEmpty &&
            selectedSavedTraineeName?.lowercased() == name.lowercased()

        return selectedFromList ||
            !marksMap.isEmpty ||
            !pendingLoadedDraft.isEmpty
    }
    
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

    private var examTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var examFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var examAssignments: [RegistrationFormState.BranchAssignment] {
        RegistrationFormState.BranchAssignmentsCodec.sanitized(
            auth.userBranchAssignments
        )
    }

    private var hasAuthoritativeExamAssignments: Bool {
        !examAssignments.isEmpty ||
        UserDefaults.standard.object(
            forKey: RegistrationFormState.BranchAssignmentsCodec.preferenceKey
        ) != nil
    }

    private var examBranches: [String] {
        if hasAuthoritativeExamAssignments {
            return examAssignments.map(\.branch)
        }

        let branch = auth.userBranch.trimmed()
        return branch.isEmpty ? [] : [branch]
    }

    private var examGroups: [String] {
        if hasAuthoritativeExamAssignments {
            return examAssignments.first {
                $0.branch == selectedExamBranch
            }?.groups ?? []
        }

        guard selectedExamBranch == auth.userBranch.trimmed() else {
            return []
        }

        let group = auth.userGroup.trimmed()
        return group.isEmpty ? [] : [group]
    }

    private var examScope: InternalExamScope? {
        guard let uid = internalExamCoachUid(),
              examBranches.contains(selectedExamBranch),
              examGroups.contains(selectedExamGroup) else {
            return nil
        }

        return InternalExamScope(
            coachUid: uid,
            branch: selectedExamBranch,
            group: selectedExamGroup
        )
    }

    private var examScopeIdentity: String {
        examScope?.cacheKey ?? "unselected"
    }

    private var examAssignmentsIdentity: String {
        let assignments = examAssignments.map {
            "\($0.branch):\($0.groups.joined(separator: "|"))"
        }
        .joined(separator: "||")

        return "\(internalExamCoachUid() ?? "")||\(auth.userRole)||\(assignments)||\(auth.userBranch)||\(auth.userGroup)"
    }

    private var isExamScopeBusy: Bool {
        isSavingFinalResult ||
        isCreatingExamPDF ||
        isSavingExamDraft ||
        isCheckingExamDraft
    }

    private var examScopeSelectors: some View {
        VStack(spacing: 12) {
            KmiPremiumDropdown(
                title: tr("סניף", "Branch"),
                options: examBranches,
                selectedValue: Binding(
                    get: { selectedExamBranch },
                    set: { branch in
                        guard branch != selectedExamBranch,
                              examBranches.contains(branch) else {
                            return
                        }

                        selectedExamBranch = branch

                        let groups = examGroups
                        selectedExamGroup = groups.count == 1
                            ? groups[0]
                            : ""
                    }
                ),
                placeholder: tr("בחר סניף", "Select a branch"),
                isEnglish: isEnglish,
                isEnabled: !isExamScopeBusy &&
                    marksMap.isEmpty &&
                    !hasUnsavedChanges,
                labelForOption: {
                    TrainingCatalogIOS.displayBranch(
                        $0,
                        isEnglish: isEnglish
                    )
                },
                titleInsideField: true
            )

            if examGroups.count > 1 {
                KmiPremiumDropdown(
                    title: tr("קבוצה", "Group"),
                    options: examGroups,
                    selectedValue: Binding(
                        get: { selectedExamGroup },
                        set: { group in
                            guard examGroups.contains(group) else {
                                return
                            }

                            selectedExamGroup = group
                        }
                    ),
                    placeholder: tr("בחר קבוצה", "Select a group"),
                    isEnglish: isEnglish,
                    isEnabled: !isExamScopeBusy &&
                        marksMap.isEmpty &&
                        !hasUnsavedChanges,
                    labelForOption: {
                        TrainingCatalogIOS.displayGroup(
                            $0,
                            isEnglish: isEnglish
                        )
                    },
                    titleInsideField: true
                )
            }

            if !selectedExamBranch.isEmpty && examGroups.isEmpty {
                Text(
                    tr(
                        "אין קבוצות משויכות למאמן בסניף זה.",
                        "No groups are assigned to the coach at this branch."
                    )
                )
                .kmiTypography(.secondary)
                .foregroundStyle(
                    KmiAppTheme.warning(for: colorScheme)
                )
            }
        }
    }

    private func initializeExamScope() {
        if !examBranches.contains(selectedExamBranch) {
            selectedExamBranch = examBranches.count == 1
                ? examBranches[0]
                : ""

            selectedExamGroup = ""
        }

        if !examGroups.contains(selectedExamGroup) {
            selectedExamGroup = examGroups.count == 1
                ? examGroups[0]
                : ""
        }
    }

    private func resetExamScopeState() {
        traineeName = ""
        marksMap.removeAll()
        pendingLoadedDraft.removeAll()
        resumeCheckedKey = nil
        expandedTopic = nil
        hasStartedExam = false
        hasUnsavedChanges = false
        showResumeDialog = false
        showLegacyExamImport = false
        showPickTraineeDialog = false
        showExamArchiveSheet = false
        examResultToDelete = nil
        completedExamResults.removeAll()
        showTraineeNameBox = true
        isTypingNewTraineeName = false
        isSavingExamDraft = false
        isCheckingExamDraft = false
        isSavingFinalResult = false
        isLoadingExamArchive = false
        isDeletingExamResult = false
        showExamShareSheet = false
        examShareItems.removeAll()
        recentTrainees = loadRecentTrainees()
        refreshExamRecentTrainees()
    }

    private func showExamScopeMessage(_ he: String, _ en: String) {
        examActionMessage = tr(he, en)
        shouldDismissAfterExamAction = false
        showExamActionAlert = true
    }

    private func loadRecentTrainees() -> [String] {
        guard let scope = examScope else {
            return []
        }

        return scopedLoadRecentTrainees(scope: scope)
    }

    private func refreshExamRecentTrainees() {
        guard let scope = examScope else {
            recentTrainees = []
            return
        }

        scopedFetchRecentTrainees(scope: scope) { result in
            DispatchQueue.main.async {
                guard examScope == scope,
                      internalExamCoachUid() == scope.coachUid else {
                    return
                }

                switch result {
                case .success(let names):
                    recentTrainees = names

                case .failure:
                    showExamScopeMessage(
                        "לא ניתן לעדכן את רשימת הנבחנים כרגע. הנתונים השמורים במכשיר נשארו זמינים.",
                        "The trainee list could not be refreshed. Locally cached entries remain available."
                    )
                }
            }
        }
    }

    private func pushRecentTrainee(_ name: String) {
        guard let scope = examScope else {
            return
        }

        scopedPushRecentTrainee(name, scope: scope)
        recentTrainees = scopedLoadRecentTrainees(scope: scope)
    }

    private func saveLastTrainee(_ name: String) {
        guard let scope = examScope else {
            return
        }

        scopedSaveLastTrainee(name, scope: scope)
    }

    private func draftKey(traineeName: String, belt: Belt) -> String {
        "\(examScopeIdentity)||\(belt.id)||\(traineeName.trimmed())"
    }

    private func saveExamDraft(
        traineeName: String,
        belt: Belt,
        marksMap: [String: Int],
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let scope = examScope else {
            completion?(false)
            return
        }

        scopedSaveExamDraft(
            traineeName: traineeName,
            belt: belt,
            marksMap: marksMap,
            scope: scope
        ) { success in
            DispatchQueue.main.async {
                guard examScope == scope,
                      internalExamCoachUid() == scope.coachUid else {
                    return
                }

                if let completion {
                    completion(success)
                } else if !success {
                    showExamScopeMessage(
                        "שמירת הטיוטה נכשלה. הציונים נשארו במסך; נסה שוב.",
                        "The draft could not be saved. Your scores remain on screen; please try again."
                    )
                }
            }
        }
    }

    private func saveCompletedExamResult(
        session: InternalExamSession,
        marksMap: [String: Int],
        completion: @escaping (Bool) -> Void
    ) {
        guard let scope = examScope else {
            completion(false)
            return
        }

        scopedSaveCompletedExamResult(
            session: session,
            marksMap: marksMap,
            scope: scope
        ) { success in
            DispatchQueue.main.async {
                guard examScope == scope,
                      internalExamCoachUid() == scope.coachUid else {
                    return
                }

                completion(success)
            }
        }
    }

    private func removeExamDraft(traineeName: String, belt: Belt) {
        guard let scope = examScope else {
            return
        }

        scopedRemoveExamDraft(
            traineeName: traineeName,
            belt: belt,
            scope: scope
        )
    }

    private func removeRecentTraineeAfterCompletion(_ name: String) {
        guard let scope = examScope else {
            return
        }

        scopedRemoveRecentTraineeAfterCompletion(name, scope: scope)
        recentTrainees = scopedLoadRecentTrainees(scope: scope)
    }

    private func importLegacyExamDraft() {
        guard let scope = examScope else {
            return
        }

        let name = traineeName.trimmed()
        let selectedBelt = currentBelt
        let importedMarks = pendingLoadedDraft

        isSavingExamDraft = true

        scopedSaveExamDraft(
            traineeName: name,
            belt: selectedBelt,
            marksMap: importedMarks,
            scope: scope
        ) { success in
            DispatchQueue.main.async {
                guard examScope == scope,
                      traineeName.trimmed() == name,
                      currentBelt.id == selectedBelt.id else {
                    return
                }

                isSavingExamDraft = false

                guard success else {
                    showExamScopeMessage(
                        "ייבוא הטיוטה נכשל. הטיוטה המקורית לא שונתה.",
                        "The draft could not be imported. The original draft was not changed."
                    )

                    resumeCheckedKey = nil
                    return
                }

                continueSavedExamFromPrompt()
            }
        }
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var examPanelColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var examFieldColor: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var examPrimaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var examSecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var examPanelBorderColor: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var examFieldBorderColor: Color {
        KmiAppTheme.outline(for: colorScheme)
    }

    private func beltNameForUi(_ belt: Belt) -> String {
        guard isEnglish else {
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

    var body: some View {
        Group {
            if coach.isLoading {
                ZStack {
                    androidExamBackground

                    KmiLoadingOverlay()
                }
            } else if coach.isCoach {
                examContent
            } else {
                ZStack {
                    androidExamBackground

                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .kmiIconSize(32)
                            .foregroundStyle(
                                KmiAppTheme.warning(for: colorScheme)
                            )

                        Text(
                            tr(
                                "גישה למאמנים בלבד",
                                "Coach access only"
                            )
                        )
                        .kmiTypography(.sectionTitle)
                        .fontWeight(.black)
                        .foregroundStyle(examPrimaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        .multilineTextAlignment(.center)

                        Text(
                            tr(
                                "ההרשאה נקבעת בשרת לפי מספר הטלפון של המשתמש.",
                                "Permission is determined on the server using the user's phone number."
                            )
                        )
                        .kmiTypography(.secondary)
                        .foregroundStyle(examSecondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(examPanelColor)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .stroke(
                            examPanelBorderColor,
                            lineWidth: 1
                        )
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .overlay {
            if coach.isCoach &&
                !coach.isLoading &&
                (isSavingExamDraft ||
                 isCheckingExamDraft ||
                 isSavingFinalResult) {
                KmiLoadingOverlay()
            }
        }
        .task(id: examAssignmentsIdentity) {
            await coach.checkCoach(userRole: auth.userRole)

            guard !Task.isCancelled else {
                return
            }

            guard coach.isCoach else {
                resetExamScopeState()
                return
            }

            let previousScope = examScopeIdentity
            initializeExamScope()

            if examScopeIdentity == previousScope {
                refreshExamRecentTrainees()
            }
        }
        .onChange(of: examScopeIdentity) { _, _ in
            resetExamScopeState()
        }
        .alert(
            tr("ייבוא טיוטה קודמת", "Import previous draft"),
            isPresented: $showLegacyExamImport
        ) {
            Button(tr("ייבא והמשך", "Import and resume")) {
                importLegacyExamDraft()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) {
                pendingLoadedDraft.removeAll()
                resumeCheckedKey = nil
            }
        } message: {
            Text(
                tr(
                    "נמצאה טיוטה ישנה ללא שיוך לסניף וקבוצה. לייבא עותק ל־\(selectedExamBranch) / \(selectedExamGroup)? הטיוטה המקורית תישאר ללא שינוי.",
                    "An old draft has no branch or group. Import a copy into \(selectedExamBranch) / \(selectedExamGroup)? The original will remain unchanged."
                )
            )
        }
        .onChange(of: traineeName) { _, newValue in
            let name = newValue.trimmed()

            if name.isEmpty ||
                selectedSavedTraineeName?.lowercased() != name.lowercased() {
                selectedSavedTraineeName = nil
            }

            recentTrainees = loadRecentTrainees()
        }
        .onChange(of: expandedTopic) { _, _ in
            expandedExamSubTopic = nil
        }
        .onChange(of: currentBelt) { _, _ in
            expandedTopic = nil
            expandedExamSubTopic = nil
            pendingLoadedDraft.removeAll()
            resumeCheckedKey = nil
            isCheckingExamDraft = false
            checkForDraft()
        }

        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)

        .sheet(isPresented: $showPickTraineeDialog) {
            traineePickerSheet
                .environment(\.layoutDirection, screenLayoutDirection)
        }
        
        .sheet(isPresented: $showExamArchiveSheet) {
            examArchiveSheet
                .environment(
                    \.layoutDirection,
                    screenLayoutDirection
                )
        }

        .sheet(isPresented: $showExamShareSheet) {
            KmiShareSheet(items: examShareItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }

        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard
                let request =
                    notification.object as? NSMutableDictionary
            else {
                return
            }

            request["handled"] = true

            if marksMap.isEmpty {
                examActionMessage = tr(
                    "אין עדיין ציונים לשיתוף. יש לבחור לפחות ציון אחד.",
                    "There are no scores to share yet. Choose at least one score."
                )
                shouldDismissAfterExamAction = false
                showExamActionAlert = true
            } else {
                exportPdf()
            }
        }

        .alert(
            tr("שמירת טיוטה", "Save draft"),
            isPresented: $showExitDialog
        ) {

            Button(tr("שמור טיוטה", "Save draft")) {
                saveDraftFromAndroidPanel(shouldExit: true)
            }

            Button(tr("צא בלי לשמור", "Exit without saving"), role: .destructive) {
                dismiss()
            }

            Button(tr("ביטול", "Cancel"), role: .cancel) { }

        } message: {
            Text(tr(
                "האם לשמור טיוטה לפני היציאה?",
                "Save a draft before exiting?"
            ))
        }
        .alert(
            tr(
                "מבחן פנימי",
                "Internal Exam"
            ),
            isPresented: $showExamActionAlert
        ) {
            Button(
                tr(
                    "אישור",
                    "OK"
                )
            ) {
                if shouldDismissAfterExamAction {
                    dismiss()
                }
            }
        } message: {
            Text(examActionMessage)
        }
        .alert(
            tr(
                "מחיקת מבחן מההיסטוריה",
                "Delete Exam from History"
            ),
            isPresented: Binding(
                get: {
                    examResultToDelete != nil
                },
                set: { isPresented in
                    if !isPresented &&
                        !isDeletingExamResult {
                        examResultToDelete = nil
                    }
                }
            )
        ) {
            Button(
                isDeletingExamResult
                    ? tr(
                        "מוחק…",
                        "Deleting…"
                    )
                    : tr(
                        "מחק",
                        "Delete"
                    ),
                role: .destructive
            ) {
                guard
                    let result =
                        examResultToDelete
                else {
                    return
                }

                deleteCompletedExamResult(
                    result
                )
            }
            .disabled(isDeletingExamResult)

            Button(
                tr(
                    "ביטול",
                    "Cancel"
                ),
                role: .cancel
            ) {
                examResultToDelete = nil
            }
            .disabled(isDeletingExamResult)

        } message: {
            if let result = examResultToDelete {
                Text(
                    tr(
                        "האם למחוק את המבחן של \"\(result.traineeName)\" מהיסטוריית המבחנים?\nהמחיקה סופית ולא תשפיע על מבחנים אחרים.",
                        "Delete \"\(result.traineeName)\" from the exam history?\nThis action is final and will not affect other exams."
                    )
                )
            }
        }
    }

    private func loadCompletedInternalExamResultsFromFirestore(
        completion: @escaping (
            Result<[StoredCompletedInternalExamResult], Error>
        ) -> Void
    ) {
        guard let scope = examScope else {
            completion(.failure(InternalExamScopeError.invalidScope))
            return
        }

        Firestore.firestore()
            .collection(InternalExamStore.completedResultsCollection)
            .whereField("coachUid", isEqualTo: scope.coachUid)
            .getDocuments { snapshot, error in
                guard scope.isCurrentUser else {
                    completion(
                        .failure(InternalExamScopeError.accountChanged)
                    )
                    return
                }

                if let error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(
                        .failure(InternalExamScopeError.invalidScope)
                    )
                    return
                }

                let results: [StoredCompletedInternalExamResult] = documents.compactMap { doc in
                    let data = doc.data()

                    let legacy =
                        (data["branch"] as? String ?? "").trimmed().isEmpty &&
                        (data["group"] as? String ?? "").trimmed().isEmpty

                    guard scope.matches(data) || legacy else {
                        return nil
                    }

                    let status = (data["status"] as? String) ?? InternalExamStore.completedStatus
                    guard status == InternalExamStore.completedStatus else {
                        return nil
                    }

                    let traineeName = ((data["traineeName"] as? String) ?? "").trimmed()
                    guard !traineeName.isEmpty else {
                        return nil
                    }

                    let answeredExercisesRaw = data["answeredExercises"] as? [[String: Any]] ?? []

                    let answeredExercises: [StoredCompletedInternalExamExercise] = answeredExercisesRaw.compactMap { raw in
                        let exerciseId = ((raw["exerciseId"] as? String) ?? UUID().uuidString).trimmed()
                        let beltId = ((raw["belt"] as? String) ?? (raw["beltId"] as? String) ?? "").trimmed()
                        let beltHeb = ((raw["beltHeb"] as? String) ?? "").trimmed()
                        let beltEn = ((raw["beltEn"] as? String) ?? "").trimmed()
                        let topic = ((raw["topic"] as? String) ?? "—").trimmed()
                        let subTopic = ((raw["subTopic"] as? String) ?? "").trimmed()
                        let name = ((raw["name"] as? String) ?? "—").trimmed()

                        let rawScore = raw["score"]
                        let score: Int

                        if let value = rawScore as? Int {
                            score = clampScore10(value)
                        } else if let value = rawScore as? Double {
                            score = clampScore10(Int(value))
                        } else if let value = rawScore as? NSNumber {
                            score = clampScore10(value.intValue)
                        } else {
                            score = 0
                        }

                        return StoredCompletedInternalExamExercise(
                            exerciseId: exerciseId,
                            beltId: beltId,
                            beltHeb: beltHeb,
                            beltEn: beltEn,
                            topic: topic,
                            subTopic: subTopic,
                            name: name,
                            score: score
                        )
                    }

                    let percent: Int
                    if let value = data["percent"] as? Int {
                        percent = value
                    } else if let value = data["percent"] as? Double {
                        percent = Int(value)
                    } else if let value = data["percent"] as? NSNumber {
                        percent = value.intValue
                    } else {
                        percent = 0
                    }

                    let score10: Double
                    if let value = data["score10"] as? Double {
                        score10 = value
                    } else if let value = data["score10"] as? NSNumber {
                        score10 = value.doubleValue
                    } else {
                        score10 = 0
                    }

                    let totalScore: Double
                    if let value = data["totalScore"] as? Double {
                        totalScore = value
                    } else if let value = data["totalScore"] as? NSNumber {
                        totalScore = value.doubleValue
                    } else {
                        totalScore = 0
                    }

                    let maxScore: Double
                    if let value = data["maxScore"] as? Double {
                        maxScore = value
                    } else if let value = data["maxScore"] as? NSNumber {
                        maxScore = value.doubleValue
                    } else {
                        maxScore = 0
                    }

                    let completedAtMillis: Int64
                    if let value = data["completedAtMillis"] as? Int64 {
                        completedAtMillis = value
                    } else if let value = data["completedAtMillis"] as? Int {
                        completedAtMillis = Int64(value)
                    } else if let value = data["completedAtMillis"] as? Double {
                        completedAtMillis = Int64(value)
                    } else if let value = data["completedAtMillis"] as? NSNumber {
                        completedAtMillis = value.int64Value
                    } else {
                        completedAtMillis = 0
                    }

                    let beltId = ((data["belt"] as? String) ?? "").trimmed()
                    let beltHeb = ((data["beltHeb"] as? String) ?? "").trimmed()
                    let beltEn = ((data["beltEn"] as? String) ?? "").trimmed()

                    return StoredCompletedInternalExamResult(
                        resultId: doc.documentID,
                        traineeName: traineeName,
                        traineeKey: ((data["traineeKey"] as? String) ?? "").trimmed(),
                        beltId: beltId,
                        beltHeb: beltHeb.isEmpty ? beltId : beltHeb,
                        beltEn: beltEn.isEmpty ? beltId : beltEn,
                        completedAtMillis: completedAtMillis,
                        totalScore: totalScore,
                        maxScore: maxScore,
                        score10: score10,
                        percent: percent,
                        summaryTextHe: ((data["summaryTextHe"] as? String) ?? examStatusText(percent: percent, isEnglish: false)).trimmed(),
                        summaryTextEn: ((data["summaryTextEn"] as? String) ?? examStatusText(percent: percent, isEnglish: true)).trimmed(),
                        shareSummaryHe: ((data["shareSummaryHe"] as? String) ?? "").trimmed(),
                        shareSummaryEn: ((data["shareSummaryEn"] as? String) ?? "").trimmed(),
                        answeredExercises: answeredExercises,
                        branch: data["branch"] as? String,
                        group: data["group"] as? String
                    )
                }
                .sorted { $0.completedAtMillis > $1.completedAtMillis }

                completion(.success(results))
            }
    }
    
    // MARK: - Main Content

    private var examContent: some View {
        ZStack {
            if hasStartedExam {
                examBeltBackground
            } else {
                androidExamBackground
            }

            VStack(spacing: 10) {
                if hasStartedExam {
                    activeExamContent
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            androidPreStartHint
                                .padding(.top, 10)

                            androidStartCard

                            androidArchiveButton
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }

            if showResumeDialog {
                androidSavedExamOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(20)
            }
        }
    }
    
    private var androidExamBackground: some View {
        KmiAppBackground()
    }

    private var androidSavedExamOverlay: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(examFieldColor)
                        .frame(width: 66, height: 66)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color(
                                        red: 0.486,
                                        green: 0.302,
                                        blue: 1.000
                                    )
                                    .opacity(0.38),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(
                                isDarkMode ? 0.34 : 0.18
                            ),
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                    Image(systemName: "externaldrive.fill")
                        .kmiFont(
                            size: 30,
                            weight: .black
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.486,
                                green: 0.302,
                                blue: 1.000
                            )
                        )
                }

                Text(
                    tr(
                        "מבחן שמור נמצא",
                        "Saved exam found"
                    )
                )
                .kmiFont(
                    size: 25,
                    weight: .black
                )
                .foregroundStyle(examPrimaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

                Text(
                    tr(
                        "נמצא מבחן שמור מהפעם האחרונה.\nלהמשיך ממנו או להתחיל מבחן חדש?",
                        "A saved exam was found from the last session.\nContinue from it or start a new exam?"
                    )
                )
                .kmiFont(
                    size: 16,
                    weight: .semibold
                )
                .foregroundStyle(examSecondaryTextColor)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                HStack(spacing: 12) {
                    Button {
                        startNewExamFromSavedPrompt()
                    } label: {
                        Text(
                            tr(
                                "מבחן חדש",
                                "New Exam"
                            )
                        )
                        .kmiFont(
                            size: 16,
                            weight: .black
                        )
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(
                                        red: 0.05,
                                        green: 0.72,
                                        blue: 0.95
                                    ),
                                    Color(
                                        red: 0.42,
                                        green: 0.22,
                                        blue: 0.95
                                    )
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        continueSavedExamFromPrompt()
                    } label: {
                        HStack(spacing: 7) {
                            Text(
                                tr(
                                    "המשך",
                                    "Continue"
                                )
                            )
                            .kmiFont(
                                size: 16,
                                weight: .black
                            )

                            Image(
                                systemName:
                                    isEnglish
                                    ? "chevron.right"
                                    : "chevron.left"
                            )
                            .kmiFont(
                                size: 12,
                                weight: .black
                            )
                        }
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(
                                        red: 0.35,
                                        green: 0.22,
                                        blue: 0.93
                                    ),
                                    Color(
                                        red: 0.69,
                                        green: 0.17,
                                        blue: 0.93
                                    )
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .environment(
                    \.layoutDirection,
                    isEnglish
                        ? .leftToRight
                        : .rightToLeft
                )
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(examPanelColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    examPanelBorderColor,
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.38 : 0.24
                ),
                radius: 18,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 18)
        }
    }
    
    private var androidPreStartHint: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(KmiAppTheme.primary(for: colorScheme).opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                KmiAppTheme.primary(for: colorScheme).opacity(0.44),
                                lineWidth: 2
                            )
                    }
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(45))

                Circle()
                    .fill(KmiAppTheme.primaryContainer(for: colorScheme))
                    .overlay {
                        Circle()
                            .stroke(
                                KmiAppTheme.primary(for: colorScheme).opacity(0.48),
                                lineWidth: 1
                            )
                    }
                    .frame(width: 46, height: 46)

                Image(systemName: "star.fill")
                    .kmiIconSize(22)
                    .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
            }
            .frame(height: 78)
            .accessibilityHidden(true)

            Text(tr(
                "בחר נבחן וחגורה לפני תחילת המבחן",
                "Select a trainee and belt before starting"
            ))
            .kmiTypography(.secondary)
            .fontWeight(.semibold)
            .foregroundStyle(examSecondaryTextColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            examPanelColor,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(examPanelBorderColor, lineWidth: 0.75)
        }
    }

    private var androidStartCard: some View {
        VStack(spacing: 14) {
            androidNameField
                .disabled(examScope == nil || isExamScopeBusy)

            examScopeSelectors
            androidBeltPicker

            Divider()
                .overlay(examPanelBorderColor)

            examEntryMetaRow
            androidStartButton
            androidSaveShareRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            examPanelColor,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(examPanelBorderColor, lineWidth: 0.75)
        }
    }

    private var examEntryMetaRow: some View {
        HStack(alignment: .top, spacing: 8) {
            examEntryMetaItem(
                icon: "square.stack",
                title: tr(
                    "\(examItemsForCurrentBelt.count) שאלות",
                    "\(examItemsForCurrentBelt.count) questions"
                )
            )

            examEntryMetaItem(
                icon: "clock",
                title: tr("ללא הגבלת זמן", "No time limit")
            )

            VStack(spacing: 7) {
                androidBeltImage
                    .scaleEffect(0.40)
                    .frame(width: 42, height: 34)
                    .accessibilityHidden(true)

                Text(examBeltNameForUi(currentBelt, isEnglish: isEnglish))
                    .kmiTypography(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(examPrimaryTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    private func examEntryMetaItem(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .kmiIconSize(15)
                .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
                .frame(width: 34, height: 34)
                .background(
                    KmiAppTheme.primaryContainer(for: colorScheme).opacity(0.50),
                    in: Circle()
                )
                .accessibilityHidden(true)

            Text(title)
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(examPrimaryTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var androidNameField: some View {
        Group {
            if isTypingNewTraineeName {
                HStack(spacing: 10) {
                    Button {
                        _ = commitTraineeNameAndCollapse()
                        isTypingNewTraineeName = false
                    } label: {
                        Text(
                            tr(
                                "אישור",
                                "OK"
                            )
                        )
                        .kmiFont(
                            size: 15,
                            weight: .black
                        )
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.40, green: 0.22, blue: 0.92),
                                        Color(red: 0.10, green: 0.62, blue: 0.92)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(traineeName.trimmed().isEmpty)

                    TextField(
                        tr(
                            "שם הנבחן",
                            "Trainee name"
                        ),
                        text: $traineeName
                    )
                    .kmiTypography(.body)
                    .fontWeight(.heavy)
                    .foregroundStyle(examPrimaryTextColor)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                        .onSubmit {
                            _ = commitTraineeNameAndCollapse()
                            isTypingNewTraineeName = false
                        }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 66)
                .background(examFieldColor)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        examFieldBorderColor,
                        lineWidth: 1.2
                    )
                )
                .environment(
                    \.layoutDirection,
                    isEnglish
                        ? .leftToRight
                        : .rightToLeft
                )

            } else {
                Menu {
                    Button {
                        traineeName = ""
                        marksMap.removeAll()
                        pendingLoadedDraft.removeAll()
                        resumeCheckedKey = nil
                        showTraineeNameBox = true
                        isTypingNewTraineeName = true
                    } label: {
                        Text(tr("נבחן חדש…", "New trainee…"))
                    }

                    if !recentTrainees.isEmpty {
                        Divider()
                    }

                    ForEach(recentTrainees, id: \.self) { name in
                        Button {
                            let cleanName = name.trimmed()

                            selectedSavedTraineeName = cleanName
                            traineeName = cleanName
                            showTraineeNameBox = false
                            isTypingNewTraineeName = false

                            marksMap.removeAll()
                            pendingLoadedDraft.removeAll()
                            resumeCheckedKey = nil

                            pushRecentTrainee(cleanName)
                            saveLastTrainee(cleanName)
                            checkForDraft()
                        } label: {
                            Text(cleanNameForMenu(name))
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.down")
                            .kmiFont(
                                size: 12,
                                weight: .black
                            )
                            .foregroundStyle(
                                examSecondaryTextColor
                            )

                        Text(
                            traineeName.trimmed().isEmpty
                                ? tr(
                                    "בחר נבחן מתוך הרשימה",
                                    "Select a trainee from the list"
                                )
                                : traineeName.trimmed()
                        )
                        .kmiFont(
                            size: 19,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            traineeName.trimmed().isEmpty
                                ? examSecondaryTextColor
                                : (
                                    isDarkMode
                                        ? Color(
                                            red: 1.00,
                                            green: 0.82,
                                            blue: 0.38
                                        )
                                        : Color(
                                            red: 0.56,
                                            green: 0.38,
                                            blue: 0.18
                                        )
                                )
                        )
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 66)
                    .background(examFieldColor)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                        .stroke(
                            examFieldBorderColor,
                            lineWidth: 1.2
                        )
                    )
                }
                .buttonStyle(.plain)
                .onAppear {
                    recentTrainees = loadRecentTrainees()
                }
            }
        }
    }
    
    private func cleanNameForMenu(_ name: String) -> String {
        let clean = name.trimmed()
        return clean.isEmpty ? "—" : clean
    }
    
    private var androidBeltPicker: some View {
        let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

        return KmiPremiumDropdown(
            title: tr("חגורה נבחרת", "Selected belt"),
            options: belts.map(\.id),
            selectedValue: Binding(
                get: { currentBelt.id },
                set: { id in
                    guard let picked = belts.first(where: { $0.id == id }),
                          picked.id != currentBelt.id else { return }

                    currentBelt = picked
                    expandedTopic = nil
                    pendingLoadedDraft.removeAll()
                    resumeCheckedKey = nil
                    checkForDraft()
                }
            ),
            placeholder: tr("בחר חגורה", "Select a belt"),
            isEnglish: isEnglish,
            isEnabled: !isSavingFinalResult && !isCreatingExamPDF,
            labelForOption: { id in
                guard let picked = belts.first(where: { $0.id == id }) else { return id }
                return examBeltNameForUi(picked, isEnglish: isEnglish)
            },
            titleInsideField: true
        )
    }

    @ViewBuilder
    private var androidBeltImage: some View {
        if let image = UIImage(named: androidBeltImageName(for: currentBelt)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 58)
                .rotationEffect(.degrees(-7))
                .shadow(
                    color: Color.black.opacity(0.10),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        } else {
            Image(systemName: "rosette")
                .kmiIconSize(42)
                .foregroundStyle(
                    beltAccentColor(for: currentBelt)
                )
                .frame(width: 98, height: 58)
        }
    }

    private func androidBeltImageName(for belt: Belt) -> String {
        switch belt {
        case .white:
            return "belt_white"
        case .yellow:
            return "belt_yellow"
        case .orange:
            return "belt_orange"
        case .green:
            return "belt_green"
        case .blue:
            return "belt_blue"
        case .brown:
            return "belt_brown"
        case .black:
            return "belt_black"
        default:
            return "belt_black"
        }
    }

    private var androidStartButton: some View {
        Button {
            startExamFromAndroidPanel()
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName:
                        shouldShowContinueExamButton
                        ? "forward.fill"
                        : "play.fill"
                )
                .kmiIconSize(17)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.16), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                }
                .accessibilityHidden(true)

                Text(
                    shouldShowContinueExamButton
                        ? tr("המשך מבחן", "Continue exam")
                        : tr("התחל מבחן", "Start exam")
                )
                .kmiTypography(.sectionTitle)
                .fontWeight(.black)
                .multilineTextAlignment(.center)
            }
            .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [
                        KmiAppTheme.primary(for: colorScheme),
                        KmiBeltPalette.color(for: .yellow)
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.5),
                    endPoint: UnitPoint(x: 1, y: 0.5)
                )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(examScope == nil || isExamScopeBusy)
    }
    
    private var androidSaveShareRow: some View {
        Button {
            saveDraftFromAndroidPanel()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "bookmark")
                    .kmiIconSize(17)
                    .accessibilityHidden(true)

                Text(tr("שמור מבחן", "Save exam"))
                    .kmiTypography(.action)
                    .fontWeight(.bold)
            }
            .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: .dark))
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, 3)
            .background(
                KmiAppTheme.tertiaryContainer(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        KmiAppTheme.primary(for: .dark),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(examScope == nil || isExamScopeBusy)
    }

    private var androidArchiveButton: some View {
        Button {
            openCompletedExamArchive()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.forward")
                    .kmiIconSize(14)
                    .accessibilityHidden(true)

                Text(tr("ארכיון מבחנים", "Exam archive"))
                    .kmiTypography(.sectionTitle)
                    .fontWeight(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "books.vertical.fill")
                    .kmiIconSize(22)
                    .frame(width: 40, height: 40)
                    .background(
                        KmiAppTheme.secondaryContainer(for: .dark),
                        in: Circle()
                    )
                    .accessibilityHidden(true)
            }
            .foregroundStyle(
                KmiAppTheme.onTertiaryContainer(for: colorScheme)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                KmiAppTheme.tertiaryContainer(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        KmiAppTheme.primary(for: .dark).opacity(0.75),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(
            examScope == nil ||
            isLoadingExamArchive ||
            isExamScopeBusy
        )
    }
    
    private func examSubTopicGroups(
        for group: ExamTopicGroup
    ) -> [ExamTopicGroup] {
        var groups: [ExamTopicGroup] = []
        var directItems: [ExamExerciseItem] = []

        for item in group.items {
            let title = (item.subTopic ?? "").trimmed()

            guard !title.isEmpty, title != group.topic else {
                directItems.append(item)
                continue
            }

            if let index = groups.firstIndex(
                where: { $0.topic == title }
            ) {
                let previous = groups[index]

                groups[index] = ExamTopicGroup(
                    topic: title,
                    items: previous.items + [item]
                )
            } else {
                groups.append(
                    ExamTopicGroup(
                        topic: title,
                        items: [item]
                    )
                )
            }
        }

        guard !groups.isEmpty else {
            return []
        }

        if !directItems.isEmpty {
            groups.append(
                ExamTopicGroup(
                    topic: tr(
                        "תרגילים כלליים",
                        "General exercises"
                    ),
                    items: directItems
                )
            )
        }

        return groups
    }

    private func examTopicChildren(
        _ group: ExamTopicGroup
    ) -> some View {
        let subGroups = examSubTopicGroups(for: group)

        return VStack(spacing: 8) {
            if subGroups.isEmpty {
                examExerciseRows(group.items)
            } else {
                ForEach(
                    Array(subGroups.enumerated()),
                    id: \.offset
                ) { index, subGroup in
                    TopicHeaderView(
                        title: examTitleForUi(
                            subGroup.topic,
                            isEnglish: isEnglish
                        ),
                        expanded: expandedExamSubTopic == index,
                        exerciseCount: subGroup.items.count,
                        isEnglish: isEnglish,
                        isDarkMode: isDarkMode,
                        belt: currentBelt
                    ) {
                        withAnimation(
                            .easeInOut(duration: 0.20)
                        ) {
                            expandedExamSubTopic =
                                expandedExamSubTopic == index
                                ? nil
                                : index
                        }
                    }
                    .padding(.horizontal, 10)

                    if expandedExamSubTopic == index {
                        examExerciseRows(subGroup.items)
                    }
                }
            }
        }
    }

    private func examExerciseRows(
        _ items: [ExamExerciseItem]
    ) -> some View {
        ForEach(items) { item in
            ExerciseRowView(
                name: examTitleForUi(
                    item.name,
                    isEnglish: isEnglish
                ),
                score: marksMap[item.id],
                isEnglish: isEnglish,
                isDarkMode: isDarkMode,
                belt: currentBelt,
                onScoreChange: { newScore in
                    hasUnsavedChanges = true

                    if let newScore {
                        marksMap[item.id] = clampScore10(newScore)
                    } else {
                        marksMap.removeValue(forKey: item.id)
                    }

                    let cleanName = traineeName.trimmed()

                    if !cleanName.isEmpty {
                        saveExamDraft(
                            traineeName: cleanName,
                            belt: currentBelt,
                            marksMap: marksMap
                        )

                        pushRecentTrainee(cleanName)
                        saveLastTrainee(cleanName)
                    }
                }
            )
            .padding(.horizontal, 10)
        }
    }

    private var activeExamContent: some View {
        VStack(spacing: 8) {
            androidActiveExamHeader
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    SummaryCardView(
                        currentBelt: currentBelt,
                        marksMap: marksMap,
                        isEnglish: isEnglish,
                        isDarkMode: isDarkMode,
                        itemsProvider: { belt in
                            examItems(for: belt)
                        }
                    )

                    ForEach(
                        groupedTopics,
                        id: \.topic
                    ) { group in
                        TopicHeaderView(
                            title: examTitleForUi(
                                group.topic,
                                isEnglish: isEnglish
                            ),
                            expanded:
                                expandedTopic == group.topic,
                            exerciseCount: group.items.count,
                            isEnglish: isEnglish,
                            isDarkMode: isDarkMode,
                            belt: currentBelt
                        ) {
                            withAnimation(
                                .easeInOut(duration: 0.20)
                            ) {
                                expandedTopic =
                                    expandedTopic == group.topic
                                    ? nil
                                    : group.topic
                            }
                        }

                        if expandedTopic == group.topic {
                            examTopicChildren(group)
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }

            BottomActionBarView(
                session: session,
                isEnglish: isEnglish,
                onSave: saveCurrentExam,
                onChangeBelt: {
                    withAnimation(
                        .easeInOut(duration: 0.22)
                    ) {
                        hasStartedExam = false
                    }
                }
            )
            .contextMenu {
                Button(
                    tr(
                        "ייצוא PDF",
                        "Export PDF"
                    )
                ) {
                    exportPdf()
                }
            }
        }
    }
 
    private var androidActiveExamHeader: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(
                    .easeInOut(duration: 0.20)
                ) {
                    hasStartedExam = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .kmiIconSize(13)
                    .foregroundStyle(
                        beltAccentColor(for: currentBelt)
                    )
                    .frame(width: 36, height: 36)
                    .background(examFieldColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                beltAccentColor(
                                    for: currentBelt
                                )
                                .opacity(0.38),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                tr(
                    "חזרה לבחירת נבחן וחגורה",
                    "Return to trainee and belt selection"
                )
            )

            VStack(
                alignment:
                    isEnglish ? .leading : .trailing,
                spacing: 3
            ) {
                Text(
                    traineeName.trimmed().isEmpty
                        ? tr(
                            "מבחן פנימי",
                            "Internal Exam"
                        )
                        : traineeName.trimmed()
                )
                .kmiTypography(.cardTitle)
                .fontWeight(.black)
                .foregroundStyle(examPrimaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish ? .leading : .trailing
                )

                Text(
                    tr(
                        "חגורה: \(examBeltNameForUi(currentBelt, isEnglish: false))",
                        "Belt: \(examBeltNameForUi(currentBelt, isEnglish: true))"
                    )
                )
                .kmiTypography(.caption)
                .fontWeight(.bold)
                .foregroundStyle(
                    beltAccentColor(for: currentBelt)
                )
                .lineLimit(1)
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish ? .leading : .trailing
                )
            }

            androidBeltImage
                .frame(width: 72, height: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(examPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                beltAccentColor(for: currentBelt)
                    .opacity(0.38),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.30 : 0.14
            ),
            radius: 7,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 12)
    }
    
    private var examBeltBackground: some View {
        KmiAppBackground()
    }

    private var traineeHeaderSection: some View {
        VStack(spacing: 6) {
            if showTraineeNameBox {
                HStack(spacing: 10) {
                    if isEnglish {
                        TextField(tr("שם הנבחן", "Trainee name"), text: $traineeName)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                            .environment(\.layoutDirection, .leftToRight)
                            .submitLabel(.done)
                            .onSubmit {
                                _ = commitTraineeNameAndCollapse()
                            }

                        Button(tr("אישור", "OK")) {
                            _ = commitTraineeNameAndCollapse()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(traineeName.trimmed().isEmpty)
                    } else {
                        Button(tr("אישור", "OK")) {
                            _ = commitTraineeNameAndCollapse()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(traineeName.trimmed().isEmpty)

                        TextField(tr("שם הנבחן", "Trainee name"), text: $traineeName)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                            .submitLabel(.done)
                            .onSubmit {
                                _ = commitTraineeNameAndCollapse()
                            }
                    }
                }
                .padding(10)
                .background(Color(red: 0.88, green: 0.95, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            } else if !traineeName.trimmed().isEmpty {
                HStack(spacing: 8) {
                    if isEnglish {
                        Text(traineeName.trimmed())
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(tr("החלף", "Change")) {
                            recentTrainees = loadRecentTrainees()
                            showPickTraineeDialog = true
                        }
                        .buttonStyle(.bordered)

                        Button(tr("חדש", "New")) {
                            marksMap.removeAll()
                            traineeName = ""
                            showTraineeNameBox = true
                            resumeCheckedKey = nil
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(tr("חדש", "New")) {
                            marksMap.removeAll()
                            traineeName = ""
                            showTraineeNameBox = true
                            resumeCheckedKey = nil
                        }
                        .buttonStyle(.bordered)

                        Button(tr("החלף", "Change")) {
                            recentTrainees = loadRecentTrainees()
                            showPickTraineeDialog = true
                        }
                        .buttonStyle(.bordered)

                        Text(traineeName.trimmed())
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.88, green: 0.95, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
        }
    }

    private var examArchiveSheet: some View {
        NavigationStack {
            ZStack {
                KmiAppBackground()

                if isLoadingExamArchive {
                    KmiLoadingOverlay()
                } else if completedExamResults.isEmpty {
                    VStack(spacing: 14) {
                        Image(
                            systemName:
                                "doc.text.magnifyingglass"
                        )
                        .kmiFont(
                            size: 42,
                            weight: .bold
                        )
                        .foregroundStyle(
                            Color(
                                red: 0.486,
                                green: 0.302,
                                blue: 1.000
                            )
                        )

                        Text(
                            tr(
                                "אין מבחנים שמורים עדיין.",
                                "No completed exams yet."
                            )
                        )
                        .kmiFont(
                            size: 18,
                            weight: .black
                        )
                        .foregroundStyle(
                            examPrimaryTextColor
                        )
                        .multilineTextAlignment(.center)

                        Text(
                            tr(
                                "לאחר סיום מבחן הוא יופיע כאן עם תאריך הסיום.",
                                "After finishing an exam, it will appear here with its completion date."
                            )
                        )
                        .kmiFont(
                            size: 14,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            examSecondaryTextColor
                        )
                        .multilineTextAlignment(.center)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 26)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(examPanelColor)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .stroke(
                            examPanelBorderColor,
                            lineWidth: 1
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(
                            isDarkMode ? 0.32 : 0.12
                        ),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
                    .padding(.horizontal, 20)

                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(
                                completedExamResults,
                                id: \.resultId
                            ) { result in
                                NavigationLink {
                                    completedExamDetailView(
                                        result
                                    )
                                } label: {
                                    completedExamArchiveRow(
                                        result
                                    )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(
                                    edge:
                                        isEnglish
                                        ? .trailing
                                        : .leading,
                                    allowsFullSwipe: false
                                ) {
                                    Button(
                                        role: .destructive
                                    ) {
                                        examResultToDelete =
                                            result
                                    } label: {
                                        Label(
                                            tr(
                                                "מחק",
                                                "Delete"
                                            ),
                                            systemImage: "trash"
                                        )
                                    }
                                    .tint(.red)
                                }
                                .contextMenu {
                                    Button(
                                        role: .destructive
                                    ) {
                                        examResultToDelete =
                                            result
                                    } label: {
                                        Label(
                                            tr(
                                                "מחיקת מבחן",
                                                "Delete Exam"
                                            ),
                                            systemImage: "trash"
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle(
                tr(
                    "ארכיון מבחנים",
                    "Exam Archive"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button(
                        tr(
                            "סגור",
                            "Close"
                        )
                    ) {
                        showExamArchiveSheet = false
                    }
                    .kmiFont(
                        size: 14,
                        weight: .black
                    )
                }
            }
        }
    }

    private func completedExamArchiveRow(
        _ result: StoredCompletedInternalExamResult
    ) -> some View {
        HStack(spacing: 12) {
            if isEnglish {
                archiveResultLabels(result)

                archivePercentBadge(result)

                Image(systemName: "chevron.right")
                    .kmiFont(
                        size: 13,
                        weight: .black
                    )
                    .foregroundStyle(
                        examSecondaryTextColor
                    )
            } else {
                Image(systemName: "chevron.left")
                    .kmiFont(
                        size: 13,
                        weight: .black
                    )
                    .foregroundStyle(
                        examSecondaryTextColor
                    )

                archivePercentBadge(result)

                archiveResultLabels(result)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(examPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                statusColor(
                    percent: result.percent
                )
                .opacity(isDarkMode ? 0.40 : 0.25),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.30 : 0.08
            ),
            radius: 6,
            x: 0,
            y: 3
        )
    }

    private func archiveResultLabels(
        _ result: StoredCompletedInternalExamResult
    ) -> some View {
        VStack(
            alignment:
                isEnglish ? .leading : .trailing,
            spacing: 5
        ) {
            if result.isUnassigned {
                Text(
                    tr(
                        "ארכיון קודם ללא שיוך לסניף וקבוצה",
                        "Previous unassigned archive"
                    )
                )
                .kmiTypography(.caption)
                .foregroundStyle(examSecondaryTextColor)
            }

            Text(result.traineeName)
                .kmiFont(
                    size: 17,
                    weight: .black
                )
                .foregroundStyle(
                    examPrimaryTextColor
                )
                .lineLimit(1)
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish ? .leading : .trailing
                )

            Text(
                result.beltNameForArchive(
                    isEnglish: isEnglish
                )
            )
            .kmiFont(
                size: 13,
                weight: .heavy
            )
            .foregroundStyle(
                beltAccentColor(
                    for:
                        beltFromArchiveResult(result)
                )
            )
            .lineLimit(1)
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish ? .leading : .trailing
            )

            Text(
                tr(
                    "תאריך סיום: \(archiveDateText(result.completedAtMillis))",
                    "Completed: \(archiveDateText(result.completedAtMillis))"
                )
            )
            .kmiFont(
                size: 12,
                weight: .bold
            )
            .foregroundStyle(
                examSecondaryTextColor
            )
            .lineLimit(1)
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish ? .leading : .trailing
            )

            Text(
                tr(
                    "ציון: \(result.score10.scoreString()) / 10 (\(result.percent)%)",
                    "Score: \(result.score10.scoreString()) / 10 (\(result.percent)%)"
                )
            )
            .kmiFont(
                size: 12,
                weight: .black
            )
            .foregroundStyle(
                statusColor(
                    percent: result.percent
                )
            )
            .lineLimit(1)
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish ? .leading : .trailing
            )
        }
    }

    private func archivePercentBadge(
        _ result: StoredCompletedInternalExamResult
    ) -> some View {
        Circle()
            .fill(
                statusColor(
                    percent: result.percent
                )
                .opacity(isDarkMode ? 0.24 : 0.18)
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text("\(result.percent)%")
                    .kmiFont(
                        size: 12,
                        weight: .black
                    )
                    .foregroundStyle(
                        statusColor(
                            percent: result.percent
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        statusColor(
                            percent: result.percent
                        )
                        .opacity(0.38),
                        lineWidth: 1
                    )
            )
    }

    private func beltFromArchiveResult(
        _ result: StoredCompletedInternalExamResult
    ) -> Belt {
        let normalized =
            result.beltId
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        switch normalized {
        case "white":
            return .white

        case "yellow":
            return .yellow

        case "orange":
            return .orange

        case "green":
            return .green

        case "blue":
            return .blue

        case "brown":
            return .brown

        case "black":
            return .black

        default:
            return currentBelt
        }
    }
    
    private func completedExamDetailView(
        _ result: StoredCompletedInternalExamResult
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                VStack(
                    alignment:
                        isEnglish ? .leading : .trailing,
                    spacing: 8
                ) {
                    Text(result.traineeName)
                        .kmiFont(
                            size: 22,
                            weight: .black
                        )
                        .foregroundStyle(
                            examPrimaryTextColor
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment:
                                isEnglish
                                ? .leading
                                : .trailing
                        )

                    Text(
                        result.beltNameForArchive(
                            isEnglish: isEnglish
                        )
                    )
                    .kmiFont(
                        size: 16,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        beltAccentColor(
                            for:
                                beltFromArchiveResult(result)
                        )
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish ? .leading : .trailing
                    )

                    Text(
                        tr(
                            "תאריך סיום: \(archiveDateText(result.completedAtMillis))",
                            "Completed: \(archiveDateText(result.completedAtMillis))"
                        )
                    )
                    .kmiFont(
                        size: 14,
                        weight: .bold
                    )
                    .foregroundStyle(
                        examSecondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish ? .leading : .trailing
                    )

                    Text(
                        tr(
                            "ציון: \(result.score10.scoreString()) / 10 (\(result.percent)%)",
                            "Score: \(result.score10.scoreString()) / 10 (\(result.percent)%)"
                        )
                    )
                    .kmiFont(
                        size: 17,
                        weight: .black
                    )
                    .foregroundStyle(
                        statusColor(
                            percent: result.percent
                        )
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish ? .leading : .trailing
                    )

                    Text(
                        isEnglish
                            ? result.summaryTextEn
                            : result.summaryTextHe
                    )
                    .kmiFont(
                        size: 14,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        examSecondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish ? .leading : .trailing
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(examPanelColor)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        statusColor(
                            percent: result.percent
                        )
                        .opacity(0.34),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: Color.black.opacity(
                        isDarkMode ? 0.30 : 0.08
                    ),
                    radius: 7,
                    x: 0,
                    y: 4
                )

                if result.answeredExercises.isEmpty {
                    Text(
                        tr(
                            "אין פירוט תרגילים למבחן זה.",
                            "No exercise details for this exam."
                        )
                    )
                    .kmiFont(
                        size: 15,
                        weight: .bold
                    )
                    .foregroundStyle(
                        examSecondaryTextColor
                    )
                    .padding(.top, 12)

                } else {
                    ForEach(
                        groupCompletedExercises(
                            result.answeredExercises
                        ),
                        id: \.topic
                    ) { group in
                        VStack(
                            alignment:
                                isEnglish
                                ? .leading
                                : .trailing,
                            spacing: 8
                        ) {
                            Text(
                                examTitleForUi(
                                    group.topic,
                                    isEnglish: isEnglish
                                )
                            )
                            .kmiFont(
                                size: 16,
                                weight: .black
                            )
                            .foregroundStyle(
                                examPrimaryTextColor
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment:
                                    isEnglish
                                    ? .leading
                                    : .trailing
                            )

                            ForEach(
                                group.items,
                                id: \.exerciseId
                            ) { item in
                                HStack(spacing: 10) {
                                    if isEnglish {
                                        completedExerciseTitle(item)
                                        completedExerciseScore(item)
                                    } else {
                                        completedExerciseScore(item)
                                        completedExerciseTitle(item)
                                    }
                                }
                                .environment(
                                    \.layoutDirection,
                                    .leftToRight
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(examFieldColor)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                    .stroke(
                                        Color.white.opacity(
                                            isDarkMode ? 0.12 : 0
                                        ),
                                        lineWidth: 1
                                    )
                                )
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .fill(examPanelColor)
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .stroke(
                                examPanelBorderColor,
                                lineWidth: 1
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background {
            KmiAppBackground()
        }
        .navigationTitle(
            tr(
                "פרטי מבחן",
                "Exam Details"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completedExerciseTitle(
        _ item: StoredCompletedInternalExamExercise
    ) -> some View {
        Text(
            examTitleForUi(
                item.name,
                isEnglish: isEnglish
            )
        )
        .kmiFont(
            size: 13,
            weight: .bold
        )
        .foregroundStyle(examPrimaryTextColor)
        .multilineTextAlignment(
            isEnglish ? .leading : .trailing
        )
        .frame(
            maxWidth: .infinity,
            alignment:
                isEnglish ? .leading : .trailing
        )
    }

    private func completedExerciseScore(
        _ item: StoredCompletedInternalExamExercise
    ) -> some View {
        Text("\(item.score)")
            .kmiFont(
                size: 14,
                weight: .black
            )
            .foregroundStyle(
                Color.black.opacity(0.88)
            )
            .frame(width: 34, height: 30)
            .background(
                scoreColor(item.score)
                    .opacity(0.72)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
    }
    
    private func openCompletedExamArchive() {
        guard let scope = examScope,
              !isLoadingExamArchive else {
            return
        }

        completedExamResults = []
        isLoadingExamArchive = true
        showExamArchiveSheet = true

        loadCompletedInternalExamResultsFromFirestore { result in
            DispatchQueue.main.async {
                guard examScope == scope else {
                    return
                }

                isLoadingExamArchive = false

                switch result {
                case .success(let results):
                    completedExamResults = results

                case .failure:
                    showExamArchiveSheet = false

                    showExamScopeMessage(
                        "לא ניתן לטעון את היסטוריית המבחנים כרגע. נסה שוב.",
                        "Exam history could not be loaded. Please try again."
                    )
                }
            }
        }
    }

    private func deleteCompletedExamResult(
        _ result: StoredCompletedInternalExamResult
    ) {
        guard let scope = examScope,
              !isDeletingExamResult,
              !result.resultId.trimmed().isEmpty else {
            return
        }

        isDeletingExamResult = true

        let reference = Firestore.firestore()
            .collection(InternalExamStore.completedResultsCollection)
            .document(result.resultId)

        reference.getDocument { snapshot, error in
            guard scope.isCurrentUser else {
                return
            }

            let data = snapshot?.data()

            let legacy =
                result.isUnassigned &&
                (data?["branch"] as? String ?? "").trimmed().isEmpty &&
                (data?["group"] as? String ?? "").trimmed().isEmpty &&
                data?["coachUid"] as? String == scope.coachUid

            guard error == nil,
                  let data,
                  scope.matches(data) || legacy else {
                DispatchQueue.main.async {
                    guard examScope == scope else {
                        return
                    }

                    isDeletingExamResult = false
                    examResultToDelete = nil

                    showExamScopeMessage(
                        "לא ניתן לאמת את המבחן למחיקה. נסה שוב.",
                        "The exam could not be verified for deletion. Please try again."
                    )
                }
                return
            }

            reference.delete { error in
                DispatchQueue.main.async {
                    guard examScope == scope else {
                        return
                    }

                    isDeletingExamResult = false
                    examResultToDelete = nil

                    guard error == nil else {
                        showExamScopeMessage(
                            "מחיקת המבחן נכשלה. נסה שוב.",
                            "The exam could not be deleted. Please try again."
                        )
                        return
                    }

                    completedExamResults.removeAll {
                        $0.resultId == result.resultId
                    }
                }
            }
        }
    }

    private var traineePickerSheet: some View {
        NavigationStack {
            List {
                if recentTrainees.isEmpty {
                    Text(tr("אין נבחנים שמורים עדיין.", "No saved trainees yet."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: examFrameAlignment)
                        .multilineTextAlignment(examTextAlignment)
                } else {
                    ForEach(recentTrainees, id: \.self) { name in
                        Button {
                            marksMap.removeAll()
                            pendingLoadedDraft.removeAll()
                            selectedSavedTraineeName = name.trimmed()
                            traineeName = name.trimmed()
                            showTraineeNameBox = false
                            isTypingNewTraineeName = false
                            resumeCheckedKey = nil
                            showPickTraineeDialog = false
                            checkForDraft()
                        } label: {
                            HStack {
                                if isEnglish {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                } else {
                                    Spacer()
                                    Text(name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Button {
                    marksMap.removeAll()
                    traineeName = ""
                    showTraineeNameBox = true
                    resumeCheckedKey = nil
                    showPickTraineeDialog = false
                } label: {
                    HStack {
                        if isEnglish {
                            Text(tr("נבחן חדש", "New trainee"))
                            Spacer()
                        } else {
                            Spacer()
                            Text(tr("נבחן חדש", "New trainee"))
                        }
                    }
                }
            }
            .navigationTitle(tr("בחר נבחן", "Select trainee"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("סגור", "Close")) {
                        showPickTraineeDialog = false
                    }
                }
            }
        }
    }

    // MARK: - Derived Data

    private var examItemsForCurrentBelt: [ExamExerciseItem] {
        examItems(for: currentBelt)
    }

    private var groupedTopics: [ExamTopicGroup] {
        let grouped = Dictionary(grouping: examItemsForCurrentBelt, by: { $0.topic })
        return grouped
            .map { ExamTopicGroup(topic: $0.key, items: $0.value) }
            .sorted { $0.topic < $1.topic }
    }

    private var session: InternalExamSession {
        let allExercises = beltsUpTo(currentBelt)
            .flatMap { belt in
                examItems(for: belt)
            }

        let uniqueExercises = Array(
            Dictionary(grouping: allExercises, by: { $0.id })
                .compactMap { $0.value.first }
        )

        let marks = uniqueExercises.map { item in
            marksMap[item.id]
        }

        return InternalExamSession(
            traineeName: traineeName.trimmed(),
            belt: currentBelt,
            date: Date(),
            exercises: uniqueExercises,
            marks: marks
        )
    }
    
    // MARK: - Actions

    private func startExamFromAndroidPanel() {
        guard examScope != nil else {
            showExamScopeMessage(
                "יש לבחור סניף וקבוצה לפני תחילת המבחן.",
                "Select a branch and group before starting the exam."
            )
            return
        }

        let name = traineeName.trimmed()

        guard !name.isEmpty else {
            showExamScopeMessage(
                "נא לבחור נבחן או להזין שם נבחן חדש.",
                "Select a trainee or enter a new trainee name."
            )
            return
        }

        traineeName = name
        showTraineeNameBox = false
        isTypingNewTraineeName = false

        pushRecentTrainee(name)
        saveLastTrainee(name)
        checkForDraft(startWhenMissing: true)
    }
    
    private func saveDraftFromAndroidPanel(
        shouldExit: Bool = false
    ) {
        guard !isExamScopeBusy, examScope != nil else {
            return
        }

        let name = traineeName.trimmed()

        guard !name.isEmpty else {
            showExamScopeMessage(
                "נא להזין שם נבחן לפני שמירה.",
                "Enter a trainee name before saving."
            )
            return
        }

        traineeName = name
        showTraineeNameBox = false
        isSavingExamDraft = true

        saveExamDraft(
            traineeName: name,
            belt: currentBelt,
            marksMap: marksMap
        ) { success in
            isSavingExamDraft = false

            guard success else {
                showExamScopeMessage(
                    "שמירת הטיוטה נכשלה. הציונים נשארו במסך; נסה שוב.",
                    "The draft could not be saved. Your scores remain on screen; please try again."
                )
                return
            }

            pushRecentTrainee(name)
            saveLastTrainee(name)
            hasUnsavedChanges = false

            if shouldExit {
                dismiss()
            } else {
                showExamScopeMessage(
                    "הטיוטה נשמרה בהצלחה.",
                    "Draft saved successfully."
                )
            }
        }
    }
    
    private func continueSavedExamFromPrompt() {
        marksMap = pendingLoadedDraft
        hasUnsavedChanges = false
        showResumeDialog = false
        showTraineeNameBox = false

        // Android behavior: saved exam opens with topics closed.
        expandedTopic = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            hasStartedExam = true
        }
    }
    
    private func startNewExamFromSavedPrompt() {
        marksMap.removeAll()
        pendingLoadedDraft.removeAll()
        showResumeDialog = false
        hasUnsavedChanges = false
        showTraineeNameBox = true
        resumeCheckedKey = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            hasStartedExam = false
        }
    }
    
    private func bootstrapInitialState() {
        recentTrainees = loadRecentTrainees()

        // Android behavior:
        // Do not auto-select the last trainee when entering the internal exam screen.
        // The field should start as "בחר נבחן מתוך הרשימה".
        if traineeName.trimmed().isEmpty {
            traineeName = ""
            showTraineeNameBox = true
            isTypingNewTraineeName = false
        }

        checkForDraft()
    }
    
    private func commitTraineeNameAndCollapse() -> Bool {
        let name = traineeName.trimmed()
        guard !name.isEmpty else { return false }

        traineeName = name
        pushRecentTrainee(name)
        saveLastTrainee(name)
        showTraineeNameBox = false
        checkForDraft()
        return true
    }

    private func checkForDraft(startWhenMissing: Bool = false) {
        guard let scope = examScope else {
            return
        }

        let name = traineeName.trimmed()

        guard !name.isEmpty, !isCheckingExamDraft else {
            return
        }

        let selectedBelt = currentBelt
        let key = draftKey(
            traineeName: name,
            belt: selectedBelt
        )

        if resumeCheckedKey == key {
            if startWhenMissing &&
                !showResumeDialog &&
                !showLegacyExamImport {
                hasStartedExam = true
            }
            return
        }

        resumeCheckedKey = key
        isCheckingExamDraft = true

        scopedLoadExamDraft(
            traineeName: name,
            belt: selectedBelt,
            scope: scope
        ) { result in
            DispatchQueue.main.async {
                guard examScope == scope,
                      traineeName.trimmed() == name,
                      currentBelt.id == selectedBelt.id,
                      resumeCheckedKey == key else {
                    return
                }

                isCheckingExamDraft = false

                switch result {
                case .success(let loaded):
                    pendingLoadedDraft = loaded.marks

                    if !loaded.marks.isEmpty {
                        if loaded.isLegacy {
                            showLegacyExamImport = true
                        } else {
                            showResumeDialog = true
                        }
                    } else if startWhenMissing {
                        expandedTopic = nil
                        hasStartedExam = true
                    }

                case .failure:
                    resumeCheckedKey = nil

                    showExamScopeMessage(
                        "לא ניתן לבדוק את הטיוטה כרגע. נסה שוב לפני תחילת המבחן.",
                        "The draft could not be checked. Please try again before starting the exam."
                    )
                }
            }
        }
    }
    
    private func saveCurrentExam() {
        guard examScope != nil else {
            showExamScopeMessage(
                "יש לבחור סניף וקבוצה לפני שמירת תוצאה.",
                "Select a branch and group before saving a result."
            )
            return
        }
        let cleanName = traineeName.trimmed()

        guard !cleanName.isEmpty else {
            examActionMessage = tr(
                "נא להזין שם נבחן לפני סיום המבחן.",
                "Please enter a trainee name before finishing the exam."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        guard !marksMap.isEmpty else {
            examActionMessage = tr(
                "אין ציונים לשמירה. יש לבחור לפחות ציון אחד לפני סיום המבחן.",
                "There are no scores to save. Choose at least one score before finishing the exam."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        guard !isSavingFinalResult else {
            return
        }

        traineeName = cleanName
        showTraineeNameBox = false
        isSavingFinalResult = true

        let finalSession = session
        let finalMarksMap = marksMap

        saveCompletedExamResult(
            session: finalSession,
            marksMap: finalMarksMap
        ) { didSave in
            DispatchQueue.main.async {
                isSavingFinalResult = false

                guard didSave else {
                    examActionMessage = tr(
                        "סיום המבחן נכשל. נסה שוב.",
                        "Finishing the exam failed. Please try again."
                    )
                    shouldDismissAfterExamAction = false
                    showExamActionAlert = true
                    return
                }

                removeExamDraft(
                    traineeName: cleanName,
                    belt: currentBelt
                )

                removeRecentTraineeAfterCompletion(cleanName)

                if let scope = examScope {
                    UserDefaults.standard.removeObject(
                        forKey: scope.localKey(InternalExamStore.lastKey)
                    )
                }

                marksMap.removeAll()
                pendingLoadedDraft.removeAll()
                hasUnsavedChanges = false
                resumeCheckedKey = nil
                selectedSavedTraineeName = nil
                expandedTopic = nil
                expandedExamSubTopic = nil
                showResumeDialog = false
                showLegacyExamImport = false
                isCheckingExamDraft = false

                traineeName = ""
                showTraineeNameBox = true
                isTypingNewTraineeName = false
                hasStartedExam = false

                examActionMessage = tr(
                    "המבחן הסתיים ונשמר בהצלחה.",
                    "The exam was finished and saved successfully."
                )
                shouldDismissAfterExamAction = false
                showExamActionAlert = true
            }
        }
    }
    
    private func shareSummaryText() {
        let cleanName = traineeName.trimmed()

        guard !cleanName.isEmpty else {
            examActionMessage = tr(
                "נא להזין שם נבחן לפני שיתוף המבחן.",
                "Please enter a trainee name before sharing the exam."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        guard !marksMap.isEmpty else {
            examActionMessage = tr(
                "אין ציונים לשיתוף. יש לבחור לפחות ציון אחד.",
                "There are no scores to share. Choose at least one score."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        traineeName = cleanName

        examShareItems = [
            session.shareText(isEnglish: isEnglish)
        ]

        showExamShareSheet = true
    }

    private func exportPdf() {
        guard !isCreatingExamPDF else {
            return
        }

        let cleanName = traineeName.trimmed()

        guard !cleanName.isEmpty else {
            examActionMessage = tr(
                "נא להזין שם נבחן לפני ייצוא PDF.",
                "Please enter a trainee name before exporting PDF."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        guard !marksMap.isEmpty else {
            examActionMessage = tr(
                "אין ציונים לייצוא. יש לבחור לפחות ציון אחד.",
                "There are no scores to export. Choose at least one score."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        isCreatingExamPDF = true

        defer {
            isCreatingExamPDF = false
        }

        traineeName = cleanName

        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let pageWidth = pageBounds.width
        let pageHeight = pageBounds.height

        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = pageWidth - 40
        let contentWidth = rightMargin - leftMargin
        let contentTop = KmiPdfHeader.CONTENT_TOP
        let contentBottom = pageHeight - KmiPdfFooter.CONTENT_BOTTOM_PADDING

        let primaryText = UIColor(
            red: 15.0 / 255.0,
            green: 23.0 / 255.0,
            blue: 42.0 / 255.0,
            alpha: 1
        )

        let secondaryText = UIColor(
            red: 71.0 / 255.0,
            green: 85.0 / 255.0,
            blue: 105.0 / 255.0,
            alpha: 1
        )

        let mutedText = UIColor(
            red: 100.0 / 255.0,
            green: 116.0 / 255.0,
            blue: 139.0 / 255.0,
            alpha: 1
        )

        let cardBackground = UIColor(
            red: 248.0 / 255.0,
            green: 250.0 / 255.0,
            blue: 252.0 / 255.0,
            alpha: 1
        )

        let borderColor = UIColor(
            red: 226.0 / 255.0,
            green: 232.0 / 255.0,
            blue: 240.0 / 255.0,
            alpha: 1
        )

        let scoreBoxBackground = UIColor(
            red: 238.0 / 255.0,
            green: 242.0 / 255.0,
            blue: 255.0 / 255.0,
            alpha: 1
        )

        let scoreBoxBorder = UIColor(
            red: 199.0 / 255.0,
            green: 210.0 / 255.0,
            blue: 254.0 / 255.0,
            alpha: 1
        )

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(
            identifier: isEnglish ? "en_US_POSIX" : "he_IL"
        )
        dateFormatter.dateFormat = "dd.MM.yyyy"

        let formattedDate = dateFormatter.string(from: session.date)

        let answeredRows: [(exercise: ExamExerciseItem, score: Int)] =
            session.exercises.enumerated().compactMap { index, exercise in
                guard
                    index < session.marks.count,
                    let rawScore = session.marks[index]
                else {
                    return nil
                }

                return (
                    exercise: exercise,
                    score: clampScore10(rawScore)
                )
            }

        func statusColor(for percent: Int) -> UIColor {
            switch percent {
            case 85...:
                return UIColor(
                    red: 22.0 / 255.0,
                    green: 163.0 / 255.0,
                    blue: 74.0 / 255.0,
                    alpha: 1
                )

            case 70...:
                return UIColor(
                    red: 132.0 / 255.0,
                    green: 204.0 / 255.0,
                    blue: 22.0 / 255.0,
                    alpha: 1
                )

            case 50...:
                return UIColor(
                    red: 245.0 / 255.0,
                    green: 158.0 / 255.0,
                    blue: 11.0 / 255.0,
                    alpha: 1
                )

            default:
                return UIColor(
                    red: 239.0 / 255.0,
                    green: 68.0 / 255.0,
                    blue: 68.0 / 255.0,
                    alpha: 1
                )
            }
        }

        func statusPillText(for percent: Int) -> String {
            if isEnglish {
                switch percent {
                case 85...:
                    return "Excellent"
                case 70...:
                    return "Good"
                case 50...:
                    return "Average"
                default:
                    return "Weak"
                }
            }

            switch percent {
            case 85...:
                return "מצוין"
            case 70...:
                return "טוב"
            case 50...:
                return "בינוני"
            default:
                return "חלש"
            }
        }

        func beltPdfColor(_ belt: Belt) -> UIColor {
            switch belt {
            case .yellow:
                return UIColor(
                    red: 202.0 / 255.0,
                    green: 138.0 / 255.0,
                    blue: 4.0 / 255.0,
                    alpha: 1
                )

            case .orange:
                return UIColor(
                    red: 234.0 / 255.0,
                    green: 88.0 / 255.0,
                    blue: 12.0 / 255.0,
                    alpha: 1
                )

            case .green:
                return UIColor(
                    red: 22.0 / 255.0,
                    green: 163.0 / 255.0,
                    blue: 74.0 / 255.0,
                    alpha: 1
                )

            case .blue:
                return UIColor(
                    red: 37.0 / 255.0,
                    green: 99.0 / 255.0,
                    blue: 235.0 / 255.0,
                    alpha: 1
                )

            case .brown:
                return UIColor(
                    red: 124.0 / 255.0,
                    green: 63.0 / 255.0,
                    blue: 29.0 / 255.0,
                    alpha: 1
                )

            case .black:
                return UIColor(
                    red: 17.0 / 255.0,
                    green: 24.0 / 255.0,
                    blue: 39.0 / 255.0,
                    alpha: 1
                )

            default:
                return UIColor(
                    red: 124.0 / 255.0,
                    green: 58.0 / 255.0,
                    blue: 237.0 / 255.0,
                    alpha: 1
                )
            }
        }

        func paragraphStyle(
            alignment: NSTextAlignment,
            lineBreakMode: NSLineBreakMode = .byTruncatingTail
        ) -> NSMutableParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            style.baseWritingDirection =
                isEnglish ? .leftToRight : .rightToLeft
            style.lineBreakMode = lineBreakMode
            return style
        }

        func drawText(
            _ text: String,
            in rect: CGRect,
            font: UIFont,
            color: UIColor,
            alignment: NSTextAlignment,
            lineBreakMode: NSLineBreakMode = .byTruncatingTail
        ) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle(
                    alignment: alignment,
                    lineBreakMode: lineBreakMode
                )
            ]

            NSString(string: text).draw(
                with: rect,
                options: [
                    .usesLineFragmentOrigin,
                    .usesFontLeading,
                    .truncatesLastVisibleLine
                ],
                attributes: attributes,
                context: nil
            )
        }

        func fillRoundedRect(
            _ rect: CGRect,
            radius: CGFloat,
            color: UIColor
        ) {
            color.setFill()

            UIBezierPath(
                roundedRect: rect,
                cornerRadius: radius
            ).fill()
        }

        func strokeRoundedRect(
            _ rect: CGRect,
            radius: CGFloat,
            color: UIColor,
            lineWidth: CGFloat
        ) {
            color.setStroke()

            let path = UIBezierPath(
                roundedRect: rect.insetBy(
                    dx: lineWidth / 2,
                    dy: lineWidth / 2
                ),
                cornerRadius: radius
            )

            path.lineWidth = lineWidth
            path.stroke()
        }

        let data = renderer.pdfData { context in
            var pageNumber = 0
            var currentY = contentTop

            func drawHeader() {
                KmiPdfHeader.draw(
                    context: context.cgContext,
                    pageWidth: pageWidth,
                    isEnglish: isEnglish,
                    titleHebrew: "דו״ח מבחן פנימי",
                    titleEnglish: "Internal Exam",
                    subtitleHebrew: "חגורה: \(examBeltNameForUi(session.belt, isEnglish: false))",
                    subtitleEnglish: "Belt: \(examBeltNameForUi(session.belt, isEnglish: true))",
                    generatedDate: formattedDate
                )
            }

            func drawFooter() {
                KmiPdfFooter.draw(
                    context: context.cgContext,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    pageNumber: pageNumber,
                    isEnglish: isEnglish
                )
            }

            func beginPage(continued: Bool) {
                if pageNumber > 0 {
                    drawFooter()
                }

                context.beginPage()
                pageNumber += 1
                currentY = contentTop

                drawHeader()

                if continued {
                    drawText(
                        tr(
                            "פירוט תרגילים – המשך",
                            "Exercise details — continued"
                        ),
                        in: CGRect(
                            x: leftMargin,
                            y: currentY,
                            width: contentWidth,
                            height: 22
                        ),
                        font: .systemFont(
                            ofSize: 15,
                            weight: .bold
                        ),
                        color: primaryText,
                        alignment: isEnglish ? .left : .right
                    )

                    currentY += 27

                    borderColor.setFill()

                    UIBezierPath(
                        rect: CGRect(
                            x: leftMargin,
                            y: currentY,
                            width: contentWidth,
                            height: 1
                        )
                    ).fill()

                    currentY += 16
                }
            }

            func drawKpiCard(
                x: CGFloat,
                width: CGFloat,
                label: String,
                value: String
            ) {
                let rect = CGRect(
                    x: x,
                    y: currentY,
                    width: width,
                    height: 64
                )

                fillRoundedRect(
                    rect,
                    radius: 14,
                    color: cardBackground
                )

                strokeRoundedRect(
                    rect,
                    radius: 14,
                    color: borderColor,
                    lineWidth: 1.2
                )

                drawText(
                    label,
                    in: CGRect(
                        x: rect.minX + 14,
                        y: rect.minY + 12,
                        width: rect.width - 28,
                        height: 18
                    ),
                    font: .systemFont(
                        ofSize: 11,
                        weight: .regular
                    ),
                    color: mutedText,
                    alignment: .left
                )

                drawText(
                    value,
                    in: CGRect(
                        x: rect.minX + 14,
                        y: rect.minY + 34,
                        width: rect.width - 28,
                        height: 20
                    ),
                    font: .systemFont(
                        ofSize: 14,
                        weight: .bold
                    ),
                    color: primaryText,
                    alignment: .right
                )
            }

            func drawScoreSummary() {
                let rect = CGRect(
                    x: leftMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 78
                )

                fillRoundedRect(
                    rect,
                    radius: 18,
                    color: .white
                )

                strokeRoundedRect(
                    rect,
                    radius: 18,
                    color: borderColor,
                    lineWidth: 1.5
                )

                let pillWidth: CGFloat = 132

                let pillRect = CGRect(
                    x:
                        isEnglish
                        ? rect.maxX - pillWidth - 18
                        : rect.minX + 18,
                    y: rect.minY + 18,
                    width: pillWidth,
                    height: 42
                )

                fillRoundedRect(
                    pillRect,
                    radius: 21,
                    color: statusColor(for: session.percent)
                )

                drawText(
                    statusPillText(for: session.percent),
                    in: CGRect(
                        x: pillRect.minX + 8,
                        y: pillRect.minY + 11,
                        width: pillRect.width - 16,
                        height: 22
                    ),
                    font: .systemFont(
                        ofSize: 14,
                        weight: .bold
                    ),
                    color: .white,
                    alignment: .center
                )

                let textX: CGFloat =
                    isEnglish
                    ? rect.minX + 18
                    : pillRect.maxX + 18

                let textWidth: CGFloat =
                    isEnglish
                    ? pillRect.minX - textX - 12
                    : rect.maxX - textX - 18

                drawText(
                    tr(
                        "ציון: \(Int(session.totalScore)) / \(Int(session.maxScore))  (\(session.percent)%)",
                        "Score: \(Int(session.totalScore)) / \(Int(session.maxScore))  (\(session.percent)%)"
                    ),
                    in: CGRect(
                        x: textX,
                        y: rect.minY + 18,
                        width: textWidth,
                        height: 23
                    ),
                    font: .systemFont(
                        ofSize: 16,
                        weight: .bold
                    ),
                    color: primaryText,
                    alignment: isEnglish ? .left : .right
                )

                drawText(
                    tr(
                        "סטטוס: \(examStatusText(percent: session.percent, isEnglish: false))",
                        "Status: \(examStatusText(percent: session.percent, isEnglish: true))"
                    ),
                    in: CGRect(
                        x: textX,
                        y: rect.minY + 46,
                        width: textWidth,
                        height: 19
                    ),
                    font: .systemFont(
                        ofSize: 12.5,
                        weight: .regular
                    ),
                    color: secondaryText,
                    alignment: isEnglish ? .left : .right
                )

                currentY += 94
            }

            func drawScoreBox(
                score: Int,
                rowRect: CGRect
            ) {
                let scoreRect = CGRect(
                    x:
                        isEnglish
                        ? rowRect.maxX - 48
                        : rowRect.minX + 8,
                    y: rowRect.minY + 3,
                    width: 40,
                    height: 22
                )

                fillRoundedRect(
                    scoreRect,
                    radius: 7,
                    color: scoreBoxBackground
                )

                strokeRoundedRect(
                    scoreRect,
                    radius: 7,
                    color: scoreBoxBorder,
                    lineWidth: 1
                )

                drawText(
                    "\(score)",
                    in: CGRect(
                        x: scoreRect.minX,
                        y: scoreRect.minY + 3,
                        width: scoreRect.width,
                        height: 18
                    ),
                    font: .systemFont(
                        ofSize: 12,
                        weight: .bold
                    ),
                    color: primaryText,
                    alignment: .center
                )
            }

            beginPage(continued: false)

            let cardGap: CGFloat = 10
            let cardWidth =
                (contentWidth - cardGap * 2) / 3

            drawKpiCard(
                x: leftMargin,
                width: cardWidth,
                label: tr(
                    "שם מתאמן",
                    "Trainee name"
                ),
                value: cleanName
            )

            drawKpiCard(
                x: leftMargin + cardWidth + cardGap,
                width: cardWidth,
                label: tr(
                    "חגורה במבחן",
                    "Exam belt"
                ),
                value: examBeltNameForUi(
                    session.belt,
                    isEnglish: isEnglish
                )
            )

            drawKpiCard(
                x: leftMargin + (cardWidth + cardGap) * 2,
                width: cardWidth,
                label: tr(
                    "תאריך",
                    "Date"
                ),
                value: formattedDate
            )

            currentY += 80

            drawScoreSummary()

            drawText(
                tr(
                    "פירוט תרגילים",
                    "Exercise details"
                ),
                in: CGRect(
                    x: leftMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 22
                ),
                font: .systemFont(
                    ofSize: 15,
                    weight: .bold
                ),
                color: primaryText,
                alignment: isEnglish ? .left : .right
            )

            currentY += 27

            borderColor.setFill()

            UIBezierPath(
                rect: CGRect(
                    x: leftMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 1
                )
            ).fill()

            currentY += 16

            var currentBeltID: String?
            var currentTopic: String?

            for row in answeredRows {
                if currentY + 92 > contentBottom {
                    beginPage(continued: true)
                    currentBeltID = nil
                    currentTopic = nil
                }

                if currentBeltID != row.exercise.belt.id {
                    currentBeltID = row.exercise.belt.id
                    currentTopic = nil

                    let beltTitle = tr(
                        "חגורה: \(examBeltNameForUi(row.exercise.belt, isEnglish: false))",
                        "Belt: \(examBeltNameForUi(row.exercise.belt, isEnglish: true))"
                    )

                    drawText(
                        beltTitle,
                        in: CGRect(
                            x: leftMargin,
                            y: currentY,
                            width: contentWidth,
                            height: 22
                        ),
                        font: .systemFont(
                            ofSize: 13.5,
                            weight: .bold
                        ),
                        color: beltPdfColor(row.exercise.belt),
                        alignment: isEnglish ? .left : .right
                    )

                    currentY += 24
                }

                let localizedTopic = examTitleForUi(
                    row.exercise.topic,
                    isEnglish: isEnglish
                )

                if currentTopic != localizedTopic {
                    currentTopic = localizedTopic

                    drawText(
                        tr(
                            "נושא: \(localizedTopic)",
                            "Topic: \(localizedTopic)"
                        ),
                        in: CGRect(
                            x: leftMargin,
                            y: currentY,
                            width: contentWidth,
                            height: 22
                        ),
                        font: .systemFont(
                            ofSize: 13.5,
                            weight: .bold
                        ),
                        color: secondaryText,
                        alignment: isEnglish ? .left : .right
                    )

                    currentY += 25
                }

                let rowRect = CGRect(
                    x: leftMargin,
                    y: currentY,
                    width: contentWidth,
                    height: 28
                )

                fillRoundedRect(
                    rowRect,
                    radius: 7,
                    color: cardBackground
                )

                strokeRoundedRect(
                    rowRect,
                    radius: 7,
                    color: borderColor,
                    lineWidth: 0.8
                )

                drawScoreBox(
                    score: row.score,
                    rowRect: rowRect
                )

                let exerciseName = examTitleForUi(
                    row.exercise.name,
                    isEnglish: isEnglish
                )

                let exerciseTextRect = CGRect(
                    x:
                        isEnglish
                        ? rowRect.minX + 10
                        : rowRect.minX + 58,
                    y: rowRect.minY + 5,
                    width: rowRect.width - 68,
                    height: 19
                )

                drawText(
                    exerciseName,
                    in: exerciseTextRect,
                    font: .systemFont(
                        ofSize: 12.5,
                        weight: .regular
                    ),
                    color: primaryText,
                    alignment: isEnglish ? .left : .right
                )

                currentY += 32
            }

            drawFooter()
        }

        let temporaryDirectory =
            FileManager.default.temporaryDirectory

        let fileName =
            isEnglish
            ? "internal_exam_report.pdf"
            : "דוח_מבחן_פנימי.pdf"

        let fileURL =
            temporaryDirectory.appendingPathComponent(
                fileName
            )

        do {
            try? FileManager.default.removeItem(
                at: fileURL
            )

            try data.write(
                to: fileURL,
                options: .atomic
            )

            examShareItems = [fileURL]
            showExamShareSheet = true
        } catch {
            examActionMessage = tr(
                "יצירת קובץ ה־PDF נכשלה. נסה שוב.",
                "The PDF could not be created. Please try again."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
        }
    }

    // MARK: - Data Source

    private func examItems(for belt: Belt) -> [ExamExerciseItem] {
        let categorized = ExamDataSource.categorizedItemsForBelt(belt)

        return categorized.enumerated().map { index, item in
            ExamExerciseItem(
                id: "\(belt.id)_\(item.topic)_\(item.name)_\(index)",
                belt: belt,
                topic: item.topic,
                name: item.name,
                subTopic: item.subTopic
            )
        }
    }
}

private struct CompletedExerciseGroup {
    let topic: String
    let items: [StoredCompletedInternalExamExercise]
}

private func groupCompletedExercises(_ exercises: [StoredCompletedInternalExamExercise]) -> [CompletedExerciseGroup] {
    Dictionary(grouping: exercises, by: { $0.topic })
        .map { CompletedExerciseGroup(topic: $0.key, items: $0.value) }
        .sorted { $0.topic < $1.topic }
}

private func archiveDateText(_ millis: Int64) -> String {
    guard millis > 0 else { return "—" }

    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    formatter.locale = Locale(identifier: "he_IL")
    return formatter.string(from: date)
}

private extension StoredCompletedInternalExamResult {
    func beltNameForArchive(isEnglish: Bool) -> String {
        isEnglish ? beltEn : beltHeb
    }
}

private func examTr(_ isEnglish: Bool, _ he: String, _ en: String) -> String {
    isEnglish ? en : he
}

private func examBeltNameForUi(_ belt: Belt, isEnglish: Bool) -> String {
    guard isEnglish else {
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

private func examTitleForUi(_ raw: String, isEnglish: Bool) -> String {
    let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    guard isEnglish else {
        return clean
    }

    return KmiEnglishTitleResolver.title(for: clean, isEnglish: true)
}

private func examStatusText(percent: Int, isEnglish: Bool) -> String {
    if isEnglish {
        switch percent {
        case 85...:
            return "Passed with excellence"
        case 70...:
            return "Passed"
        case 50...:
            return "Needs improvement"
        default:
            return "Did not pass"
        }
    } else {
        switch percent {
        case 85...:
            return "עבר בהצטיינות"
        case 70...:
            return "עבר"
        case 50...:
            return "נדרש שיפור"
        default:
            return "לא עבר"
        }
    }
}

private func examSummaryText(percent: Int, isEnglish: Bool) -> String {
    if isEnglish {
        switch percent {
        case 85...:
            return "Passed very successfully"
        case 70...:
            return "Passed successfully"
        case 50...:
            return "Average - needs improvement"
        default:
            return "Did not pass the exam"
        }
    } else {
        switch percent {
        case 85...:
            return "עבר בהצלחה רבה"
        case 70...:
            return "עבר בהצלחה"
        case 50...:
            return "בינוני – נדרש שיפור"
        default:
            return "לא עבר את המבחן"
        }
    }
}


// MARK: - UI Models
private struct ExamTopicGroup {
    let topic: String
    let items: [ExamExerciseItem]
}

private struct ExamExerciseItem: Identifiable, Hashable {
    let id: String
    let belt: Belt
    let topic: String
    let name: String
    var subTopic: String? = nil
}

private struct InternalExamSession {
    let traineeName: String
    let belt: Belt
    let date: Date
    let exercises: [ExamExerciseItem]
    let marks: [Int?]

    private var answeredMarks: [Int] {
        marks.compactMap { $0 }
    }

    var totalScore: Double {
        Double(answeredMarks.reduce(0, +))
    }

    var maxScore: Double {
        Double(answeredMarks.count * 10)
    }

    var percent: Int {
        guard maxScore > 0 else { return 0 }
        return Int((totalScore / maxScore) * 100.0)
    }

    var score10: Double {
        guard maxScore > 0 else { return 0 }
        return (totalScore / maxScore) * 10.0
    }

    func summaryText(isEnglish: Bool) -> String {
        examStatusText(percent: percent, isEnglish: isEnglish)
    }

    func shareText(isEnglish: Bool) -> String {
        let trainee = traineeName.isEmpty ? "—" : traineeName
        let beltName = examBeltNameForUi(belt, isEnglish: isEnglish)
        let status = summaryText(isEnglish: isEnglish)

        if isEnglish {
            return """
            Internal Exam Report
            Trainee: \(trainee)
            Belt: \(beltName)
            Score: \(score10.scoreString()) / 10 (\(percent)%)
            Status: \(status)
            """
        } else {
            return """
            דו״ח מבחן פנימי
            נבחן: \(trainee)
            חגורה: \(beltName)
            ציון: \(score10.scoreString()) / 10 (\(percent)%)
            סטטוס: \(status)
            """
        }
    }
}

private struct BeltScore {
    let total: Double
    let max: Double

    var percent: Int {
        guard max > 0 else { return 0 }
        return Int((total / max) * 100.0)
    }

    var score10: Double {
        guard max > 0 else { return 0 }
        return (total / max) * 10.0
    }
}

// MARK: - Components

private struct BeltSelectorView: View {
    @Binding var currentBelt: Belt
    let accent: Color
    let belt: Belt
    let isEnglish: Bool

    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        Menu {
            ForEach(belts, id: \.id) { belt in
                Button(examBeltNameForUi(belt, isEnglish: isEnglish)) {
                    currentBelt = belt
                }
            }
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    beltIcon

                    VStack(alignment: stackAlignment, spacing: 4) {
                        Text(examTr(isEnglish, "חגורה במבחן", "Exam belt"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))

                        Text(examBeltNameForUi(currentBelt, isEnglish: isEnglish))
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                    chevronIcon
                } else {
                    chevronIcon

                    VStack(alignment: stackAlignment, spacing: 4) {
                        Text(examTr(isEnglish, "חגורה במבחן", "Exam belt"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))

                        Text(examBeltNameForUi(currentBelt, isEnglish: isEnglish))
                            .font(.system(size: 21, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                    beltIcon
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [
                        beltDarkColor(for: belt).opacity(0.88),
                        accent.opacity(0.78),
                        Color.purple.opacity(0.72)
                    ],
                    startPoint: isEnglish ? .leading : .trailing,
                    endPoint: isEnglish ? .trailing : .leading
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 1.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: beltDarkColor(for: belt).opacity(0.22), radius: 9, x: 0, y: 5)
            .padding(.horizontal, 12)
        }
    }

    private var beltIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 44, height: 44)

            Image(systemName: "rosette")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    private var chevronIcon: some View {
        Image(systemName: "chevron.down.circle.fill")
            .font(.system(size: 23, weight: .heavy))
            .foregroundStyle(Color.white.opacity(0.88))
    }
}

private struct SummaryCardView: View {
    let currentBelt: Belt
    let marksMap: [String: Int]
    let isEnglish: Bool
    let isDarkMode: Bool
    let itemsProvider: (Belt) -> [ExamExerciseItem]

    @State private var expanded = false

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: isDarkMode ? .dark : .light)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: isDarkMode ? .dark : .light)
    }

    private var rowBackground: Color {
        KmiAppTheme.surfaceVariant(for: isDarkMode ? .dark : .light)
    }

    private var cardBackground: Color {
        KmiAppTheme.surface(for: isDarkMode ? .dark : .light)
    }

    var body: some View {
        let orderedBelts = beltsUpTo(currentBelt)

        let beltScores: [(Belt, BeltScore)] =
            orderedBelts.map { belt in
                let exercises = itemsProvider(belt)
                var total = 0.0
                var maximum = 0.0

                for exercise in exercises {
                    if let score = marksMap[exercise.id] {
                        maximum += 10
                        total += Double(
                            clampScore10(score)
                        )
                    }
                }

                return (
                    belt,
                    BeltScore(
                        total: total,
                        max: maximum
                    )
                )
            }

        let totalScore =
            beltScores.reduce(0.0) {
                $0 + $1.1.total
            }

        let maximumScore =
            beltScores.reduce(0.0) {
                $0 + $1.1.max
            }

        let totalScore10 =
            maximumScore == 0
            ? 0
            : (totalScore / maximumScore) * 10

        let percent =
            maximumScore == 0
            ? 0
            : Int(
                (totalScore / maximumScore) * 100
            )

        let answeredCount = marksMap.count

        let totalExercises =
            orderedBelts
                .flatMap {
                    itemsProvider($0)
                }
                .count

        return VStack(spacing: 8) {
            Button {
                withAnimation(
                    .easeInOut(duration: 0.18)
                ) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(
                        systemName:
                            expanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .kmiFont(
                        size: 14,
                        weight: .black
                    )
                    .foregroundStyle(
                        beltAccentColor(for: currentBelt)
                    )
                    .frame(width: 34, height: 34)
                    .background(rowBackground)
                    .clipShape(Circle())

                    VStack(
                        alignment:
                            isEnglish ? .leading : .trailing,
                        spacing: 3
                    ) {
                        Text(
                            examTr(
                                isEnglish,
                                "סיכום מבחן",
                                "Exam Summary"
                            )
                        )
                        .kmiFont(
                            size: 17,
                            weight: .black
                        )
                        .foregroundStyle(primaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )

                        Text(
                            isEnglish
                                ? "Average: \(totalScore10.scoreString()) / 10 (\(percent)%)"
                                : "מצטבר: \(totalScore10.scoreString()) / 10 (\(percent)%)"
                        )
                        .kmiFont(
                            size: 16,
                            weight: .black
                        )
                        .foregroundStyle(primaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )

                        Text(
                            isEnglish
                                ? "\(answeredCount) of \(totalExercises) exercises"
                                : "\(answeredCount) / \(totalExercises) תרגילים"
                        )
                        .kmiFont(
                            size: 13,
                            weight: .heavy
                        )
                        .foregroundStyle(secondaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )

                        Text(
                            examSummaryText(
                                percent: percent,
                                isEnglish: isEnglish
                            )
                        )
                        .kmiFont(
                            size: 14,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            statusColor(percent: percent)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )
                    }

                    miniBeltIcon
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(cardBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .stroke(
                        isDarkMode
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.60),
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: Color.black.opacity(
                        isDarkMode ? 0.28 : 0.12
                    ),
                    radius: 7,
                    x: 0,
                    y: 4
                )
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 6) {
                    ForEach(
                        beltScores,
                        id: \.0.id
                    ) { belt, score in
                        HStack(spacing: 10) {
                            Text(
                                "\(score.score10.scoreString()) / 10 (\(score.percent)%)"
                            )
                            .kmiFont(
                                size: 12,
                                weight: .black
                            )
                            .foregroundStyle(
                                statusColor(
                                    percent: score.percent
                                )
                            )

                            Spacer()

                            Text(
                                examBeltNameForUi(
                                    belt,
                                    isEnglish: isEnglish
                                )
                            )
                            .kmiFont(
                                size: 12,
                                weight: .heavy
                            )
                            .foregroundStyle(primaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(rowBackground)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var miniBeltIcon: some View {
        if let image = UIImage(
            named: beltImageName(for: currentBelt)
        ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 34)
                .rotationEffect(.degrees(-6))
        } else {
            Image(systemName: "rosette")
                .kmiFont(
                    size: 25,
                    weight: .black
                )
                .foregroundStyle(
                    beltAccentColor(for: currentBelt)
                )
                .frame(width: 54, height: 34)
        }
    }

    private func beltImageName(
        for belt: Belt
    ) -> String {
        switch belt {
        case .white:
            return "belt_white"

        case .yellow:
            return "belt_yellow"

        case .orange:
            return "belt_orange"

        case .green:
            return "belt_green"

        case .blue:
            return "belt_blue"

        case .brown:
            return "belt_brown"

        case .black:
            return "belt_black"

        default:
            return "belt_black"
        }
    }
}

private struct TopicHeaderView: View {
    let title: String
    let expanded: Bool
    let exerciseCount: Int
    let isEnglish: Bool
    let isDarkMode: Bool
    let belt: Belt
    let onTap: () -> Void

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var countText: String {
        isEnglish
            ? "\(exerciseCount) exercises"
            : "\(exerciseCount) תרגילים"
    }

    private var backgroundColor: Color {
        KmiAppTheme.surfaceVariant(for: isDarkMode ? .dark : .light)
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: isDarkMode ? .dark : .light)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: isDarkMode ? .dark : .light)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isEnglish {
                    chevron
                    topicLabels
                } else {
                    topicLabels
                    chevron
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(.horizontal, 9)
            .frame(height: 42)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .stroke(
                    expanded
                        ? beltAccentColor(for: belt)
                            .opacity(0.60)
                        : (
                            isDarkMode
                                ? Color.white.opacity(0.16)
                                : Color(
                                    red: 0.85,
                                    green: 0.89,
                                    blue: 0.96
                                )
                        ),
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.22 : 0.08
                ),
                radius: 2,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(.plain)
    }

    private var topicLabels: some View {
        VStack(
            alignment:
                isEnglish ? .leading : .trailing,
            spacing: 1
        ) {
            Text(title)
                .kmiFont(
                    size: 14,
                    weight: .black
                )
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(
                    maxWidth: .infinity,
                    alignment: frameAlignment
                )
                .multilineTextAlignment(textAlignment)

            Text(countText)
                .kmiFont(
                    size: 9.5,
                    weight: .semibold
                )
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(
                    maxWidth: .infinity,
                    alignment: frameAlignment
                )
                .multilineTextAlignment(textAlignment)
        }
    }

    private var chevron: some View {
        ZStack {
            Circle()
                .fill(
                    expanded
                        ? beltAccentColor(for: belt)
                        : (
                            isDarkMode
                                ? Color.white.opacity(0.22)
                                : Color(
                                    red: 0.42,
                                    green: 0.47,
                                    blue: 0.55
                                )
                        )
                )
                .frame(width: 23, height: 23)

            Image(
                systemName:
                    expanded
                    ? "chevron.up"
                    : "chevron.down"
            )
            .kmiFont(
                size: 9,
                weight: .black
            )
            .foregroundStyle(.white)
        }
    }
}

private struct ExerciseRowView: View {
    let name: String
    let score: Int?
    let isEnglish: Bool
    let isDarkMode: Bool
    let belt: Belt
    let onScoreChange: (Int?) -> Void

    private var scheme: ColorScheme {
        isDarkMode ? .dark : .light
    }

    private let scoreColumns: [GridItem] = Array(
        repeating: GridItem(
            .flexible(minimum: 32, maximum: 44),
            spacing: 6,
            alignment: .center
        ),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .kmiTypography(.secondary)
                .fontWeight(.black)
                .foregroundStyle(KmiAppTheme.onSurface(for: scheme))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: scoreColumns, alignment: .center, spacing: 6) {
                ForEach(1...10, id: \.self) { value in
                    ScoreChipView(
                        value: value,
                        selected: score == value
                    ) {
                        onScoreChange(score == value ? nil : value)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            KmiAppTheme.surface(for: scheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    KmiAppTheme.outlineVariant(for: scheme),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
    }
}

private struct ScoreChipView: View {
    let value: Int
    let selected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let base = scoreColor(value)
        let foreground: Color = selected
            ? (value <= 3 ? .white : .black)
            : KmiAppTheme.onSurface(for: colorScheme)

        Button(action: onTap) {
            Text("\(value)")
                .kmiTypography(.caption)
                .fontWeight(.black)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    base.opacity(selected ? 0.95 : 0.20),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            selected
                                ? base
                                : KmiAppTheme.outlineVariant(for: colorScheme),
                            lineWidth: selected ? 2 : 1
                        )
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct BottomActionBarView: View {
    let session: InternalExamSession
    let isEnglish: Bool
    let onSave: () -> Void
    let onChangeBelt: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSave) {
                Text(examTr(isEnglish, "סיום מבחן", "Finish exam"))
                    .kmiFont(
                        size: 17,
                        weight: .black
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.21, blue: 0.84),
                                Color(red: 0.49, green: 0.23, blue: 0.93),
                                Color(red: 0.55, green: 0.36, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 4)

            Button(action: onChangeBelt) {
                HStack(spacing: 10) {
                    Text(examTr(isEnglish, "מעבר לחגורה אחרת", "Change Belt"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "rosette")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.62, green: 0.38, blue: 0.08),
                            Color(red: 0.90, green: 0.68, blue: 0.18),
                            Color(red: 0.55, green: 0.20, blue: 0.90)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 5)
        .background(beltSoftColor(for: session.belt).opacity(0.58))
    }
}

// MARK: - Helpers

private func clampScore10(_ value: Int) -> Int {
    min(max(value, 0), 10)
}

private func beltsUpTo(_ target: Belt) -> [Belt] {
    let all: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]
    guard let idx = all.firstIndex(where: { $0.id == target.id }) else { return all }
    return Array(all.prefix(idx + 1))
}

private func scoreColor(_ value: Int) -> Color {
    let v = min(max(value, 0), 10)
    let tLinear = Double(v) / 10.0
    let t = tLinear * tLinear
    let hue = 120.0 * t / 360.0
    let saturation = 0.90
    let brightnessBase = 0.92
    let brightness = min(max(brightnessBase - (0.08 * (1.0 - tLinear)), 0.78), 0.95)
    return Color(hue: hue, saturation: saturation, brightness: brightness)
}

private func statusColor(percent: Int) -> Color {
    switch percent {
    case 85...:
        return Color.green
    case 70...:
        return Color(red: 0.44, green: 0.68, blue: 0.08)
    case 50...:
        return Color.orange
    default:
        return Color.red
    }
}

private func beltAccentColor(for belt: Belt) -> Color {
    switch belt {
    case .white: return Color.gray.opacity(0.55)
    case .yellow: return Color.orange.opacity(0.85)
    case .orange: return Color.orange.opacity(0.95)
    case .green: return Color.green.opacity(0.75)
    case .blue: return Color.blue.opacity(0.70)
    case .brown: return Color(red: 0.55, green: 0.35, blue: 0.20).opacity(0.85)
    case .black: return Color.black.opacity(0.75)
    default: return Color.black.opacity(0.25)
    }
}

private func beltSoftColor(for belt: Belt) -> Color {
    switch belt {
    case .white:
        return Color(red: 0.94, green: 0.96, blue: 0.98)
    case .yellow:
        return Color(red: 1.00, green: 0.98, blue: 0.80)
    case .orange:
        return Color(red: 1.00, green: 0.91, blue: 0.78)
    case .green:
        return Color(red: 0.84, green: 0.96, blue: 0.88)
    case .blue:
        return Color(red: 0.84, green: 0.91, blue: 1.00)
    case .brown:
        return Color(red: 0.94, green: 0.86, blue: 0.74)
    case .black:
        return Color(red: 0.88, green: 0.90, blue: 0.94)
    default:
        return Color(red: 0.93, green: 0.91, blue: 1.00)
    }
}

private func beltDarkColor(for belt: Belt) -> Color {
    switch belt {
    case .white:
        return Color(red: 0.38, green: 0.42, blue: 0.50)
    case .yellow:
        return Color(red: 0.58, green: 0.36, blue: 0.05)
    case .orange:
        return Color(red: 0.66, green: 0.25, blue: 0.05)
    case .green:
        return Color(red: 0.04, green: 0.32, blue: 0.23)
    case .blue:
        return Color(red: 0.10, green: 0.23, blue: 0.54)
    case .brown:
        return Color(red: 0.28, green: 0.13, blue: 0.07)
    case .black:
        return Color(red: 0.02, green: 0.03, blue: 0.06)
    default:
        return Color(red: 0.20, green: 0.18, blue: 0.50)
    }
}

// MARK: - Persistence

private struct InternalExamScope: Equatable, Sendable {
    let coachUid: String
    let branch: String
    let group: String

    var isCurrentUser: Bool {
        internalExamCoachUid() == coachUid
    }

    var cacheKey: String {
        let value = [coachUid, branch, group]
            .map { "\($0.utf8.count):\($0)" }
            .joined()

        return Data(value.utf8).base64EncodedString()
    }

    func localKey(_ base: String) -> String {
        "\(base).scope.\(cacheKey)"
    }

    func matches(_ data: [String: Any]) -> Bool {
        (data["coachUid"] as? String) == coachUid &&
        (data["branch"] as? String ?? "").trimmed() == branch &&
        (data["group"] as? String ?? "").trimmed() == group
    }

    func recentDocumentId(_ name: String) -> String {
        "\(Self.part(branch))_\(Self.part(group))_\(internalExamTraineeKey(name))"
    }

    static func part(_ value: String) -> String {
        value.trimmed()
            .lowercased()
            .replacingOccurrences(
                of: "[^a-z0-9א-ת]+",
                with: "_",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "_")
            )
    }
}

private enum InternalExamScopeError: Error {
    case accountChanged
    case invalidScope
}

private struct InternalExamLoadedDraft: Sendable {
    let marks: [String: Int]
    let isLegacy: Bool
}

private func scopedFetchRecentTrainees(
    scope: InternalExamScope,
    completion: @escaping (Result<[String], Error>) -> Void
) {
    guard scope.isCurrentUser else {
        completion(.failure(InternalExamScopeError.accountChanged))
        return
    }

    Firestore.firestore()
        .collection(InternalExamStore.recentTraineesCollection)
        .document(scope.coachUid)
        .collection(InternalExamStore.traineesSubcollection)
        .getDocuments { snapshot, error in
            guard scope.isCurrentUser else {
                completion(
                    .failure(InternalExamScopeError.accountChanged)
                )
                return
            }

            if let error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(
                    .failure(InternalExamScopeError.invalidScope)
                )
                return
            }

            let rows = documents.compactMap { doc -> (String, Int64)? in
                let data = doc.data()

                let legacy =
                    (data["branch"] as? String ?? "").trimmed().isEmpty &&
                    (data["group"] as? String ?? "").trimmed().isEmpty &&
                    data["coachUid"] as? String == scope.coachUid

                guard scope.matches(data) || legacy,
                      let name = (data["name"] as? String)?.trimmed(),
                      !name.isEmpty else {
                    return nil
                }

                return (
                    name,
                    (data["updatedAtMillis"] as? NSNumber)?.int64Value ?? 0
                )
            }
            .sorted { $0.1 > $1.1 }

            var seen = Set<String>()

            let names = Array(
                rows.map(\.0)
                    .filter {
                        seen.insert($0.lowercased()).inserted
                    }
                    .prefix(20)
            )

            UserDefaults.standard.set(
                names,
                forKey: scope.localKey(InternalExamStore.recentKey)
            )

            completion(.success(names))
        }
}

private enum InternalExamStore {
    static let draftsKey = "kmi_internal_exam_drafts"
    static let recentKey = "kmi_internal_exam_recent_trainees"
    static let lastKey = "kmi_internal_exam_last_trainee"
    static let completedResultsKey = "kmi_internal_exam_completed_results"

    static let draftsCollection = "internalExamDrafts"
    static let completedResultsCollection = "internalExamResults"
    static let recentTraineesCollection = "internalExamRecentTrainees"
    static let coachStateCollection = "internalExamCoachState"
    static let traineesSubcollection = "trainees"

    static let draftStatus = "draft"
    static let completedStatus = "completed"
    static let completedSource = "ios_internal_exam"
}

private struct StoredCompletedInternalExamResult: Codable {
    let resultId: String
    let traineeName: String
    let traineeKey: String
    let beltId: String
    let beltHeb: String
    let beltEn: String
    let completedAtMillis: Int64
    let totalScore: Double
    let maxScore: Double
    let score10: Double
    let percent: Int
    let summaryTextHe: String
    let summaryTextEn: String
    let shareSummaryHe: String
    let shareSummaryEn: String
    let answeredExercises: [StoredCompletedInternalExamExercise]
    var branch: String? = nil
    var group: String? = nil

    var isUnassigned: Bool {
        (branch ?? "").trimmed().isEmpty &&
        (group ?? "").trimmed().isEmpty
    }
}

private struct StoredCompletedInternalExamExercise: Codable {
    let exerciseId: String
    let beltId: String
    let beltHeb: String
    let beltEn: String
    let topic: String
    let subTopic: String
    let name: String
    let score: Int
}

private func internalExamItemsForPersistence(for belt: Belt) -> [ExamExerciseItem] {
    let categorized = ExamDataSource.categorizedItemsForBelt(belt)

    return categorized.enumerated().map { index, item in
        ExamExerciseItem(
            id: "\(belt.id)_\(item.topic)_\(item.name)_\(index)",
            belt: belt,
            topic: item.topic,
            name: item.name,
            subTopic: item.subTopic
        )
    }
}

private func internalExamItemsForPersistence(upTo belt: Belt) -> [ExamExerciseItem] {
    let allExercises = beltsUpTo(belt)
        .flatMap { internalExamItemsForPersistence(for: $0) }

    return Array(
        Dictionary(grouping: allExercises, by: { $0.id })
            .compactMap { $0.value.first }
    )
}

private func internalExamCoachUid() -> String? {
    Auth.auth().currentUser?.uid
}

private func internalExamTraineeKey(_ name: String) -> String {
    let clean = name
        .trimmed()
        .lowercased()

    let mapped = clean.map { char -> Character in
        if char.isLetter || char.isNumber {
            return char
        }

        return "_"
    }

    let normalized = String(mapped)
        .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

    return normalized.isEmpty ? "unknown_trainee" : normalized
}

private func internalExamDraftId(
    coachUid: String,
    traineeName: String,
    belt: Belt,
    scope: InternalExamScope
) -> String {
    "\(coachUid)_\(InternalExamScope.part(scope.branch))_\(InternalExamScope.part(scope.group))_\(belt.id.uppercased())_\(internalExamTraineeKey(traineeName))"
}

private func scopedSaveExamDraft(
    traineeName: String,
    belt: Belt,
    marksMap: [String: Int],
    scope: InternalExamScope,
    completion: @escaping (Bool) -> Void
) {
    let cleanName = traineeName.trimmed()

    guard !cleanName.isEmpty, scope.isCurrentUser else {
        completion(false)
        return
    }

    let coachUid = scope.coachUid

    let safeMarks = Dictionary(
        uniqueKeysWithValues: marksMap
            .filter { !$0.key.trimmed().isEmpty }
            .map { key, value in
                (key, clampScore10(value))
            }
    )

    let draftExercises = internalExamItemsForPersistence(upTo: belt)

    let draftSession = InternalExamSession(
        traineeName: cleanName,
        belt: belt,
        date: Date(),
        exercises: draftExercises,
        marks: draftExercises.map { safeMarks[$0.id] }
    )

    let docId = internalExamDraftId(
        coachUid: coachUid,
        traineeName: cleanName,
        belt: belt,
        scope: scope
    )

    let data: [String: Any] = [
        "examId": docId,
        "coachUid": coachUid,
        "branch": scope.branch,
        "group": scope.group,
        "traineeName": cleanName,
        "traineeKey": internalExamTraineeKey(cleanName),
        "belt": belt.id.uppercased(),
        "beltHeb": belt.heb,
        "beltEn": examBeltNameForUi(belt, isEnglish: true),
        "status": InternalExamStore.draftStatus,
        "marks": safeMarks,
        "totalScore": draftSession.totalScore,
        "maxScore": draftSession.maxScore,
        "percent": draftSession.percent,
        "summaryTextHe": examStatusText(
            percent: draftSession.percent,
            isEnglish: false
        ),
        "summaryTextEn": examStatusText(
            percent: draftSession.percent,
            isEnglish: true
        ),
        "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
        "updatedAt": FieldValue.serverTimestamp()
    ]

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .setData(data) { error in
            completion(error == nil && scope.isCurrentUser)
        }
}

private func scopedLoadExamDraft(
    traineeName: String,
    belt: Belt,
    scope: InternalExamScope,
    completion: @escaping (Result<InternalExamLoadedDraft, Error>) -> Void
) {
    let cleanName = traineeName.trimmed()

    guard !cleanName.isEmpty, scope.isCurrentUser else {
        completion(.failure(InternalExamScopeError.accountChanged))
        return
    }

    let docId = internalExamDraftId(
        coachUid: scope.coachUid,
        traineeName: cleanName,
        belt: belt,
        scope: scope
    )

    func parsedMarks(_ data: [String: Any]) -> [String: Int] {
        (data["marks"] as? [String: Any] ?? [:])
            .reduce(into: [String: Int]()) { result, pair in
                guard !pair.key.trimmed().isEmpty else {
                    return
                }

                if let number = pair.value as? NSNumber {
                    result[pair.key] = clampScore10(number.intValue)
                } else if let text = pair.value as? String,
                          let number = Int(text) {
                    result[pair.key] = clampScore10(number)
                }
            }
    }

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .getDocument { snapshot, error in
            guard scope.isCurrentUser else {
                completion(
                    .failure(InternalExamScopeError.accountChanged)
                )
                return
            }

            if let error {
                completion(.failure(error))
                return
            }

            if let data = snapshot?.data() {
                guard scope.matches(data) else {
                    completion(
                        .failure(InternalExamScopeError.invalidScope)
                    )
                    return
                }

                completion(
                    .success(
                        InternalExamLoadedDraft(
                            marks: parsedMarks(data),
                            isLegacy: false
                        )
                    )
                )
                return
            }

            let legacyId =
                "\(scope.coachUid)_\(belt.id)_\(internalExamTraineeKey(cleanName))"

            Firestore.firestore()
                .collection(InternalExamStore.draftsCollection)
                .document(legacyId)
                .getDocument { oldSnapshot, oldError in
                    guard scope.isCurrentUser else {
                        completion(
                            .failure(InternalExamScopeError.accountChanged)
                        )
                        return
                    }

                    if let oldError {
                        completion(.failure(oldError))
                        return
                    }

                    guard let data = oldSnapshot?.data(),
                          data["coachUid"] as? String == scope.coachUid,
                          (data["branch"] as? String ?? "").trimmed().isEmpty,
                          (data["group"] as? String ?? "").trimmed().isEmpty,
                          (data["traineeName"] as? String ?? "")
                            .trimmed()
                            .lowercased() == cleanName.lowercased() else {
                        completion(
                            .success(
                                InternalExamLoadedDraft(
                                    marks: [:],
                                    isLegacy: false
                                )
                            )
                        )
                        return
                    }

                    completion(
                        .success(
                            InternalExamLoadedDraft(
                                marks: parsedMarks(data),
                                isLegacy: true
                            )
                        )
                    )
                }
        }
}

private func scopedRemoveExamDraft(
    traineeName: String,
    belt: Belt,
    scope: InternalExamScope
) {
    let cleanName = traineeName.trimmed()

    guard !cleanName.isEmpty, scope.isCurrentUser else {
        return
    }

    let docId = internalExamDraftId(
        coachUid: scope.coachUid,
        traineeName: cleanName,
        belt: belt,
        scope: scope
    )

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .delete()
}

private func scopedSaveCompletedExamResult(
    session: InternalExamSession,
    marksMap: [String: Int],
    scope: InternalExamScope,
    completion: @escaping (Bool) -> Void
) {
    let cleanName = session.traineeName.trimmed()

    guard !cleanName.isEmpty, scope.isCurrentUser else {
        completion(false)
        return
    }

    let coachUid = scope.coachUid
    let db = Firestore.firestore()

    let docRef = db
        .collection(InternalExamStore.completedResultsCollection)
        .document()

    let resultId = docRef.documentID
    let completedAtMillis = Int64(Date().timeIntervalSince1970 * 1000)
    let traineeKey = internalExamTraineeKey(cleanName)

    let answeredExercises: [[String: Any]] = session.exercises.compactMap { exercise in
        guard let score = marksMap[exercise.id] else {
            return nil
        }

        return [
            "exerciseId": exercise.id,
            "belt": exercise.belt.id.uppercased(),
            "beltHeb": exercise.belt.heb,
            "beltEn": examBeltNameForUi(
                exercise.belt,
                isEnglish: true
            ),
            "topic": exercise.topic,
            "subTopic": exercise.subTopic ?? "",
            "name": exercise.name,
            "score": clampScore10(score)
        ]
    }

    let safeMarks = Dictionary(
        uniqueKeysWithValues: marksMap
            .filter { !$0.key.trimmed().isEmpty }
            .map { key, value in
                (key, clampScore10(value))
            }
    )

    let data: [String: Any] = [
        "resultId": resultId,
        "coachUid": coachUid,
        "branch": scope.branch,
        "group": scope.group,

        "traineeName": cleanName,
        "traineeKey": traineeKey,

        "belt": session.belt.id.uppercased(),
        "beltHeb": session.belt.heb,
        "beltEn": examBeltNameForUi(session.belt, isEnglish: true),

        "status": InternalExamStore.completedStatus,

        "marks": safeMarks,
        "answeredExercises": answeredExercises,
        "answeredCount": answeredExercises.count,
        "totalExerciseCount": session.exercises.count,

        "totalScore": session.totalScore,
        "maxScore": session.maxScore,
        "score10": session.score10,
        "percent": session.percent,

        "summaryTextHe": examStatusText(
            percent: session.percent,
            isEnglish: false
        ),
        "summaryTextEn": examStatusText(
            percent: session.percent,
            isEnglish: true
        ),
        "shareSummaryHe": session.shareText(isEnglish: false),
        "shareSummaryEn": session.shareText(isEnglish: true),

        "completedAtMillis": completedAtMillis,
        "completedAt": FieldValue.serverTimestamp(),

        "source": InternalExamStore.completedSource
    ]

    docRef.setData(data, merge: true) { error in
        completion(error == nil && scope.isCurrentUser)
    }
}

private func scopedLoadCompletedExamResults(
    scope: InternalExamScope
) -> [StoredCompletedInternalExamResult] {
    guard scope.isCurrentUser else {
        return []
    }

    guard let data = UserDefaults.standard.data(
        forKey: scope.localKey(InternalExamStore.completedResultsKey)
    ),
    let decoded = try? JSONDecoder().decode(
        [StoredCompletedInternalExamResult].self,
        from: data
    ) else {
        return []
    }

    return decoded
}

private func scopedRemoveRecentTraineeAfterCompletion(
    _ name: String,
    scope: InternalExamScope
) {
    let clean = name.trimmed()

    guard !clean.isEmpty, scope.isCurrentUser else {
        return
    }

    let list = scopedLoadRecentTrainees(scope: scope).filter {
        $0.trimmed().lowercased() != clean.lowercased()
    }

    UserDefaults.standard.set(
        list,
        forKey: scope.localKey(InternalExamStore.recentKey)
    )

    Firestore.firestore()
        .collection(InternalExamStore.recentTraineesCollection)
        .document(scope.coachUid)
        .collection(InternalExamStore.traineesSubcollection)
        .document(scope.recentDocumentId(clean))
        .delete()
}

private func scopedLoadRecentTrainees(
    scope: InternalExamScope
) -> [String] {
    guard scope.isCurrentUser else {
        return []
    }

    return UserDefaults.standard.stringArray(
        forKey: scope.localKey(InternalExamStore.recentKey)
    ) ?? []
}

private func scopedPushRecentTrainee(
    _ name: String,
    scope: InternalExamScope,
    limit: Int = 20
) {
    let clean = name.trimmed()

    guard !clean.isEmpty, scope.isCurrentUser else {
        return
    }

    var list = scopedLoadRecentTrainees(scope: scope).filter {
        $0.trimmed().lowercased() != clean.lowercased()
    }

    list.insert(clean, at: 0)

    if list.count > limit {
        list = Array(list.prefix(limit))
    }

    UserDefaults.standard.set(
        list,
        forKey: scope.localKey(InternalExamStore.recentKey)
    )

    let traineeKey = internalExamTraineeKey(clean)

    Firestore.firestore()
        .collection(InternalExamStore.recentTraineesCollection)
        .document(scope.coachUid)
        .collection(InternalExamStore.traineesSubcollection)
        .document(scope.recentDocumentId(clean))
        .setData(
            [
                "name": clean,
                "traineeKey": traineeKey,
                "coachUid": scope.coachUid,
                "branch": scope.branch,
                "group": scope.group,
                "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
}

private func scopedSaveLastTrainee(
    _ name: String,
    scope: InternalExamScope
) {
    let clean = name.trimmed()

    guard !clean.isEmpty, scope.isCurrentUser else {
        return
    }

    UserDefaults.standard.set(
        clean,
        forKey: scope.localKey(InternalExamStore.lastKey)
    )

    Firestore.firestore()
        .collection(InternalExamStore.coachStateCollection)
        .document(scope.coachUid)
        .setData(
            [
                "branch": scope.branch,
                "group": scope.group,
                "lastTraineeName": clean,
                "lastTraineeKey": internalExamTraineeKey(clean),
                "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
}

// MARK: - String / Number utils

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ifBlank(_ fallback: String) -> String {
        trimmed().isEmpty ? fallback : self
    }
}

private extension Double {
    func scoreString() -> String {
        if self == 0 { return "0" }
        let intValue = Int(self)
        if abs(self - Double(intValue)) < 0.000001 {
            return "\(intValue)"
        }
        return String(format: "%.1f", self)
    }
}
