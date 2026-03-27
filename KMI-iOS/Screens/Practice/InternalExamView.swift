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
    
    @State private var marksMap: [String: Int] = [:]
    @State private var expandedTopic: String? = nil

    init(belt: Belt) {
        self.belt = belt
        _currentBelt = State(initialValue: belt)
    }

    var body: some View {
        Group {
            if coach.isLoading {
                ProgressView("בודק הרשאות…")
            } else if coach.isCoach {
                examContent
            } else {
                VStack(spacing: 10) {
                    Text("גישה למאמנים בלבד")
                        .font(.title3.weight(.heavy))

                    Text("ההרשאה נקבעת בשרת לפי מספר טלפון")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await coach.checkCoach(userRole: auth.userRole)
            bootstrapInitialState()
        }
        .onChange(of: traineeName) { _ in
            recentTrainees = loadRecentTrainees()
        }
        .onChange(of: currentBelt) { _ in
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
                    Image(systemName: "chevron.left")
                }
            }
        }

        .navigationBarTitleDisplayMode(.inline)

        .sheet(isPresented: $showPickTraineeDialog) {
            traineePickerSheet
        }
        .alert("שמירת מבחן", isPresented: $showExitDialog) {

            Button("שמור") {
                saveCurrentExam()
                dismiss()
            }

            Button("צא בלי לשמור", role: .destructive) {
                dismiss()
            }

            Button("ביטול", role: .cancel) { }

        } message: {
            Text("האם לשמור את המבחן לפני היציאה?")
        }
        .alert("מבחן שמור נמצא", isPresented: $showResumeDialog) {
            Button("המשך") {
                marksMap = pendingLoadedDraft
                hasUnsavedChanges = false
            }
            Button("מבחן חדש", role: .destructive) {
                marksMap.removeAll()
                removeExamDraft(traineeName: traineeName, belt: currentBelt)
                traineeName = ""
                showTraineeNameBox = true
                resumeCheckedKey = nil
                hasUnsavedChanges = false
            }
            Button("ביטול", role: .cancel) { }
        } message: {
            Text("נמצא מבחן שמור מהפעם האחרונה. להמשיך ממנו או להתחיל מבחן חדש?")
        }
    }

    // MARK: - Main Content

    private var examContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.02, blue: 0.09),
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.12, green: 0.23, blue: 0.54),
                    Color(red: 0.22, green: 0.74, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                traineeHeaderSection

                BeltSelectorView(
                    currentBelt: $currentBelt,
                    accent: beltAccentColor(for: currentBelt)
                )

                SummaryCardView(
                    currentBelt: currentBelt,
                    marksMap: marksMap,
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
                                title: group.topic,
                                expanded: expandedTopic == group.topic
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedTopic = (expandedTopic == group.topic ? nil : group.topic)
                                }
                            }

                            if expandedTopic == group.topic {
                                ForEach(group.items) { item in
                                    ExerciseRowView(
                                        name: item.name,
                                        score: marksMap[item.id],
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
                    onSave: saveCurrentExam,
                    onShare: shareSummaryText
                )
                .contextMenu {
                    Button("ייצוא PDF") {
                        exportPdf()
                    }
                }
            }
        }
    }

    private var traineeHeaderSection: some View {
        VStack(spacing: 6) {
            if showTraineeNameBox {
                HStack(spacing: 10) {
                    TextField("שם הנבחן", text: $traineeName)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .onSubmit {
                            _ = commitTraineeNameAndCollapse()
                        }

                    Button("אישור") {
                        _ = commitTraineeNameAndCollapse()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(traineeName.trimmed().isEmpty)
                }
                .padding(10)
                .background(Color(red: 0.88, green: 0.95, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            } else if !traineeName.trimmed().isEmpty {
                HStack(spacing: 8) {
                    Text(traineeName.trimmed())
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Button("החלף") {
                        recentTrainees = loadRecentTrainees()
                        showPickTraineeDialog = true
                    }
                    .buttonStyle(.bordered)

                    Button("חדש") {
                        marksMap.removeAll()
                        traineeName = ""
                        showTraineeNameBox = true
                        resumeCheckedKey = nil
                    }
                    .buttonStyle(.bordered)
                }
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
                    Text("אין נבחנים שמורים עדיין.")
                        .foregroundStyle(.secondary)
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
                                Spacer()
                                Text(name)
                                    .foregroundStyle(.primary)
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
                        Spacer()
                        Text("נבחן חדש")
                    }
                }
            }
            .navigationTitle("בחר נבחן")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
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
        guard commitTraineeNameAndCollapse() else { return }
        saveExamDraft(traineeName: traineeName.trimmed(), belt: currentBelt, marksMap: marksMap)
        pushRecentTrainee(traineeName.trimmed())
        saveLastTrainee(traineeName.trimmed())
        hasUnsavedChanges = false
    }

    private func shareSummaryText() {

        let text = session.shareText

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

            let text = session.shareText

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]

            text.draw(
                in: CGRect(x: 40, y: 40, width: 515, height: 760),
                withAttributes: attrs
            )
        }

        let tmp = FileManager.default.temporaryDirectory
        let file = tmp.appendingPathComponent("internal_exam.pdf")

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
        let rawItems = ExamDataSource.itemsForBelt(belt)

        return rawItems.enumerated().map { index, rawName in
            let cleanedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            return ExamExerciseItem(
                id: "\(belt.id)_\(cleanedName)_\(index)",
                belt: belt,
                topic: "כללי",
                name: cleanedName.isEmpty ? "ללא שם" : cleanedName
            )
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

    var summaryText: String {
        switch percent {
        case 85...: return "עבר בהצטיינות"
        case 70...: return "עבר"
        case 50...: return "נדרש שיפור"
        default: return "לא עבר"
        }
    }

    var score10: Double {
        guard maxScore > 0 else { return 0 }
        return (totalScore / maxScore) * 10.0
    }

    var shareText: String {
        """
        דו״ח מבחן פנימי
        נבחן: \(traineeName.isEmpty ? "—" : traineeName)
        חגורה: \(belt.heb)
        ציון: \(score10.scoreString()) / 10 (\(percent)%)
        סטטוס: \(summaryText)
        """
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

    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

    var body: some View {
        Menu {
            ForEach(belts, id: \.id) { belt in
                Button(belt.heb) {
                    currentBelt = belt
                }
            }
        } label: {
            HStack {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("חגורה במבחן")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(currentBelt.heb)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(accent.opacity(0.30))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent.opacity(0.95), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
        }
    }
}

private struct SummaryCardView: View {
    let currentBelt: Belt
    let marksMap: [String: Int]
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

        let summaryText: String = {
            switch percent {
            case 85...: return "עבר בהצלחה רבה"
            case 70...: return "עבר בהצלחה"
            case 50...: return "בינוני – נדרש שיפור"
            default: return "לא עבר את המבחן"
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .trailing, spacing: 6) {
                HStack {
                    Text(expanded ? "▲" : "▼")
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("סיכום מבחן")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Text("מצטבר: \(totalScore10.scoreString()) / 10 (\(percent)%)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if expanded && !beltScores.isEmpty {
                    Divider()
                    ForEach(beltScores, id: \.0.id) { belt, score in
                        Text("\(belt.heb): \(score.score10.scoreString()) / 10 (\(score.percent)%)")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 1.0, green: 0.95, blue: 0.80))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct TopicHeaderView: View {
    let title: String
    let expanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(expanded ? "▲" : "▼")
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Spacer()

                Text(title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.88, green: 0.95, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }
}

private struct ExerciseRowView: View {
    let name: String
    let score: Int?
    let onScoreChange: (Int?) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(name)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ScoreChipView: View {
    let value: Int
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let base = scoreColor(value)
        let background = selected ? base.opacity(0.95) : base.opacity(0.40)

        Button(action: onTap) {
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? base : base.opacity(0.85), lineWidth: selected ? 2 : 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct BottomActionBarView: View {
    let session: InternalExamSession
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("ציון: \(session.score10.scoreString()) / 10 (\(session.percent)%)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button("שמור", action: onSave)
                .buttonStyle(.borderedProminent)

            Button("שתף", action: onShare)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
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
