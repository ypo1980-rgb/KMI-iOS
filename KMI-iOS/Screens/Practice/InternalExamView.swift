import SwiftUI
import Shared
import FirebaseAuth
import FirebaseFirestore

struct InternalExamView: View {
    let belt: Belt

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var coach = CoachService.shared
    @State private var currentBelt: Belt
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

    private var shouldShowContinueExamButton: Bool {
        !marksMap.isEmpty || !pendingLoadedDraft.isEmpty
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

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var examPanelColor: Color {
        isDarkMode
            ? Color(
                red: 0.055,
                green: 0.075,
                blue: 0.120
            )
            : Color.white.opacity(0.96)
    }

    private var examFieldColor: Color {
        isDarkMode
            ? Color(
                red: 0.080,
                green: 0.105,
                blue: 0.165
            )
            : Color.white
    }

    private var examPrimaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(
                red: 0.10,
                green: 0.14,
                blue: 0.22
            )
    }

    private var examSecondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color(
                red: 0.42,
                green: 0.48,
                blue: 0.58
            )
    }

    private var examPanelBorderColor: Color {
        isDarkMode
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.10)
    }

    private var examFieldBorderColor: Color {
        isDarkMode
            ? beltAccentColor(for: currentBelt)
                .opacity(0.42)
            : Color(
                red: 0.76,
                green: 0.63,
                blue: 0.45
            )
            .opacity(0.65)
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

                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)

                        Text(
                            tr(
                                "בודק הרשאות…",
                                "Checking permissions…"
                            )
                        )
                        .kmiFont(
                            size: 15,
                            weight: .black
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .fill(Color.black.opacity(0.24))
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 22,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                    )
                }
            } else if coach.isCoach {
                examContent
            } else {
                ZStack {
                    androidExamBackground

                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .kmiFont(
                                size: 32,
                                weight: .black
                            )
                            .foregroundStyle(
                                Color(
                                    red: 1.00,
                                    green: 0.82,
                                    blue: 0.18
                                )
                            )

                        Text(
                            tr(
                                "גישה למאמנים בלבד",
                                "Coach access only"
                            )
                        )
                        .kmiFont(
                            size: 20,
                            weight: .black
                        )
                        .foregroundStyle(.white)
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
                        .kmiFont(
                            size: 13,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            .white.opacity(0.76)
                        )
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
                        .fill(Color.black.opacity(0.30))
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .task {
            await coach.checkCoach(userRole: auth.userRole)
            bootstrapInitialState()
        }
        .onChange(of: traineeName) { _, _ in
            recentTrainees = loadRecentTrainees()
        }
        .onChange(of: currentBelt) { _, _ in
            expandedTopic = nil
            checkForDraft()
        }

        .navigationBarBackButtonHidden(true)

        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hasUnsavedChanges {
                        showExitDialog = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: isEnglish ? "chevron.left" : "chevron.right")
                }
            }
        }

        .navigationBarTitleDisplayMode(.inline)

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

                hasUnsavedChanges = false
                dismiss()
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
        completion: @escaping ([StoredCompletedInternalExamResult]) -> Void
    ) {
        guard let coachUid = internalExamCoachUid() else {
            completion([])
            return
        }

        Firestore.firestore()
            .collection(InternalExamStore.completedResultsCollection)
            .whereField("coachUid", isEqualTo: coachUid)
            .limit(to: 80)
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let results: [StoredCompletedInternalExamResult] = documents.compactMap { doc in
                    let data = doc.data()

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
                        resultId: ((data["resultId"] as? String) ?? doc.documentID).trimmed(),
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
                        answeredExercises: answeredExercises
                    )
                }
                .sorted { $0.completedAtMillis > $1.completedAtMillis }

                completion(results)
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
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.08, blue: 0.15),
                Color(red: 0.03, green: 0.20, blue: 0.32),
                Color(red: 0.03, green: 0.48, blue: 0.64),
                Color(red: 0.03, green: 0.18, blue: 0.30)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
                        .frame(height: 54)
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
                        .frame(height: 54)
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
        VStack(spacing: 0) {
            Text(
                tr(
                    "בחר נבחן וחגורה לפני\nתחילת המבחן",
                    "Choose trainee and belt\nbefore starting the exam"
                )
            )
            .kmiFont(
                size: 21,
                weight: .black
            )
            .foregroundStyle(examPrimaryTextColor)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                examFieldColor.opacity(
                    isDarkMode ? 0.88 : 0.92
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
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
                isDarkMode ? 0.30 : 0.14
            ),
            radius: 7,
            x: 0,
            y: 4
        )
    }

    private var androidStartCard: some View {
        VStack(spacing: 14) {
            androidNameField

            androidBeltPicker

            androidStartButton

            androidSaveShareRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
                isDarkMode ? 0.34 : 0.18
            ),
            radius: 12,
            x: 0,
            y: 7
        )
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
                    .kmiFont(
                        size: 18,
                        weight: .heavy
                    )
                    .foregroundStyle(examPrimaryTextColor)
                    .multilineTextAlignment(
                        isEnglish ? .leading : .trailing
                    )
                    .submitLabel(.done)
                        .onSubmit {
                            _ = commitTraineeNameAndCollapse()
                            isTypingNewTraineeName = false
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 66)
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
                    .frame(height: 66)
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
        Menu {
            ForEach(
                [
                    Belt.yellow,
                    .orange,
                    .green,
                    .blue,
                    .brown,
                    .black
                ],
                id: \.id
            ) { picked in
                Button(
                    examBeltNameForUi(
                        picked,
                        isEnglish: isEnglish
                    )
                ) {
                    currentBelt = picked
                    expandedTopic = nil
                    pendingLoadedDraft.removeAll()
                    resumeCheckedKey = nil
                    checkForDraft()
                }
            }
        } label: {
            HStack(spacing: 12) {
                if isEnglish {
                    androidBeltImage
                }

                VStack(
                    alignment:
                        isEnglish ? .leading : .trailing,
                    spacing: 2
                ) {
                    Text(
                        tr(
                            "חגורה במבחן",
                            "Exam belt"
                        )
                    )
                    .kmiFont(
                        size: 13,
                        weight: .bold
                    )
                    .foregroundStyle(examSecondaryTextColor)

                    Text(
                        examBeltNameForUi(
                            currentBelt,
                            isEnglish: isEnglish
                        )
                    )
                    .kmiFont(
                        size: 21,
                        weight: .black
                    )
                    .foregroundStyle(
                        beltAccentColor(for: currentBelt)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish ? .leading : .trailing
                )

                Image(systemName: "chevron.down")
                    .kmiFont(
                        size: 12,
                        weight: .black
                    )
                    .foregroundStyle(
                        beltAccentColor(for: currentBelt)
                    )
                    .frame(width: 34, height: 34)
                    .background(
                        beltAccentColor(for: currentBelt)
                            .opacity(0.15)
                    )
                    .clipShape(Circle())

                if !isEnglish {
                    androidBeltImage
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 90)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(examFieldColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    beltAccentColor(for: currentBelt)
                        .opacity(0.40),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color:
                    beltAccentColor(for: currentBelt)
                        .opacity(0.22),
                radius: 7,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var androidBeltImage: some View {
        if let image = UIImage(named: androidBeltImageName(for: currentBelt)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 98, height: 58)
                .rotationEffect(.degrees(-7))
                .shadow(color: beltAccentColor(for: currentBelt).opacity(0.40), radius: 5, x: 0, y: 3)
        } else {
            Image(systemName: "rosette")
                .kmiFont(
                    size: 42,
                    weight: .black
                )
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
                Text(
                    shouldShowContinueExamButton
                        ? tr(
                            "המשך מבחן",
                            "Continue Exam"
                        )
                        : tr(
                            "התחל מבחן",
                            "Start Exam"
                        )
                )
                .kmiFont(
                    size: 23,
                    weight: .black
                )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(
                    systemName:
                        shouldShowContinueExamButton
                        ? (
                            isEnglish
                                ? "forward.fill"
                                : "backward.fill"
                        )
                        : "play.fill"
                )
                .kmiFont(
                    size: 17,
                    weight: .black
                )
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.66, green: 0.36, blue: 0.05),
                        Color(red: 1.00, green: 0.82, blue: 0.18),
                        Color(red: 0.62, green: 0.25, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var androidSaveShareRow: some View {
        HStack(spacing: 10) {
            Button {
                shareSummaryText()
            } label: {
                Text(tr("שתף", "Share"))
                    .kmiFont(
                        size: 18,
                        weight: .black
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.72, blue: 0.94),
                                Color(red: 0.16, green: 0.41, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                saveDraftFromAndroidPanel()
            } label: {
                Text(tr("שמור", "Save"))
                    .kmiFont(
                        size: 18,
                        weight: .black
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.41, green: 0.23, blue: 0.93),
                                Color(red: 0.61, green: 0.21, blue: 0.89)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var androidArchiveButton: some View {
        Button {
            openCompletedExamArchive()
        } label: {
            HStack(spacing: 10) {
                Text(tr("ארכיון מבחנים", "Exam Archive"))
                    .kmiFont(
                        size: 19,
                        weight: .black
                    )
                    .foregroundStyle(.white)

                Image(systemName: "books.vertical.fill")
                    .kmiFont(
                        size: 17,
                        weight: .black
                    )
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.37, blue: 1.0),
                                Color(red: 0.12, green: 0.76, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.09, blue: 0.17),
                        Color(red: 0.16, green: 0.20, blue: 0.34),
                        Color(red: 0.44, green: 0.16, blue: 0.88)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
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
                            ForEach(group.items) { item in
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
                                            marksMap[item.id] =
                                                clampScore10(
                                                    newScore
                                                )
                                        } else {
                                            marksMap.removeValue(
                                                forKey: item.id
                                            )
                                        }

                                        let cleanName =
                                            traineeName.trimmed()

                                        if !cleanName.isEmpty {
                                            saveExamDraft(
                                                traineeName:
                                                    cleanName,
                                                belt: currentBelt,
                                                marksMap: marksMap
                                            )

                                            pushRecentTrainee(
                                                cleanName
                                            )

                                            saveLastTrainee(
                                                cleanName
                                            )
                                        }
                                    }
                                )
                                .padding(.horizontal, 10)
                            }
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
                    .kmiFont(
                        size: 13,
                        weight: .black
                    )
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
                .kmiFont(
                    size: 17,
                    weight: .black
                )
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
                .kmiFont(
                    size: 12,
                    weight: .bold
                )
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
        LinearGradient(
            colors:
                isDarkMode
                ? [
                    Color(
                        red: 0.020,
                        green: 0.035,
                        blue: 0.075
                    ),
                    beltDarkColor(for: currentBelt)
                        .opacity(0.74),
                    Color(
                        red: 0.035,
                        green: 0.055,
                        blue: 0.105
                    ),
                    beltAccentColor(for: currentBelt)
                        .opacity(0.30)
                ]
                : [
                    Color.white.opacity(0.98),
                    beltSoftColor(for: currentBelt)
                        .opacity(0.98),
                    Color.white.opacity(0.96),
                    beltSoftColor(for: currentBelt)
                        .opacity(0.88)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(
            LinearGradient(
                colors: [
                    beltAccentColor(for: currentBelt)
                        .opacity(isDarkMode ? 0.18 : 0.10),
                    Color.clear,
                    beltDarkColor(for: currentBelt)
                        .opacity(isDarkMode ? 0.24 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
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
                LinearGradient(
                    colors:
                        isDarkMode
                        ? [
                            Color(
                                red: 0.020,
                                green: 0.035,
                                blue: 0.075
                            ),
                            Color(
                                red: 0.040,
                                green: 0.075,
                                blue: 0.140
                            ),
                            Color(
                                red: 0.025,
                                green: 0.045,
                                blue: 0.090
                            )
                        ]
                        : [
                            Color(
                                red: 0.95,
                                green: 0.97,
                                blue: 1.00
                            ),
                            Color(
                                red: 0.88,
                                green: 0.94,
                                blue: 1.00
                            ),
                            Color(
                                red: 0.96,
                                green: 0.94,
                                blue: 1.00
                            )
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if isLoadingExamArchive {
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(
                                Color(
                                    red: 0.486,
                                    green: 0.302,
                                    blue: 1.000
                                )
                            )

                        Text(
                            tr(
                                "טוען ארכיון מבחנים…",
                                "Loading exam archive…"
                            )
                        )
                        .kmiFont(
                            size: 15,
                            weight: .bold
                        )
                        .foregroundStyle(
                            examSecondaryTextColor
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
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
                            examPanelBorderColor,
                            lineWidth: 1
                        )
                    )

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
        .background(
            LinearGradient(
                colors:
                    isDarkMode
                    ? [
                        Color(
                            red: 0.020,
                            green: 0.035,
                            blue: 0.075
                        ),
                        Color(
                            red: 0.035,
                            green: 0.065,
                            blue: 0.125
                        )
                    ]
                    : [
                        Color(
                            red: 0.95,
                            green: 0.96,
                            blue: 0.99
                        ),
                        Color(
                            red: 0.90,
                            green: 0.95,
                            blue: 1.00
                        )
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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
        completedExamResults = []
        isLoadingExamArchive = true
        showExamArchiveSheet = true

        loadCompletedInternalExamResultsFromFirestore { results in
            DispatchQueue.main.async {
                completedExamResults = results
                isLoadingExamArchive = false
            }
        }
    }

    private func deleteCompletedExamResult(
        _ result: StoredCompletedInternalExamResult
    ) {
        guard !isDeletingExamResult else {
            return
        }

        let resultId =
            result.resultId
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !resultId.isEmpty else {
            examResultToDelete = nil

            examActionMessage = tr(
                "לא ניתן למחוק את המבחן משום שמזהה התוצאה חסר.",
                "The exam cannot be deleted because its result identifier is missing."
            )

            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        isDeletingExamResult = true

        Firestore.firestore()
            .collection(
                InternalExamStore
                    .completedResultsCollection
            )
            .document(resultId)
            .delete { error in
                DispatchQueue.main.async {
                    isDeletingExamResult = false

                    if let error {
                        examResultToDelete = nil

                        examActionMessage = tr(
                            "מחיקת המבחן נכשלה: \(error.localizedDescription)",
                            "Deleting the exam failed: \(error.localizedDescription)"
                        )

                        shouldDismissAfterExamAction = false
                        showExamActionAlert = true
                        return
                    }

                    withAnimation(
                        .easeInOut(duration: 0.20)
                    ) {
                        completedExamResults.removeAll {
                            $0.resultId == resultId
                        }
                    }

                    examResultToDelete = nil

                    examActionMessage = tr(
                        "המבחן נמחק מהיסטוריית המבחנים.",
                        "The exam was deleted from history."
                    )

                    shouldDismissAfterExamAction = false
                    showExamActionAlert = true
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
                            traineeName = name
                            showTraineeNameBox = false
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
        let cleanName = traineeName.trimmed()

        guard !cleanName.isEmpty else {
            examActionMessage = tr(
                "נא לבחור נבחן מתוך הרשימה או ליצור נבחן חדש לפני תחילת המבחן.",
                "Please select a trainee from the list or create a new trainee before starting the exam."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        traineeName = cleanName
        showTraineeNameBox = false
        isTypingNewTraineeName = false

        if marksMap.isEmpty && !pendingLoadedDraft.isEmpty {
            marksMap = pendingLoadedDraft
        }

        pushRecentTrainee(cleanName)
        saveLastTrainee(cleanName)
        checkForDraft()

        // Android behavior: exercise topics start closed.
        expandedTopic = nil

        withAnimation(.easeInOut(duration: 0.22)) {
            hasStartedExam = true
        }
    }
    
    private func saveDraftFromAndroidPanel() {
        let cleanName = traineeName.trimmed()

        guard !cleanName.isEmpty else {
            examActionMessage = tr(
                "נא להזין שם נבחן לפני שמירה.",
                "Please enter a trainee name before saving."
            )
            shouldDismissAfterExamAction = false
            showExamActionAlert = true
            return
        }

        traineeName = cleanName
        showTraineeNameBox = false

        saveExamDraft(
            traineeName: cleanName,
            belt: currentBelt,
            marksMap: marksMap
        )

        pushRecentTrainee(cleanName)
        saveLastTrainee(cleanName)

        examActionMessage = tr(
            "הטיוטה נשמרה בהצלחה.",
            "Draft saved successfully."
        )
        shouldDismissAfterExamAction = false
        showExamActionAlert = true
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

    private func checkForDraft() {
        let name = traineeName.trimmed()
        guard !name.isEmpty else { return }

        let beltForCheck = currentBelt
        let key = draftKey(traineeName: name, belt: beltForCheck)

        if resumeCheckedKey == key { return }
        resumeCheckedKey = key

        loadExamDraft(traineeName: name, belt: beltForCheck) { loaded in
            DispatchQueue.main.async {
                guard resumeCheckedKey == key else { return }
                guard traineeName.trimmed() == name else { return }
                guard currentBelt.id == beltForCheck.id else { return }

                if !loaded.isEmpty {
                    pendingLoadedDraft = loaded
                    showResumeDialog = true
                }
            }
        }
    }
    
    private func saveCurrentExam() {
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
                saveLastTrainee(cleanName)

                marksMap.removeAll()
                hasUnsavedChanges = false
                resumeCheckedKey = draftKey(traineeName: cleanName, belt: currentBelt)

                examActionMessage = tr(
                    "המבחן הסתיים ונשמר בהצלחה.",
                    "The exam was finished and saved successfully."
                )
                shouldDismissAfterExamAction = true
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
        let contentTop: CGFloat = 164
        let contentBottom: CGFloat = pageHeight - 66

        let navy = UIColor(
            red: 2.0 / 255.0,
            green: 43.0 / 255.0,
            blue: 74.0 / 255.0,
            alpha: 1
        )

        let mediumBlue = UIColor(
            red: 36.0 / 255.0,
            green: 103.0 / 255.0,
            blue: 158.0 / 255.0,
            alpha: 1
        )

        let lightHeaderBlue = UIColor(
            red: 128.0 / 255.0,
            green: 183.0 / 255.0,
            blue: 220.0 / 255.0,
            alpha: 1
        )

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
                let graphicsContext = context.cgContext

                graphicsContext.saveGState()

                UIColor.white.setFill()
                graphicsContext.fill(pageBounds)

                let headerBottom: CGFloat = 122

                navy.setFill()

                let navyPath = UIBezierPath()
                navyPath.move(
                    to: CGPoint(
                        x: pageWidth,
                        y: 0
                    )
                )
                navyPath.addLine(
                    to: CGPoint(
                        x: pageWidth,
                        y: headerBottom
                    )
                )
                navyPath.addLine(
                    to: CGPoint(
                        x: 178,
                        y: headerBottom
                    )
                )
                navyPath.addLine(
                    to: CGPoint(
                        x: 238,
                        y: 0
                    )
                )
                navyPath.close()
                navyPath.fill()

                mediumBlue.setFill()

                let mediumStripe = UIBezierPath()
                mediumStripe.move(
                    to: CGPoint(
                        x: 208,
                        y: headerBottom
                    )
                )
                mediumStripe.addLine(
                    to: CGPoint(
                        x: 224,
                        y: headerBottom
                    )
                )
                mediumStripe.addLine(
                    to: CGPoint(
                        x: 284,
                        y: 0
                    )
                )
                mediumStripe.addLine(
                    to: CGPoint(
                        x: 268,
                        y: 0
                    )
                )
                mediumStripe.close()
                mediumStripe.fill()

                lightHeaderBlue.setFill()

                let lightStripe = UIBezierPath()
                lightStripe.move(
                    to: CGPoint(
                        x: 230,
                        y: headerBottom
                    )
                )
                lightStripe.addLine(
                    to: CGPoint(
                        x: 238,
                        y: headerBottom
                    )
                )
                lightStripe.addLine(
                    to: CGPoint(
                        x: 298,
                        y: 0
                    )
                )
                lightStripe.addLine(
                    to: CGPoint(
                        x: 290,
                        y: 0
                    )
                )
                lightStripe.close()
                lightStripe.fill()

                navy.setFill()

                UIBezierPath(
                    ovalIn: CGRect(
                        x: 36,
                        y: 16,
                        width: 84,
                        height: 84
                    )
                ).fill()

                UIColor.white.setFill()

                UIBezierPath(
                    ovalIn: CGRect(
                        x: 40,
                        y: 20,
                        width: 76,
                        height: 76
                    )
                ).fill()

                drawText(
                    "KAMI",
                    in: CGRect(
                        x: 40,
                        y: 43,
                        width: 76,
                        height: 34
                    ),
                    font: .systemFont(
                        ofSize: 25,
                        weight: .bold
                    ),
                    color: navy,
                    alignment: .center
                )

                let headerTextX: CGFloat =
                    isEnglish ? 308 : 260

                let headerTextWidth: CGFloat =
                    pageWidth - headerTextX - 34

                drawText(
                    tr(
                        "דו״ח מבחן פנימי",
                        "Internal Exam Report"
                    ),
                    in: CGRect(
                        x: headerTextX,
                        y: 28,
                        width: headerTextWidth,
                        height: 39
                    ),
                    font: .systemFont(
                        ofSize: 28,
                        weight: .bold
                    ),
                    color: .white,
                    alignment: isEnglish ? .left : .right
                )

                drawText(
                    tr(
                        "חגורה: \(examBeltNameForUi(session.belt, isEnglish: false))",
                        "Belt: \(examBeltNameForUi(session.belt, isEnglish: true))"
                    ),
                    in: CGRect(
                        x: headerTextX,
                        y: 70,
                        width: headerTextWidth,
                        height: 25
                    ),
                    font: .systemFont(
                        ofSize: 14,
                        weight: .regular
                    ),
                    color: .white,
                    alignment: isEnglish ? .left : .right
                )

                drawText(
                    tr(
                        "תאריך הפקה: \(formattedDate)",
                        "Generated: \(formattedDate)"
                    ),
                    in: CGRect(
                        x: leftMargin,
                        y: 132,
                        width: contentWidth,
                        height: 18
                    ),
                    font: .systemFont(
                        ofSize: 9,
                        weight: .regular
                    ),
                    color: mutedText,
                    alignment: .right
                )

                graphicsContext.restoreGState()
            }

            func drawFooter() {
                let footerY = pageHeight - 29

                borderColor.setFill()

                UIBezierPath(
                    rect: CGRect(
                        x: leftMargin,
                        y: footerY - 10,
                        width: contentWidth,
                        height: 1
                    )
                ).fill()

                drawText(
                    tr(
                        "נוצר ע״י K.A.M.I",
                        "Generated by K.A.M.I"
                    ),
                    in: CGRect(
                        x: leftMargin,
                        y: footerY,
                        width: contentWidth / 2,
                        height: 16
                    ),
                    font: .systemFont(
                        ofSize: 10.5,
                        weight: .regular
                    ),
                    color: mutedText,
                    alignment: .left
                )

                drawText(
                    tr(
                        "עמוד \(pageNumber)",
                        "Page \(pageNumber)"
                    ),
                    in: CGRect(
                        x: leftMargin + contentWidth / 2,
                        y: footerY,
                        width: contentWidth / 2,
                        height: 16
                    ),
                    font: .systemFont(
                        ofSize: 10.5,
                        weight: .regular
                    ),
                    color: mutedText,
                    alignment: .right
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
            : "internal_exam_hebrew_report.pdf"

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
                "יצירת קובץ ה־PDF נכשלה: \(error.localizedDescription)",
                "Failed to create the PDF: \(error.localizedDescription)"
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
                name: item.name
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
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(
                red: 0.10,
                green: 0.14,
                blue: 0.24
            )
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color.black.opacity(0.58)
    }

    private var rowBackground: Color {
        isDarkMode
            ? Color.white.opacity(0.10)
            : Color.white.opacity(0.70)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors:
                isDarkMode
                ? [
                    Color(
                        red: 0.075,
                        green: 0.100,
                        blue: 0.160
                    ),
                    beltDarkColor(for: currentBelt)
                        .opacity(0.55),
                    Color(
                        red: 0.060,
                        green: 0.080,
                        blue: 0.135
                    )
                ]
                : [
                    Color(
                        red: 1.0,
                        green: 0.98,
                        blue: 0.78
                    ),
                    Color.white.opacity(0.96),
                    beltSoftColor(for: currentBelt)
                        .opacity(0.68)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        isDarkMode
            ? Color(
                red: 0.070,
                green: 0.095,
                blue: 0.150
            )
            : Color(
                red: 0.92,
                green: 0.95,
                blue: 1.00
            )
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color(
                red: 0.07,
                green: 0.10,
                blue: 0.15
            )
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.64)
            : Color(
                red: 0.37,
                green: 0.42,
                blue: 0.50
            )
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

    private var primaryTextColor: Color {
                                            isDarkMode
                                                ? Color.white.opacity(0.94)
                                                : Color(
                                                    red: 0.08,
                                                    green: 0.12,
                                                    blue: 0.20
                                                )
                                        }

                                        private var cardColor: Color {
                                            isDarkMode
                                                ? Color(
                                                    red: 0.060,
                                                    green: 0.082,
                                                    blue: 0.130
                                                )
                                                : Color.white.opacity(0.985)
                                        }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var scoreValues: [Int] {
        isEnglish ? Array(1...10) : [5, 4, 3, 2, 1, 10, 9, 8, 7, 6]
    }

    private let scoreColumns: [GridItem] = Array(
        repeating: GridItem(.fixed(26), spacing: 6, alignment: .center),
        count: 5
    )

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 7) {
            Text(name)
                .kmiFont(
                    size: 13,
                    weight: .black
                )
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.bottom, 1)

            LazyVGrid(columns: scoreColumns, alignment: .center, spacing: 5) {
                ForEach(scoreValues, id: \.self) { value in
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
        .padding(.vertical, 7)
        .background(cardColor)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isDarkMode
                        ? beltAccentColor(for: belt)
                            .opacity(0.32)
                        : Color(
                            red: 0.78,
                            green: 0.84,
                            blue: 0.92
                        )
                        .opacity(0.75),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.075), radius: 4, x: 0, y: 2)
    }
}

private struct ScoreChipView: View {
    let value: Int
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let base = scoreColor(value)
        let background = selected ? base.opacity(0.95) : base.opacity(0.34)

        Button(action: onTap) {
            Text("\(value)")
                .kmiFont(
                    size: 9.5,
                    weight: .black
                )
                .foregroundStyle(
                    selected
                        ? Color.black.opacity(0.94)
                        : Color.primary.opacity(0.92)
                )
                .frame(width: 25, height: 25)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            selected ? base.opacity(0.98) : base.opacity(0.82),
                            lineWidth: selected ? 1.4 : 0.9
                        )
                )
                .shadow(
                    color: selected ? base.opacity(0.22) : Color.clear,
                    radius: selected ? 2 : 0,
                    x: 0,
                    y: selected ? 1 : 0
                )
        }
        .buttonStyle(.plain)
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

private func draftKey(traineeName: String, belt: Belt) -> String {
    "draft_\(traineeName.trimmed())_\(belt.id)"
}

private func internalExamItemsForPersistence(for belt: Belt) -> [ExamExerciseItem] {
    let categorized = ExamDataSource.categorizedItemsForBelt(belt)

    return categorized.enumerated().map { index, item in
        ExamExerciseItem(
            id: "\(belt.id)_\(item.topic)_\(item.name)_\(index)",
            belt: belt,
            topic: item.topic,
            name: item.name
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
    belt: Belt
) -> String {
    "\(coachUid)_\(belt.id)_\(internalExamTraineeKey(traineeName))"
}

private func saveExamDraft(
    traineeName: String,
    belt: Belt,
    marksMap: [String: Int]
) {
    let cleanName = traineeName.trimmed()
    guard !cleanName.isEmpty else { return }
    guard let coachUid = internalExamCoachUid() else { return }

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
        belt: belt
    )

    let data: [String: Any] = [
        "examId": docId,
        "coachUid": coachUid,
        "traineeName": cleanName,
        "traineeKey": internalExamTraineeKey(cleanName),
        "belt": belt.id,
        "beltHeb": belt.heb,
        "beltEn": examBeltNameForUi(belt, isEnglish: true),
        "status": InternalExamStore.draftStatus,
        "marks": safeMarks,
        "totalScore": draftSession.totalScore,
        "maxScore": draftSession.maxScore,
        "percent": draftSession.percent,
        "summaryTextHe": examStatusText(percent: draftSession.percent, isEnglish: false),
        "summaryTextEn": examStatusText(percent: draftSession.percent, isEnglish: true),
        "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
        "updatedAt": FieldValue.serverTimestamp()
    ]

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .setData(data, merge: true)

    pushRecentTrainee(cleanName)
    saveLastTrainee(cleanName)
}

private func loadExamDraft(
    traineeName: String,
    belt: Belt,
    completion: @escaping ([String: Int]) -> Void
) {
    let cleanName = traineeName.trimmed()
    guard !cleanName.isEmpty else {
        completion([:])
        return
    }

    guard let coachUid = internalExamCoachUid() else {
        completion([:])
        return
    }

    let docId = internalExamDraftId(
        coachUid: coachUid,
        traineeName: cleanName,
        belt: belt
    )

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .getDocument { snapshot, _ in
            guard let data = snapshot?.data(),
                  let rawMarks = data["marks"] as? [String: Any] else {
                completion([:])
                return
            }

            let marks = rawMarks.reduce(into: [String: Int]()) { result, item in
                let key = item.key.trimmed()
                guard !key.isEmpty else { return }

                if let value = item.value as? Int {
                    result[key] = clampScore10(value)
                } else if let value = item.value as? Double {
                    result[key] = clampScore10(Int(value))
                } else if let value = item.value as? NSNumber {
                    result[key] = clampScore10(value.intValue)
                }
            }

            completion(marks)
        }
}

private func removeExamDraft(traineeName: String, belt: Belt) {
    let cleanName = traineeName.trimmed()
    guard !cleanName.isEmpty else { return }
    guard let coachUid = internalExamCoachUid() else { return }

    let docId = internalExamDraftId(
        coachUid: coachUid,
        traineeName: cleanName,
        belt: belt
    )

    Firestore.firestore()
        .collection(InternalExamStore.draftsCollection)
        .document(docId)
        .delete()
}

private func saveCompletedExamResult(
    session: InternalExamSession,
    marksMap: [String: Int],
    completion: @escaping (Bool) -> Void
) {
    let cleanName = session.traineeName.trimmed()

    guard !cleanName.isEmpty else {
        completion(false)
        return
    }

    guard let coachUid = Auth.auth().currentUser?.uid else {
        completion(false)
        return
    }

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
            "belt": exercise.belt.id,
            "beltHeb": exercise.belt.heb,
            "beltEn": examBeltNameForUi(exercise.belt, isEnglish: true),
            "topic": exercise.topic,
            "subTopic": "",
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

        "traineeName": cleanName,
        "traineeKey": traineeKey,

        "belt": session.belt.id,
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

        "summaryTextHe": examStatusText(percent: session.percent, isEnglish: false),
        "summaryTextEn": examStatusText(percent: session.percent, isEnglish: true),
        "shareSummaryHe": session.shareText(isEnglish: false),
        "shareSummaryEn": session.shareText(isEnglish: true),

        "completedAtMillis": completedAtMillis,
        "completedAt": FieldValue.serverTimestamp(),

        "source": InternalExamStore.completedSource
    ]

    docRef.setData(data, merge: true) { error in
        completion(error == nil)
    }
}

private func loadCompletedExamResults() -> [StoredCompletedInternalExamResult] {
    guard let data = UserDefaults.standard.data(forKey: InternalExamStore.completedResultsKey),
          let decoded = try? JSONDecoder().decode([StoredCompletedInternalExamResult].self, from: data) else {
        return []
    }

    return decoded
}

private func removeRecentTraineeAfterCompletion(_ name: String) {
    let clean = name.trimmed()
    guard !clean.isEmpty else { return }

    let list = loadRecentTrainees().filter {
        $0.trimmed().lowercased() != clean.lowercased()
    }

    UserDefaults.standard.set(list, forKey: InternalExamStore.recentKey)

    guard let coachUid = internalExamCoachUid() else { return }

    Firestore.firestore()
        .collection(InternalExamStore.recentTraineesCollection)
        .document(coachUid)
        .collection(InternalExamStore.traineesSubcollection)
        .document(internalExamTraineeKey(clean))
        .delete()
}

private func loadRecentTrainees() -> [String] {
    UserDefaults.standard.stringArray(forKey: InternalExamStore.recentKey) ?? []
}

private func pushRecentTrainee(_ name: String, limit: Int = 20) {
    let clean = name.trimmed()
    guard !clean.isEmpty else { return }

    var list = loadRecentTrainees().filter {
        $0.trimmed().lowercased() != clean.lowercased()
    }

    list.insert(clean, at: 0)

    if list.count > limit {
        list = Array(list.prefix(limit))
    }

    UserDefaults.standard.set(list, forKey: InternalExamStore.recentKey)

    guard let coachUid = internalExamCoachUid() else { return }

    let traineeKey = internalExamTraineeKey(clean)

    Firestore.firestore()
        .collection(InternalExamStore.recentTraineesCollection)
        .document(coachUid)
        .collection(InternalExamStore.traineesSubcollection)
        .document(traineeKey)
        .setData(
            [
                "name": clean,
                "traineeKey": traineeKey,
                "coachUid": coachUid,
                "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
}

private func saveLastTrainee(_ name: String) {
    let clean = name.trimmed()
    guard !clean.isEmpty else { return }

    UserDefaults.standard.set(clean, forKey: InternalExamStore.lastKey)

    guard let coachUid = internalExamCoachUid() else { return }

    Firestore.firestore()
        .collection(InternalExamStore.coachStateCollection)
        .document(coachUid)
        .setData(
            [
                "lastTraineeName": clean,
                "lastTraineeKey": internalExamTraineeKey(clean),
                "updatedAtMillis": Int64(Date().timeIntervalSince1970 * 1000),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
}

private func loadLastTrainee() -> String {
    UserDefaults.standard.string(forKey: InternalExamStore.lastKey) ?? ""
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
