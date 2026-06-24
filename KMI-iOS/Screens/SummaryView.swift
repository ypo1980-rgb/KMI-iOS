import SwiftUI
import Shared

// MARK: - Summary models (file-scope)

// זהה ללוגיקה מהתרגילים
enum SummaryMark: String {
    case done
    case notDone
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
    
    // אותו key כמו TopicExercisesListView (חשוב!)
    private func markKey(topicTitle: String, item: String) -> String {
        let b = belt.id
        let t = topicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.mark.\(b).\(t).\(i)"
    }
    
    private func loadMark(topicTitle: String, item: String) -> SummaryMark? {
        let key = markKey(topicTitle: topicTitle, item: item)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return SummaryMark(rawValue: raw)
    }
    
    // MARK: - Model for UI
    
    private var catalogTopics: [CatalogData.Topic] {
        let catalog = CatalogData.shared.data
        return catalog[belt]?.topics ?? []
    }
    
    private var blocks: [SummaryTopicBlock] {
        let filteredTopics: [CatalogData.Topic]

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

            if let subTopic, !subTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let st = t.subTopics.first(where: {
                    $0.title.trimmingCharacters(in: .whitespacesAndNewlines) ==
                    subTopic.trimmingCharacters(in: .whitespacesAndNewlines)
                }) {
                    out.append(contentsOf: st.items)
                } else {
                    return nil
                }
            } else {
                out.append(contentsOf: t.items)
                for st in t.subTopics { out.append(contentsOf: st.items) }
            }

            var seen = Set<String>()
            let uniq = out
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { seen.insert($0).inserted }

            let rows: [SummaryRowItem] = uniq.map { item in
                let m = loadMark(topicTitle: t.title, item: item)
                return SummaryRowItem(
                    id: "\(t.title)||\(item)",
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
    private var remainingCount: Int { max(totalCount - doneCount - notDoneCount, 0) }

    private var percentAll: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(doneCount) / Double(totalCount)) * 100.0))
    }

    private var comparisonTraineesCount: Int {
        // זמני עד חיבור לנתוני אמת של מתאמנים אחרים.
        // באנדרואיד זה מגיע מלוגיקת השוואה מול מתאמנים באותה חגורה.
        return 2
    }

    private var comparisonAveragePercent: Int {
        // זמני עד חיבור לנתוני אמת.
        // כרגע מציג ממוצע לפי אחוז ההתקדמות המקומי כדי שהכרטיס יעבוד יציב.
        return percentAll
    }

    private var comparisonBetterThanPercent: Int {
        guard comparisonAveragePercent > 0 else {
            return percentAll > 0 ? 100 : 0
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
        if percentAll >= comparisonAveragePercent {
            return "אתה מעל \(comparisonBetterThanPercent)% מהמתאמנים בחגורה שלך."
        }

        return "אתה מתחת לממוצע המתאמנים בחגורה שלך."
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
    
    private var progressCardTitle: String {
        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let subTopic,
           !subTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "מד התקדמות – \(topic) / \(subTopic)"
        }

        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "מד התקדמות – \(topic)"
        }

        return "מד התקדמות – חגורה \(belt.heb)"
    }

    private var shareSummaryText: String {

        var text = "סיכום אימון – חגורה \(belt.heb)\n"

        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "נושא: \(topic)\n"
        }

        if let subTopic,
           !subTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "תת נושא: \(subTopic)\n"
        }

        text += "\nבוצעו: \(doneCount)"
        text += "\nלא בוצעו: \(notDoneCount)"
        text += "\nנותרו: \(remainingCount)"
        text += "\nאחוז השלמה: \(percentAll)%"

        return text
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

                                    Text(progressCardTitle)
                                        .font(.system(size: 17, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.76))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .multilineTextAlignment(.center)

                                    ProgressRing(percent: percentAll)
                                        .frame(width: 190, height: 190)
                                        .padding(.vertical, 4)

                                    Text("\(doneCount) מתוך \(totalCount)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.62))
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
                                    Text("אין נתוני סיכום להצגה")
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))

                                    Text("עדיין לא סומנו תרגילים עבור הבחירה הנוכחית")
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
                                TopicSummaryCard(block: block)
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

                summaryBottomBackButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
        }
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
                title: "השוואה",
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showComparisonCard
            ) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showProgressCard = false
                    showComparisonCard.toggle()
                }
            }

            summaryTopActionButton(
                title: "התקדמות",
                systemImage: "chart.line.uptrend.xyaxis",
                isOpen: showProgressCard
            ) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showComparisonCard = false
                    showProgressCard.toggle()
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
    
    private var beltBadgeForSummary: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.88))
                .overlay(
                    Circle()
                        .stroke(beltAccentForSummary().opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

            Text(beltShortTextForSummary())
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(beltAccentForSummary())
                .minimumScaleFactor(0.72)
        }
        .frame(width: 42, height: 42)
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

                    Text("חזרה למסך הנושאים")
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
        let onClose: () -> Void

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

                    Text("המצב שלך בחגורה")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.24))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    ComparisonMetricBox(
                        value: "\(userPercent)%",
                        title: "אתה יודע",
                        tint: Color.green.opacity(0.82)
                    )

                    ComparisonMetricBox(
                        value: "\(averagePercent)%",
                        title: "ממוצע",
                        tint: Color.blue.opacity(0.72)
                    )

                    ComparisonMetricBox(
                        value: "\(traineesCount)",
                        title: "מתאמנים",
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
    
    private struct SummaryBackground: View {
        var body: some View {
            Color(red: 0.98, green: 0.94, blue: 0.86) // בז' כמו בתמונה
                .ignoresSafeArea()
        }
    }
    
    private struct ProgressRing: View {
        let percent: Int
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.20), lineWidth: 14)
                
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, percent))) / 100.0)
                    .stroke(
                        Color.orange.opacity(0.92),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(percent)%")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.82))
                }
            }
        }
    }
    
    private struct TopicSummaryCard: View {
        let block: SummaryTopicBlock
        @State private var expanded: Bool = true
        
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
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(spacing: 0) {
                        ForEach(block.items) { item in
                            SummaryRow(title: item.title, mark: item.mark)

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
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private struct SummaryStatPill: View {
        let title: String
        let value: Int
        let tint: Color

        var body: some View {
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.82))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.58))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
        }
    }
}
