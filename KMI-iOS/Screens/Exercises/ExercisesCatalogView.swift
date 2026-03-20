import SwiftUI
import Shared

/// ✅ כל התרגילים מתוך CatalogData.shared.data
struct ExercisesCatalogView: View {

    private let catalog = CatalogData.shared.data

    // סדר חגורות כמו באנדרואיד (ללא לבנה)
    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

    @State private var selectedBelt: Belt = .orange
    @State private var query: String = ""

    private var topics: [CatalogData.Topic] {
        catalog[selectedBelt]?.topics ?? []
    }

    private var debugTopicLines: [String] {
        topics.flatMap { topic in
            var lines: [String] = []
            lines.append("נושא: \(topic.title) | ישיר: \(topic.items.count)")
            for sub in topic.subTopics {
                lines.append("  - תת נושא: \(sub.title) | פריטים: \(sub.items.count)")
            }
            return lines
        }
    }

    private func filtered(_ items: [String]) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            VStack(spacing: 10) {

                // Title
                HStack {
                    Text("כל התרגילים")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                // Belts carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(belts, id: \.self) { b in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    selectedBelt = b
                                }
                            } label: {
                                BeltPill(belt: b, isSelected: b == selectedBelt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                }

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.75))

                    TextField("חפש תרגיל…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)

                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .padding(.horizontal, 18)

                // Content
                ScrollView {
                    VStack(spacing: 12) {

                        TopicCard(title: "דיבאג – שמות נושאים בקטלוג", count: debugTopicLines.count) {
                            VStack(alignment: .trailing, spacing: 6) {
                                ForEach(debugTopicLines, id: \.self) { line in
                                    Text(line)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }

                        ForEach(topics, id: \.title) { t in
                            TopicCard(title: t.title, count: t.totalCount) {
                                let direct = filtered(t.items)
                                if !direct.isEmpty {
                                    ItemsSection(title: "תרגילים", items: direct)
                                }

                                ForEach(t.subTopics, id: \.title) { st in
                                    let items = filtered(st.items)
                                    if !items.isEmpty {
                                        ItemsSection(title: st.title, items: items)
                                    }
                                }

                                if direct.isEmpty && t.subTopics.allSatisfy({ filtered($0.items).isEmpty }) {
                                    Text("אין תוצאות.")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .padding(.top, 6)
                                }
                            }
                        }

                        if topics.isEmpty {
                            Text("אין נושאים להצגה")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.top, 18)
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UI components

private struct BeltPill: View {
    let belt: Belt
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(isSelected ? 1.0 : 0.65))
                .frame(width: 14, height: 14)

            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.18 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.24 : 0.14), lineWidth: 1)
        )
    }

    private var title: String {
        switch belt {
        case .yellow: return "צהובה"
        case .orange: return "כתומה"
        case .green:  return "ירוקה"
        case .blue:   return "כחולה"
        case .brown:  return "חומה"
        case .black:  return "שחורה"
        default:      return "חגורה"
        }
    }

    private var color: Color {
        switch belt {
        case .yellow: return .yellow
        case .orange: return .orange
        case .green:  return .green
        case .blue:   return .blue
        case .brown:  return Color(red: 0.55, green: 0.35, blue: 0.18)
        case .black:  return .black
        default:      return .white
        }
    }
}

private struct TopicCard<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: Content

    @State private var expanded: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(title)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("\(count) תרגילים")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .buttonStyle(.plain)

            if expanded {
                content
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct ItemsSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Spacer(minLength: 0)

                        Text(item)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)

                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - helpers

private extension CatalogData.Topic {
    var totalCount: Int {
        items.count + subTopics.reduce(0) { $0 + $1.items.count }
    }
}
