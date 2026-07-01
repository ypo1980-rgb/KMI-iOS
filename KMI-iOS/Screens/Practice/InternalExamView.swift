import SwiftUI
import Shared
import FirebaseAuth
import FirebaseFirestore

struct InternalExamView: View {
    let belt: Belt
    @Environment(\.dismiss) private var dismiss
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
    @State private var marksMap: [String: Int] = [:]
    @State private var expandedTopic: String? = nil

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
                ProgressView(tr("בודק הרשאות…", "Checking permissions…"))
            } else if coach.isCoach {
                examContent
            } else {
                VStack(spacing: 10) {
                    Text(tr("גישה למאמנים בלבד", "Coach access only"))
                        .font(.title3.weight(.heavy))
                        .frame(maxWidth: .infinity, alignment: examFrameAlignment)
                        .multilineTextAlignment(examTextAlignment)

                    Text(tr("ההרשאה נקבעת בשרת לפי מספר טלפון", "Permission is determined on the server by phone number"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: examFrameAlignment)
                        .multilineTextAlignment(examTextAlignment)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .environment(\.layoutDirection, screenLayoutDirection)
        }
        
        .alert(tr("שמירת טיוטה", "Save draft"), isPresented: $showExitDialog) {

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
            .alert(tr("מבחן פנימי", "Internal Exam"), isPresented: $showExamActionAlert) {
            Button(tr("אישור", "OK")) {
                if shouldDismissAfterExamAction {
                    dismiss()
                }
            }
        } message: {
            Text(examActionMessage)
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
            androidExamBackground

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
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.88))
                        .frame(width: 66, height: 66)
                        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)

                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Color(red: 0.22, green: 0.24, blue: 0.31))
                }

                Text(tr("מבחן שמור נמצא", "Saved exam found"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.19, blue: 0.29))
                    .multilineTextAlignment(.center)

                Text(tr(
                    "נמצא מבחן שמור מהפעם האחרונה.\nלהמשיך ממנו או להתחיל מבחן חדש?",
                    "A saved exam was found from the last session.\nContinue from it or start a new exam?"
                ))
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.35, green: 0.38, blue: 0.48))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

                HStack(spacing: 12) {
                    Button {
                        startNewExamFromSavedPrompt()
                    } label: {
                        Text(tr("בחן חדש ✨", "New Exam ✨"))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.05, green: 0.72, blue: 0.95),
                                        Color(red: 0.42, green: 0.22, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        continueSavedExamFromPrompt()
                    } label: {
                        Text(tr("המשך  > ", "Continue  >"))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.35, green: 0.22, blue: 0.93),
                                        Color(red: 0.69, green: 0.17, blue: 0.93)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 22)
            .frame(maxWidth: 340)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        Color(red: 0.94, green: 0.90, blue: 1.0).opacity(0.97),
                        Color.white.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 18)
        }
    }
    
    private var androidPreStartHint: some View {
        VStack(spacing: 0) {
            Text(tr("בחר נבחן וחגורה לפני\nתחילת המבחן", "Choose trainee and belt\nbefore starting the exam"))
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.30))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.91, green: 0.94, blue: 0.97).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 7)
    }

    private var androidNameField: some View {
        Group {
            if isTypingNewTraineeName {
                HStack(spacing: 10) {
                    Button {
                        _ = commitTraineeNameAndCollapse()
                        isTypingNewTraineeName = false
                    } label: {
                        Text(tr("אישור", "OK"))
                            .font(.system(size: 15, weight: .black, design: .rounded))
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

                    TextField(tr("שם הנבחן", "Trainee name"), text: $traineeName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.22))
                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                        .submitLabel(.done)
                        .onSubmit {
                            _ = commitTraineeNameAndCollapse()
                            isTypingNewTraineeName = false
                        }
                }
                .padding(.horizontal, 14)
                .frame(height: 66)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.76, green: 0.63, blue: 0.45).opacity(0.65), lineWidth: 1.2)
                )
                .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

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
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color(red: 0.25, green: 0.27, blue: 0.34))

                        Text(traineeName.trimmed().isEmpty
                             ? tr("בחר נבחן מתוך הרשימה", "Select a trainee from the list")
                             : traineeName.trimmed())
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                traineeName.trimmed().isEmpty
                                ? Color(red: 0.42, green: 0.48, blue: 0.58)
                                : Color(red: 0.56, green: 0.38, blue: 0.18)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 66)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(red: 0.76, green: 0.63, blue: 0.45).opacity(0.65), lineWidth: 1.2)
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
            ForEach([Belt.yellow, .orange, .green, .blue, .brown, .black], id: \.id) { picked in
                Button(examBeltNameForUi(picked, isEnglish: isEnglish)) {
                    currentBelt = picked
                    expandedTopic = nil
                    pendingLoadedDraft.removeAll()
                    resumeCheckedKey = nil
                    checkForDraft()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.50, green: 0.40, blue: 0.15))
                    .frame(width: 34, height: 34)
                    .background(Color(red: 1.00, green: 0.98, blue: 0.82))
                    .clipShape(Circle())

                VStack(alignment: .trailing, spacing: 2) {
                    Text(tr("חגורה במבחן", "Exam belt"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.42, green: 0.47, blue: 0.60))

                    Text(examBeltNameForUi(currentBelt, isEnglish: isEnglish))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(beltDarkColor(for: currentBelt))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                androidBeltImage
            }
            .padding(.horizontal, 14)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.81, blue: 0.63).opacity(0.55), lineWidth: 1.2)
            )
            .shadow(color: beltAccentColor(for: currentBelt).opacity(0.22), radius: 7, x: 0, y: 3)
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
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(beltAccentColor(for: currentBelt))
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
                Text(shouldShowContinueExamButton
                     ? tr("המשך מבחן", "Continue Exam")
                     : tr("התחל מבחן", "Start Exam"))
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: shouldShowContinueExamButton ? "forward.fill" : "play.fill")
                    .font(.system(size: 18, weight: .black))
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
                    .font(.system(size: 20, weight: .black, design: .rounded))
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
                    .font(.system(size: 20, weight: .black, design: .rounded))
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
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18, weight: .black))
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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10, pinnedViews: []) {
                    SummaryCardView(
                        currentBelt: currentBelt,
                        marksMap: marksMap,
                        isEnglish: isEnglish,
                        itemsProvider: { belt in
                            examItems(for: belt)
                        }
                    )
                    .padding(.top, 8)

                    ForEach(groupedTopics, id: \.topic) { group in
                        TopicHeaderView(
                            title: examTitleForUi(group.topic, isEnglish: isEnglish),
                            expanded: expandedTopic == group.topic,
                            exerciseCount: group.items.count,
                            isEnglish: isEnglish,
                            belt: currentBelt
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedTopic = (expandedTopic == group.topic ? nil : group.topic)
                            }
                        }

                        if expandedTopic == group.topic {
                            ForEach(group.items) { item in
                                ExerciseRowView(
                                    name: examTitleForUi(item.name, isEnglish: isEnglish),
                                    score: marksMap[item.id],
                                    isEnglish: isEnglish,
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
                    }

                    Spacer(minLength: 72)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }

            BottomActionBarView(
                session: session,
                isEnglish: isEnglish,
                onSave: saveCurrentExam,
                onShare: shareSummaryText,
                onChangeBelt: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        hasStartedExam = false
                    }
                }
            )
            .contextMenu {
                Button(tr("ייצוא PDF", "Export PDF")) {
                    exportPdf()
                }
            }
        }
    }
    
    private var androidActiveExamHeader: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hasStartedExam = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(red: 0.12, green: 0.18, blue: 0.30))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 2) {
                Text(traineeName.trimmed().isEmpty ? tr("מבחן פנימי", "Internal Exam") : traineeName.trimmed())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(examBeltNameForUi(currentBelt, isEnglish: isEnglish))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }
    
    private var examBeltBackground: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                beltSoftColor(for: currentBelt).opacity(0.98),
                Color.white.opacity(0.96),
                beltSoftColor(for: currentBelt).opacity(0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(
            LinearGradient(
                colors: [
                    beltAccentColor(for: currentBelt).opacity(0.10),
                    Color.clear,
                    beltDarkColor(for: currentBelt).opacity(0.10)
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
                Color(red: 0.95, green: 0.96, blue: 0.99)
                    .ignoresSafeArea()

                if isLoadingExamArchive {
                    VStack(spacing: 12) {
                        ProgressView()

                        Text(tr("טוען ארכיון מבחנים…", "Loading exam archive…"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if completedExamResults.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.39, blue: 0.50))

                        Text(tr("אין מבחנים שמורים עדיין.", "No completed exams yet."))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.18, green: 0.22, blue: 0.32))
                            .multilineTextAlignment(.center)

                        Text(tr(
                            "לאחר סיום מבחן הוא יופיע כאן עם תאריך הסיום.",
                            "After finishing an exam, it will appear here with its completion date."
                        ))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(completedExamResults, id: \.resultId) { result in
                                NavigationLink {
                                    completedExamDetailView(result)
                                } label: {
                                    completedExamArchiveRow(result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle(tr("ארכיון מבחנים", "Exam Archive"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("סגור", "Close")) {
                        showExamArchiveSheet = false
                    }
                }
            }
        }
    }
    
    private func completedExamArchiveRow(_ result: StoredCompletedInternalExamResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
                Text(result.traineeName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                Text(result.beltNameForArchive(isEnglish: isEnglish))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.29, green: 0.34, blue: 0.46))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                Text(tr(
                    "תאריך סיום: \(archiveDateText(result.completedAtMillis))",
                    "Completed: \(archiveDateText(result.completedAtMillis))"
                ))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                Text(tr(
                    "ציון: \(result.score10.scoreString()) / 10  (\(result.percent)%)",
                    "Score: \(result.score10.scoreString()) / 10  (\(result.percent)%)"
                ))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(statusColor(percent: result.percent))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            }

            Circle()
                .fill(statusColor(percent: result.percent).opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay(
                    Text("\(result.percent)%")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor(percent: result.percent))
                )

            Image(systemName: isEnglish ? "chevron.right" : "chevron.left")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.secondary)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color(red: 0.91, green: 0.95, blue: 1.0).opacity(0.94),
                    Color.white.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    private func completedExamDetailView(_ result: StoredCompletedInternalExamResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                    Text(result.traineeName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    Text(result.beltNameForArchive(isEnglish: isEnglish))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.29, green: 0.34, blue: 0.46))
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    Text(tr(
                        "תאריך סיום: \(archiveDateText(result.completedAtMillis))",
                        "Completed: \(archiveDateText(result.completedAtMillis))"
                    ))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    Text(tr(
                        "ציון: \(result.score10.scoreString()) / 10  (\(result.percent)%)",
                        "Score: \(result.score10.scoreString()) / 10  (\(result.percent)%)"
                    ))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(statusColor(percent: result.percent))
                    .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                    Text(isEnglish ? result.summaryTextEn : result.summaryTextHe)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.28, green: 0.32, blue: 0.43))
                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                }
                .padding(16)
                .background(Color.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 7, x: 0, y: 4)

                if result.answeredExercises.isEmpty {
                    Text(tr("אין פירוט תרגילים למבחן זה.", "No exercise details for this exam."))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 12)
                } else {
                    ForEach(groupCompletedExercises(result.answeredExercises), id: \.topic) { group in
                        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
                            Text(examTitleForUi(group.topic, isEnglish: isEnglish))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)

                            ForEach(group.items, id: \.exerciseId) { item in
                                HStack(spacing: 10) {
                                    Text("\(item.score)")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(.black.opacity(0.86))
                                        .frame(width: 32, height: 28)
                                        .background(scoreColor(item.score).opacity(0.55))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Text(examTitleForUi(item.name, isEnglish: isEnglish))
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.27))
                                        .multilineTextAlignment(isEnglish ? .leading : .trailing)
                                        .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                                }
                                .environment(\.layoutDirection, .leftToRight)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.82))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(red: 0.95, green: 0.96, blue: 0.99).ignoresSafeArea())
        .navigationTitle(tr("פרטי מבחן", "Exam Details"))
        .navigationBarTitleDisplayMode(.inline)
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

        let text = session.shareText(isEnglish: isEnglish)

        let activity = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {

            root.present(activity, animated: true)
        }
    }
    
    private func exportPdf() {
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

        traineeName = cleanName

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            let text = session.shareText(isEnglish: isEnglish)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = isEnglish ? .left : .right
            paragraphStyle.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .paragraphStyle: paragraphStyle
            ]

            text.draw(
                in: CGRect(x: 40, y: 40, width: 515, height: 760),
                withAttributes: attrs
            )
        }

        let tmp = FileManager.default.temporaryDirectory
        let fileName = isEnglish ? "internal_exam_report.pdf" : "internal_exam_hebrew_report.pdf"
        let file = tmp.appendingPathComponent(fileName)

        try? data.write(to: file)

        let activity = UIActivityViewController(
            activityItems: [file],
            applicationActivities: nil
        )

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {

            root.present(activity, animated: true)
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
    let itemsProvider: (Belt) -> [ExamExerciseItem]

    @State private var expanded = false

    var body: some View {
        let orderedBelts = beltsUpTo(currentBelt)
        let beltScores: [(Belt, BeltScore)] = orderedBelts.map { belt in
            let exercises = itemsProvider(belt)
            var total = 0.0
            var max = 0.0

            for ex in exercises {
                if let score = marksMap[ex.id] {
                    max += 10.0
                    total += Double(clampScore10(score))
                }
            }

            return (belt, BeltScore(total: total, max: max))
        }

        let totalScore = beltScores.reduce(0.0) { $0 + $1.1.total }
        let maxScore = beltScores.reduce(0.0) { $0 + $1.1.max }
        let totalScore10 = maxScore == 0 ? 0 : (totalScore / maxScore) * 10.0
        let percent = maxScore == 0 ? 0 : Int((totalScore / maxScore) * 100.0)
        let answeredCount = marksMap.count
        let totalExercises = orderedBelts.flatMap { itemsProvider($0) }.count

        return VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.78))
                        .clipShape(Circle())

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(isEnglish ? "Exam Summary" : "סיכום מבחן")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.24))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(isEnglish
                             ? "Average: \(totalScore10.scoreString()) / 10 (\(percent)%)"
                             : "מצטבר: \(totalScore10.scoreString()) / 10 (\(percent)%)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.90))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(isEnglish
                             ? "\(answeredCount) of \(totalExercises) exercises"
                             : "\(answeredCount) / \(totalExercises) תרגילים")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.58))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text(examSummaryText(percent: percent, isEnglish: isEnglish))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(statusColor(percent: percent).opacity(0.95))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    miniBeltIcon
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.78),
                            Color.white.opacity(0.96),
                            beltSoftColor(for: currentBelt).opacity(0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.60), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 6) {
                    ForEach(beltScores, id: \.0.id) { belt, score in
                        HStack(spacing: 10) {
                            Text("\(score.score10.scoreString()) / 10 (\(score.percent)%)")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(statusColor(percent: score.percent).opacity(0.96))

                            Spacer()

                            Text(examBeltNameForUi(belt, isEnglish: isEnglish))
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.70))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        if let image = UIImage(named: beltImageName(for: currentBelt)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 34)
                .rotationEffect(.degrees(-6))
        } else {
            Image(systemName: "rosette")
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(beltAccentColor(for: currentBelt))
                .frame(width: 54, height: 34)
        }
    }

    private func beltImageName(for belt: Belt) -> String {
        switch belt {
        case .white: return "belt_white"
        case .yellow: return "belt_yellow"
        case .orange: return "belt_orange"
        case .green: return "belt_green"
        case .blue: return "belt_blue"
        case .brown: return "belt_brown"
        case .black: return "belt_black"
        default: return "belt_black"
        }
    }
}

private struct TopicHeaderView: View {
    let title: String
    let expanded: Bool
    let exerciseCount: Int
    let isEnglish: Bool
    let belt: Belt
    let onTap: () -> Void

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var countText: String {
        isEnglish ? "\(exerciseCount) exercises" : "\(exerciseCount) תרגילים"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isEnglish {
                    iconBubble

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)

                        Text(countText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(beltDarkColor(for: belt).opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }

                    chevron
                } else {
                    chevron

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.86))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)

                        Text(countText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(beltDarkColor(for: belt).opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }

                    iconBubble
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        beltSoftColor(for: belt).opacity(0.96),
                        Color.white.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(beltAccentColor(for: belt).opacity(0.32), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var iconBubble: some View {
        ZStack {
            Circle()
                .fill(beltAccentColor(for: belt).opacity(0.18))
                .frame(width: 38, height: 38)

            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(beltDarkColor(for: belt).opacity(0.88))
        }
    }

    private var chevron: some View {
        Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(beltDarkColor(for: belt).opacity(0.80))
    }
}

private struct ExerciseRowView: View {
    let name: String
    let score: Int?
    let isEnglish: Bool
    let belt: Belt
    let onScoreChange: (Int?) -> Void

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
                .font(.system(size: 13.2, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
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
        .background(Color.white.opacity(0.985))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.84, blue: 0.92).opacity(0.75), lineWidth: 1)
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
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.92))
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
    let onShare: () -> Void
    let onChangeBelt: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onShare) {
                    Text(examTr(isEnglish, "שתף", "Share"))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.70, blue: 0.94),
                                    Color(red: 0.19, green: 0.40, blue: 0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onSave) {
                    Text(examTr(isEnglish, "סיום מבחן", "Finish Exam"))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.22, blue: 0.92),
                                    Color(red: 0.68, green: 0.15, blue: 0.86)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onChangeBelt) {
                HStack(spacing: 10) {
                    Text(examTr(isEnglish, "מעבר לחגורה אחרת", "Change Belt"))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "rosette")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
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
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color(red: 0.02, green: 0.16, blue: 0.26).opacity(0.96))
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
