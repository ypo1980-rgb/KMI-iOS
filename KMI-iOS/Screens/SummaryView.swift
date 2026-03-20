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
        catalogTopics.map { t in
            var out: [String] = []
            out.append(contentsOf: t.items)
            for st in t.subTopics { out.append(contentsOf: st.items) }
            
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
    
    private var percentAll: Int {
        guard totalCount > 0 else { return 0 }
        return Int(round((Double(doneCount) / Double(totalCount)) * 100.0))
    }
    
    var body: some View {
        KmiRootLayout(
            title: "סיכום \(belt.heb)",
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: "\(percentAll)%",
            titleColor: KmiBeltPalette.color(for: belt)
        ) {
            ZStack {
                SummaryBackground()
                
                ScrollView {
                    VStack(spacing: 14) {
                        
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
                                    Text("מד התקדמות – חגורה \(belt.heb)")
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
                        
                        ForEach(blocks) { b in
                            TopicSummaryCard(block: b)
                                .padding(.leading, 16)
                                .padding(.trailing, 16)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 22)
                }
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
}
