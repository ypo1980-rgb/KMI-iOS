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

    private var summaryTitle: String {
        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let subTopic,
           !subTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "סיכום \(subTopic)"
        }

        if let topic,
           !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "סיכום \(topic)"
        }

        return "סיכום \(belt.heb)"
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
            SummaryBackground()

            ScrollView {
                VStack(spacing: 14) {

                    WhiteCard {
                        HStack(spacing: 10) {
                            SummaryStatPill(title: "בוצעו", value: doneCount, tint: .green)
                            SummaryStatPill(title: "לא בוצעו", value: notDoneCount, tint: .red)
                            SummaryStatPill(title: "נותרו", value: remainingCount, tint: .gray)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Chip "התקדמות"  ✅ toggle
                    HStack {
                        Spacer()

                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showProgressCard.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 14, weight: .heavy))

                                Text("התקדמות")
                                    .font(.system(size: 16, weight: .heavy))

                                Image(systemName: showProgressCard ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .heavy))
                                    .opacity(0.55)
                            }
                            .foregroundStyle(Color.black.opacity(0.80))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.purple.opacity(0.16)))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.top, 10)

                    // Progress Card (עיגול)
                    if showProgressCard {
                        WhiteCard {
                            VStack(spacing: 10) {
                                Text(progressCardTitle)
                                    .font(.system(size: 17, weight: .heavy))
                                    .foregroundStyle(Color.black.opacity(0.82))

                                ProgressRing(percent: percentAll)
                                    .frame(width: 170, height: 170)
                                    .padding(.vertical, 4)

                                Text("\(doneCount) מתוך \(totalCount)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.70))
                            }
                            .padding(.vertical, 14)
                        }
                        .padding(.horizontal, 16)
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
                        .padding(.leading, 16)
                        .padding(.trailing, 16)
                    } else {
                        ForEach(blocks) { b in
                            TopicSummaryCard(block: b)
                                .padding(.leading, 16)
                                .padding(.trailing, 16)
                        }
                    }

                    WhiteCard {
                        ShareLink(
                            item: shareSummaryText
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("שתף סיכום אימון")
                                    .font(.system(size: 16, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 22)
            }
        }
    }
    
    
    // MARK: - UI pieces
    
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
            WhiteCard {
                VStack(spacing: 10) {
                    
                    HStack {
                        Text("\(block.percent)% — \(block.title)")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.82))
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeOut(duration: 0.12)) { expanded.toggle() }
                        } label: {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.45))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.gray.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if expanded {
                        VStack(spacing: 0) {
                            ForEach(block.items) { it in
                                SummaryRow(title: it.title, mark: it.mark)
                                Divider().opacity(0.18)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.vertical, 10)
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
