import SwiftUI
import Shared

// MARK: - Summary models (file-scope)

// זהה ללוגיקה מהתרגילים
enum SummaryMark: String {
    case done
    case notDone

    static func fromStoredValue(_ value: String) -> SummaryMark? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "done", "mastered":
            return .done
        case "notdone", "not_done", "unknown":
            return .notDone
        default:
            return nil
        }
    }
}

struct SummaryRowItem: Identifiable {
    let id: String
    let title: String
    let mark: SummaryMark?
}

struct SummaryTopicBlock: Identifiable {
    let id: String
    let title: String
    let items: [SummaryRowItem]

    var doneCount: Int { items.filter { $0.mark == .done }.count }
    var notDoneCount: Int { items.filter { $0.mark == .notDone }.count }
    var totalCount: Int { items.count }

    var percent: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(doneCount) / Double(totalCount)) * 100.0))
    }
}

struct SummaryView: View {
    let belt: Belt
    var topic: String? = nil
    var subTopic: String? = nil
    
    @ObservedObject var nav: AppNavModel
    @State private var showProgressCard: Bool = false
    @State private var showComparisonCard: Bool = false
    
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    private var effectiveLanguageCode: String {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in values {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "en" || clean == "english" {
                return "en"
            }

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
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

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
    private func normalizedSummaryText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased()
    }

    private func summarySafePart(_ value: String) -> String {
        normalizedSummaryText(value)
    }

    private func loadMark(
        topicTitle: String,
        subTopicTitle: String?,
        item: String,
        index: Int
    ) -> SummaryMark? {
        let defaults = UserDefaults.standard

        let beltId = belt.id
        let cleanTopic = summarySafePart(topicTitle)
        let cleanSubTopic = subTopicTitle.map(summarySafePart) ?? ""
        let cleanItem = summarySafePart(item)

        let topicKey = cleanSubTopic.isEmpty
            ? cleanTopic
            : "\(cleanTopic)__\(cleanSubTopic)"

        let directStringKeys = [
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",

            "mark.status_\(beltId)_\(topicKey)_\(index)_\(item)",
            "mark.status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",

            "kmi.mark.\(beltId).\(topicTitle).\(item)",
            "kmi.mark.\(beltId).\(cleanTopic).\(cleanItem)",
            "kmi.mark.\(beltId).\(topicKey).\(cleanItem)"
        ]

        for key in directStringKeys {
            if let raw = defaults.string(forKey: key),
               let mark = SummaryMark.fromStoredValue(raw) {
                return mark
            }
        }

        let directBoolKeys = [
            "exercise_\(beltId)_\(item)",
            "exercise_\(beltId)_\(cleanItem)",

            "status_\(beltId)_\(topicTitle)_\(index)_\(item)",
            "status_\(beltId)_\(topicTitle)_\(index)_\(cleanItem)",

            "status_\(beltId)_\(topicKey)_\(index)_\(item)",
            "status_\(beltId)_\(topicKey)_\(index)_\(cleanItem)",

            "\(beltId)_\(topicTitle)_\(item)",
            "\(beltId)_\(topicKey)_\(item)",
            "\(beltId)_\(cleanTopic)_\(cleanItem)",
            "\(beltId)_\(topicKey)_\(cleanItem)"
        ]

        for key in directBoolKeys {
            if defaults.object(forKey: key) != nil {
                return defaults.bool(forKey: key) ? .done : .notDone
            }
        }

        for entry in defaults.dictionaryRepresentation() {
            let normalizedKey = summarySafePart(entry.key)

            guard normalizedKey.contains(beltId),
                  normalizedKey.contains(cleanItem) else {
                continue
            }

            if let raw = entry.value as? String,
               let mark = SummaryMark.fromStoredValue(raw) {
                return mark
            }

            if let boolValue = entry.value as? Bool {
                return boolValue ? .done : .notDone
            }
        }

        return nil
    }
    
    // MARK: - Model for UI
    
    private struct SummaryRawTopic {
        let title: String
        let items: [String]
    }

    private var catalogTopics: [SummaryRawTopic] {
        TopicsEngine.shared.topicTitlesFor(belt: belt)
            .map { title in
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

                var allItems: [String] = []

                allItems.append(
                    contentsOf: ContentRepo.shared.getAllItemsFor(
                        belt: belt,
                        topicTitle: cleanTitle,
                        subTopicTitle: nil
                    )
                )

                let subTopicTitles = ContentRepo.shared.getSubTopicsFor(
                    belt: belt,
                    topicTitle: cleanTitle
                )
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

                for subTopicTitle in subTopicTitles {
                    allItems.append(
                        contentsOf: ContentRepo.shared.getAllItemsFor(
                            belt: belt,
                            topicTitle: cleanTitle,
                            subTopicTitle: subTopicTitle
                        )
                    )
                }

                return SummaryRawTopic(
                    title: cleanTitle,
                    items: allItems
                )
            }
    }
    
    private var blocks: [SummaryTopicBlock] {
        let filteredTopics: [SummaryRawTopic]

        if let topic, !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredTopics = catalogTopics.filter {
                $0.title.trimmingCharacters(in: .whitespacesAndNewlines) ==
                topic.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            filteredTopics = catalogTopics
        }

        return filteredTopics.compactMap { t in
            var out: [String] = []
            out.append(contentsOf: t.items)
            
            var seen = Set<String>()
            let uniq = out
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { seen.insert($0).inserted }

            let rows: [SummaryRowItem] = uniq.enumerated().map { index, item in
                let m = loadMark(
                    topicTitle: t.title,
                    subTopicTitle: subTopic,
                    item: item,
                    index: index
                )

                return SummaryRowItem(
                    id: "\(t.title)||\(subTopic ?? "")||\(item)",
                    title: item,
                    mark: m
                )
            }
            
            return SummaryTopicBlock(
                id: t.title,
                title: t.title,
                items: rows
            )
        }
    }
    
    private var totalCount: Int { blocks.reduce(0) { $0 + $1.totalCount } }
    private var doneCount: Int { blocks.reduce(0) { $0 + $1.doneCount } }
    private var notDoneCount: Int { blocks.reduce(0) { $0 + $1.notDoneCount } }
    private var markedCount: Int { doneCount + notDoneCount }
    private var remainingCount: Int { max(totalCount - markedCount, 0) }

    private var percentAll: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(doneCount) / Double(totalCount)) * 100.0))
    }

    private var markedPercentAll: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(markedCount) / Double(totalCount)) * 100.0))
    }
    
    private var comparisonTraineesCount: Int {
        // אין להציג נתונים זמניים.
        // עד חיבור iOS לנתוני ההשוואה האמיתיים מהשרת, מציגים מצב "אין מספיק נתונים".
        return 0
    }

    private var comparisonAveragePercent: Int {
        return 0
    }

    private var comparisonHasEnoughData: Bool {
        comparisonTraineesCount >= 2
    }

    private var comparisonBetterThanPercent: Int {
        guard comparisonHasEnoughData, comparisonAveragePercent > 0 else {
            return 0
        }

        if percentAll >= comparisonAveragePercent {
            return 100
        }

        return max(
            0,
            Int(round((Double(percentAll) / Double(comparisonAveragePercent)) * 100.0))
        )
    }

    private var comparisonStatusText: String {
        guard comparisonHasEnoughData else {
            return tr(
                "אין עדיין מספיק נתונים להשוואה מול מתאמנים אחרים.",
                "There is not enough data yet to compare with other trainees."
            )
        }

        if percentAll >= comparisonAveragePercent {
            return tr(
                "אתה מעל \(comparisonBetterThanPercent)% מהמתאמנים בחגורה שלך.",
                "You are above \(comparisonBetterThanPercent)% of trainees in your belt."
            )
        }

        return tr(
            "אתה מתחת לממוצע המתאמנים בחגורה שלך.",
            "You are below the average for trainees in your belt."
        )
    }
    
    private var summaryTitle: String {
        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let subTopic,
           !subTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(subTopic) - \(percentAll)%"
        }

        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(topic) - \(percentAll)%"
        }

        return "\(beltDisplayTitleForSummary()) - \(percentAll)%"
    }
    
    private func beltDisplayTitleForSummary() -> String {
        let clean = belt.heb.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.hasPrefix("חגורה") {
            return clean
        }

        return "חגורה \(clean)"
    }

    private func postSummaryTopTitleOverride() {
        NotificationCenter.default.post(
            name: Notification.Name("KMI_TOP_TITLE_OVERRIDE"),
            object: summaryTitle
        )
    }

    var body: some View {
        ZStack {
            KmiGradientBackground(forceTraineeStyle: false)

            VStack(spacing: 0) {

                summaryTopControls

                ScrollView {
                    VStack(spacing: 12) {

                        if showComparisonCard {
                            WhiteCard {
                                BeltComparisonStatusCard(
                                    traineesCount: comparisonTraineesCount,
                                    averagePercent: comparisonAveragePercent,
                                    userPercent: percentAll,
                                    statusText: comparisonStatusText,
                                    hasEnoughData: comparisonHasEnoughData,
                                    isEnglish: isEnglish,
                                    onClose: {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            showComparisonCard = false
                                        }
                                    }
                                )
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        if showProgressCard {
                            WhiteCard {
                                VStack(spacing: 10) {
                                    HStack {
                                        Spacer()

                                        Button {
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                showProgressCard = false
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 13, weight: .black))
                                                .foregroundStyle(Color.black.opacity(0.62))
                                                .frame(width: 32, height: 32)
                                                .background(Circle().fill(Color.black.opacity(0.06)))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Text(tr("מד התקדמות", "Progress meter"))
                                        .font(.system(size: 22, weight: .black))
                                        .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                                        .multilineTextAlignment(screenTextAlignment)
                                    
                                    ProgressRing(
                                        percent: markedPercentAll,
                                        doneCount: doneCount,
                                        notDoneCount: notDoneCount,
                                        remainingCount: remainingCount,
                                        totalCount: totalCount,
                                        isEnglish: isEnglish
                                    )
                                    .frame(width: 194, height: 194)
                                    .padding(.vertical, 4)

                                    Text(
                                        isEnglish
                                        ? "Marked \(markedCount) of \(totalCount)"
                                        : "סומנו \(markedCount) מתוך \(totalCount)"
                                    )
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))

                                    HStack(spacing: 8) {
                                        SummaryStatusChip(
                                            title: tr("יודע: \(doneCount)", "Known: \(doneCount)"),
                                            tint: Color(red: 0.30, green: 0.69, blue: 0.31)
                                        )

                                        SummaryStatusChip(
                                            title: tr("לא יודע: \(notDoneCount)", "Not known: \(notDoneCount)"),
                                            tint: Color(red: 0.90, green: 0.22, blue: 0.21)
                                        )

                                        SummaryStatusChip(
                                            title: tr("לא סומן: \(remainingCount)", "Open: \(remainingCount)"),
                                            tint: Color(red: 0.60, green: 0.64, blue: 0.70)
                                        )
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if blocks.isEmpty {
                            WhiteCard {
                                VStack(spacing: 10) {
                                    Text(tr("אין נתוני סיכום להצגה", "No summary data to display"))
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))

                                    Text(tr(
                                        "עדיין לא סומנו תרגילים עבור הבחירה הנוכחית",
                                        "No exercises have been marked for the current selection yet"
                                    ))
                                    
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.56))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 18)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        } else {
                            ForEach(blocks) { block in
                                TopicSummaryCard(
                                    block: block,
                                    isEnglish: isEnglish
                                )
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 88)
                }
            }

            VStack {
                Spacer()

                VStack(spacing: 0) {
                    summaryBottomBackButton
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                }
                .background(Color.white.opacity(0.96))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            postSummaryTopTitleOverride()

            DispatchQueue.main.async {
                postSummaryTopTitleOverride()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                postSummaryTopTitleOverride()
            }
        }
        .onChange(of: percentAll) { _, _ in
            postSummaryTopTitleOverride()

            DispatchQueue.main.async {
                postSummaryTopTitleOverride()
            }
        }
    }
    
    private var summaryTopControls: some View {
        HStack(spacing: 12) {
            summaryTopActionButton(
                title: tr("התקדמות", "Progress"),
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showProgressCard
            ) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showComparisonCard = false
                    showProgressCard.toggle()
                }
            }

            summaryTopActionButton(
                title: tr("השוואה", "Compare"),
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showComparisonCard
            ) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showProgressCard = false
                    showComparisonCard.toggle()
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func summaryTopActionButton(
        title: String,
        systemImage: String,
        isOpen: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.orange.opacity(0.90))

                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.78))

                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                isOpen ? Color.orange.opacity(0.11) : Color.white.opacity(0.90),
                                Color.orange.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isOpen ? Color.orange.opacity(0.26) : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.10), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var summaryBottomBackButton: some View {
        Button {
            nav.pop()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.50, green: 0.00, blue: 1.00),
                                Color(red: 0.25, green: 0.32, blue: 0.72),
                                Color(red: 0.02, green: 0.66, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(tr("חזרה למסך הנושאים", "Back to topics screen"))
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func beltShortTextForSummary() -> String {
        switch belt {
        case .white:
            return "ל"
        case .yellow:
            return "צ"
        case .orange:
            return "כ"
        case .green:
            return "י"
        case .blue:
            return "כח"
        case .brown:
            return "ח"
        case .black:
            return "ש"
        default:
            return "ח"
        }
    }

    private func beltAccentForSummary() -> Color {
        switch belt {
        case .white:
            return Color.gray.opacity(0.80)
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
            return Color.black.opacity(0.45)
        }
    }
    
    // MARK: - UI pieces
    
    private struct BeltComparisonStatusCard: View {
        let traineesCount: Int
        let averagePercent: Int
        let userPercent: Int
        let statusText: String
        let hasEnoughData: Bool
        let isEnglish: Bool
        let onClose: () -> Void

        private func tr(_ he: String, _ en: String) -> String {
            isEnglish ? en : he
        }
        
        var body: some View {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(Color(red: 0.18, green: 0.27, blue: 0.38))
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Text(tr("המצב שלך בחגורה", "Your belt progress"))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.24))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(.horizontal, 4)

                if hasEnoughData {
                    HStack(spacing: 8) {
                        ComparisonMetricBox(
                            value: "\(userPercent)%",
                            title: tr("אתה יודע", "You know"),
                            tint: Color.green.opacity(0.82)
                        )

                        ComparisonMetricBox(
                            value: "\(averagePercent)%",
                            title: tr("ממוצע", "Average"),
                            tint: Color.blue.opacity(0.72)
                        )

                        ComparisonMetricBox(
                            value: "\(traineesCount)",
                            title: tr("מתאמנים", "Trainees"),
                            tint: Color.gray.opacity(0.72)
                        )
                    }

                    Text(statusText)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(Color.green.opacity(0.84))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 2)
                } else {
                    Text(statusText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
            }
        }
    }

    private struct ComparisonMetricBox: View {
        let value: String
        let title: String
        let tint: Color

        var body: some View {
            VStack(spacing: 5) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(red: 0.25, green: 0.34, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.26), lineWidth: 1)
            )
        }
    }
    
    private struct ProgressRing: View {
        let percent: Int
        let doneCount: Int
        let notDoneCount: Int
        let remainingCount: Int
        let totalCount: Int
        let isEnglish: Bool
        
        private var donePart: CGFloat {
            guard totalCount > 0 else { return 0 }
            return CGFloat(doneCount) / CGFloat(totalCount)
        }

        private var notDonePart: CGFloat {
            guard totalCount > 0 else { return 0 }
            return CGFloat(notDoneCount) / CGFloat(totalCount)
        }

        private var remainingPart: CGFloat {
            guard totalCount > 0 else { return 1 }
            return CGFloat(remainingCount) / CGFloat(totalCount)
        }

        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.98))
                    .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 3)

                Circle()
                    .trim(from: 0, to: max(remainingPart, 0.001))
                    .stroke(
                        Color(red: 0.85, green: 0.85, blue: 0.89),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: donePart)
                    .stroke(
                        Color(red: 0.30, green: 0.69, blue: 0.31),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: donePart, to: min(donePart + notDonePart, 1.0))
                    .stroke(
                        Color(red: 0.90, green: 0.22, blue: 0.21),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: 128, height: 128)

                VStack(spacing: 5) {
                    Text("\(percent)%")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.24))

                    Text(isEnglish ? "Marked" : "סומנו")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(red: 0.30, green: 0.69, blue: 0.31))

                    Text(
                        isEnglish
                        ? "\(doneCount + notDoneCount) of \(totalCount)"
                        : "\(doneCount + notDoneCount) מתוך \(totalCount)"
                    )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.55))
                }
            }
        }
    }
    
    private struct SummaryStatusChip: View {
        let title: String
        let tint: Color

        var body: some View {
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.26), lineWidth: 1)
                )
        }
    }
    
    private struct TopicSummaryCard: View {
        let block: SummaryTopicBlock
        let isEnglish: Bool
        @State private var expanded: Bool = true

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        private var textAlignment: TextAlignment {
            isEnglish ? .leading : .trailing
        }
        
        var body: some View {
            VStack(spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        ButtonIcon(expanded: expanded)

                        Spacer(minLength: 0)

                        Text("\(block.title) — \(block.percent)%")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(spacing: 0) {
                        ForEach(block.items) { item in
                            SummaryRow(
                                title: item.title,
                                mark: item.mark,
                                isEnglish: isEnglish
                            )

                            if item.id != block.items.last?.id {
                                Divider()
                                    .opacity(0.14)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.88),
                                Color.white.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }

        private struct ButtonIcon: View {
            let expanded: Bool

            var body: some View {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black.opacity(0.08)))
            }
        }
    }
    
    private struct SummaryRow: View {
        let title: String
        let mark: SummaryMark?
        let isEnglish: Bool

        private var frameAlignment: Alignment {
            isEnglish ? .leading : .trailing
        }

        var body: some View {
            HStack(spacing: 10) {
                // icon מצב
                Group {
                    switch mark {
                    case .done:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green.opacity(0.85))
                    case .notDone:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.red.opacity(0.80))
                    default:
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color.gray.opacity(0.35))
                    }
                }
                .font(.system(size: 18, weight: .heavy))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }
}
