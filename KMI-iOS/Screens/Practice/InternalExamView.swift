import SwiftUI
import Shared

struct InternalExamView: View {
    let belt: Belt
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var coach = CoachService.shared
    @State private var currentBelt: Belt
    @State private var traineeName: String = ""

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
        .alert(tr("מבחן שמור נמצא", "Saved exam found"), isPresented: $showResumeDialog) {
            Button(tr("המשך", "Continue")) {
                marksMap = pendingLoadedDraft
                hasUnsavedChanges = false
            }
            Button(tr("מבחן חדש", "New exam"), role: .destructive) {
                marksMap.removeAll()
                removeExamDraft(traineeName: traineeName, belt: currentBelt)
                traineeName = ""
                showTraineeNameBox = true
                resumeCheckedKey = nil
                hasUnsavedChanges = false
            }
            Button(tr("ביטול", "Cancel"), role: .cancel) { }
        } message: {
            Text(tr(
                "נמצא מבחן שמור מהפעם האחרונה. להמשיך ממנו או להתחיל מבחן חדש?",
                "A saved exam was found from the last session. Continue from it or start a new exam?"
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

    // MARK: - Main Content

    private var examContent: some View {
        ZStack {
            examBeltBackground

            VStack(spacing: 8) {
                traineeHeaderSection

                BeltSelectorView(
                    currentBelt: $currentBelt,
                    accent: beltAccentColor(for: currentBelt),
                    belt: currentBelt,
                    isEnglish: isEnglish
                )

                SummaryCardView(
                    currentBelt: currentBelt,
                    marksMap: marksMap,
                    isEnglish: isEnglish,
                    itemsProvider: { belt in
                        examItems(for: belt)
                    }
                )

                Divider()
                    .overlay(.white.opacity(0.25))

                ScrollView {
                    LazyVStack(spacing: 8, pinnedViews: []) {
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
                                        }
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 70)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                BottomActionBarView(
                    session: session,
                    isEnglish: isEnglish,
                    onSave: saveCurrentExam,
                    onShare: shareSummaryText
                )
                .contextMenu {
                    Button(tr("ייצוא PDF", "Export PDF")) {
                        exportPdf()
                    }
                }
            }
        }
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
        let marks = examItemsForCurrentBelt.map { item in
            marksMap[item.id]
        }
        return InternalExamSession(
            traineeName: traineeName.trimmed(),
            belt: currentBelt,
            date: Date(),
            exercises: examItemsForCurrentBelt,
            marks: marks
        )
    }

    // MARK: - Actions

    private func bootstrapInitialState() {
        recentTrainees = loadRecentTrainees()

        if traineeName.trimmed().isEmpty {
            let last = loadLastTrainee().trimmed()
            if !last.isEmpty {
                traineeName = last
                showTraineeNameBox = false
            }
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

        let key = draftKey(traineeName: name, belt: currentBelt)
        if resumeCheckedKey == key { return }
        resumeCheckedKey = key

        let loaded = loadExamDraft(traineeName: name, belt: currentBelt)
        if !loaded.isEmpty {
            pendingLoadedDraft = loaded
            showResumeDialog = true
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

        traineeName = cleanName
        showTraineeNameBox = false

        saveExamDraft(
            traineeName: cleanName,
            belt: currentBelt,
            marksMap: marksMap
        )

        pushRecentTrainee(cleanName)
        saveLastTrainee(cleanName)

        hasUnsavedChanges = false
        resumeCheckedKey = draftKey(traineeName: cleanName, belt: currentBelt)

        examActionMessage = tr(
            "המבחן הסתיים ונשמר בהצלחה.",
            "The exam was finished and saved successfully."
        )
        shouldDismissAfterExamAction = true
        showExamActionAlert = true
    }

    private func shareSummaryText() {

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

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

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
        let summaryText = examSummaryText(percent: percent, isEnglish: isEnglish)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: stackAlignment, spacing: 8) {
                HStack(spacing: 10) {
                    if isEnglish {
                        summaryIcon

                        VStack(alignment: .leading, spacing: 3) {
                            Text(examTr(isEnglish, "סיכום מבחן", "Exam summary"))
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.86))

                            Text(summaryText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(statusColor(percent: percent).opacity(0.92))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        chevronIcon
                    } else {
                        chevronIcon

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(examTr(isEnglish, "סיכום מבחן", "Exam summary"))
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.86))

                            Text(summaryText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(statusColor(percent: percent).opacity(0.92))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        summaryIcon
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                HStack(spacing: 8) {
                    miniStat(
                        title: isEnglish ? "Score" : "ציון",
                        value: "\(totalScore10.scoreString()) / 10"
                    )

                    miniStat(
                        title: isEnglish ? "Percent" : "אחוז",
                        value: "\(percent)%"
                    )
                }
                .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)

                if expanded && !beltScores.isEmpty {
                    Divider()
                        .padding(.vertical, 2)

                    VStack(spacing: 5) {
                        ForEach(beltScores, id: \.0.id) { belt, score in
                            HStack {
                                if isEnglish {
                                    Text(examBeltNameForUi(belt, isEnglish: isEnglish))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.78))

                                    Spacer()

                                    Text("\(score.score10.scoreString()) / 10 (\(score.percent)%)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(statusColor(percent: score.percent).opacity(0.94))
                                } else {
                                    Text("\(score.score10.scoreString()) / 10 (\(score.percent)%)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(statusColor(percent: score.percent).opacity(0.94))

                                    Spacer()

                                    Text(examBeltNameForUi(belt, isEnglish: isEnglish))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.78))
                                }
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.92),
                        Color.white.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 7, x: 0, y: 3)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    private var summaryIcon: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 40, height: 40)

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color.orange.opacity(0.92))
        }
    }

    private var chevronIcon: some View {
        Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(Color.orange.opacity(0.84))
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.52))

            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.orange.opacity(0.14), lineWidth: 1)
                )
        )
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

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var scoreCaption: String {
        if let score {
            return isEnglish ? "Score \(score) / 10" : "ציון \(score) / 10"
        }

        return isEnglish ? "Choose score" : "בחר ציון"
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 10) {
            HStack(spacing: 10) {
                if isEnglish {
                    accentLine

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .multilineTextAlignment(textAlignment)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)

                        Text(scoreCaption)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(score == nil ? Color.black.opacity(0.46) : beltDarkColor(for: belt).opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .multilineTextAlignment(textAlignment)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)

                        Text(scoreCaption)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(score == nil ? Color.black.opacity(0.46) : beltDarkColor(for: belt).opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                    }

                    accentLine
                }
            }
            .environment(\.layoutDirection, .leftToRight)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(0...10, id: \.self) { value in
                        ScoreChipView(
                            value: value,
                            selected: score == value
                        ) {
                            onScoreChange(score == value ? nil : value)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    beltSoftColor(for: belt).opacity(0.34),
                    Color.white.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.055), radius: 4, x: 0, y: 2)
    }

    private var accentLine: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(beltAccentColor(for: belt))
            .frame(width: 5, height: 42)
    }
}

private struct ScoreChipView: View {
    let value: Int
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let base = scoreColor(value)
        let background = selected ? base.opacity(0.96) : base.opacity(0.26)

        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: selected ? 14 : 13, weight: .heavy))
                .foregroundStyle(selected ? Color.black.opacity(0.92) : Color.black.opacity(0.66))
                .frame(width: selected ? 39 : 36, height: selected ? 39 : 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            selected ? base.opacity(0.98) : base.opacity(0.58),
                            lineWidth: selected ? 2.4 : 1.2
                        )
                )
                .shadow(
                    color: selected ? base.opacity(0.30) : Color.clear,
                    radius: selected ? 5 : 0,
                    x: 0,
                    y: selected ? 2 : 0
                )
                .scaleEffect(selected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct BottomActionBarView: View {
    let session: InternalExamSession
    let isEnglish: Bool
    let onSave: () -> Void
    let onShare: () -> Void

    private var scoreText: String {
        isEnglish
        ? "Score: \(session.score10.scoreString()) / 10 (\(session.percent)%)"
        : "ציון: \(session.score10.scoreString()) / 10 (\(session.percent)%)"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(scoreText)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
                .multilineTextAlignment(isEnglish ? .leading : .trailing)

            HStack(spacing: 10) {
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .bold))

                        Text(examTr(isEnglish, "שתף", "Share"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.purple.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.purple.opacity(0.20), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: onSave) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))

                        Text(examTr(isEnglish, "סיום מבחן", "Finish exam"))
                            .font(.system(size: 15, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.95),
                                Color.blue.opacity(0.86)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.58))
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
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
}

private func draftKey(traineeName: String, belt: Belt) -> String {
    "draft_\(traineeName.trimmed())_\(belt.id)"
}

private func saveExamDraft(traineeName: String, belt: Belt, marksMap: [String: Int]) {
    let key = draftKey(traineeName: traineeName, belt: belt)
    let clean = Dictionary(uniqueKeysWithValues: marksMap.map { ($0.key, clampScore10($0.value)) })

    if let data = try? JSONEncoder().encode(clean) {
        UserDefaults.standard.set(data, forKey: "\(InternalExamStore.draftsKey)_\(key)")
    }
}

private func loadExamDraft(traineeName: String, belt: Belt) -> [String: Int] {
    let key = draftKey(traineeName: traineeName, belt: belt)
    guard let data = UserDefaults.standard.data(forKey: "\(InternalExamStore.draftsKey)_\(key)"),
          let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
        return [:]
    }
    return decoded
}

private func removeExamDraft(traineeName: String, belt: Belt) {
    let key = draftKey(traineeName: traineeName, belt: belt)
    UserDefaults.standard.removeObject(forKey: "\(InternalExamStore.draftsKey)_\(key)")
}

private func loadRecentTrainees() -> [String] {
    UserDefaults.standard.stringArray(forKey: InternalExamStore.recentKey) ?? []
}

private func pushRecentTrainee(_ name: String, limit: Int = 10) {
    let clean = name.trimmed()
    guard !clean.isEmpty else { return }

    var list = loadRecentTrainees().filter { $0 != clean }
    list.insert(clean, at: 0)
    if list.count > limit {
        list = Array(list.prefix(limit))
    }
    UserDefaults.standard.set(list, forKey: InternalExamStore.recentKey)
}

private func saveLastTrainee(_ name: String) {
    UserDefaults.standard.set(name.trimmed(), forKey: InternalExamStore.lastKey)
}

private func loadLastTrainee() -> String {
    UserDefaults.standard.string(forKey: InternalExamStore.lastKey) ?? ""
}

// MARK: - String / Number utils

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
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
