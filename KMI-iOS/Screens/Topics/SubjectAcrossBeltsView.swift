import SwiftUI
import Shared

struct SubjectAcrossBeltsView: View {

    let subject: KMI_iOS.SubjectTopic
    let forcedSectionTitle: String?

    init(subject: KMI_iOS.SubjectTopic, forcedSectionTitle: String? = nil) {
        self.subject = subject
        self.forcedSectionTitle = forcedSectionTitle
    }

    // סדר חגורות כמו אצלך באנדרואיד
    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    @State private var selectedBelt: Belt = .orange

    // ✅ קטלוג מה-Shared (כמו בשאר המסכים)
    private let catalog = CatalogData.shared.data

    // MARK: - Local UI models (במקום SubjectItemsResolver מה-KMP)
    private struct UiItem: Identifiable {
        let id: String
        let displayName: String
        let topicTitle: String
    }

    private struct UiSection: Identifiable {
        let id: String
        let title: String
        let items: [UiItem]
    }

    // MARK: - Filtering helpers (כמו SubjectTopicContentView)
    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hardSubjectId(for subject: KMI_iOS.SubjectTopic) -> String? {

        switch subject.id {

        case "topic_breakfalls_rolls", "rolls_breakfalls":
            return "topic_breakfalls_rolls"

        case "kicks":
            return "topic_kicks"

        case "releases":
            return "releases"

        case "knife_defense":
            return "knife_defense"

        case "gun_threat_defense":
            return "gun_threat_defense"

        case "stick_defense":
            return "stick_defense"

        case "def_internal_punches":
            return "def_internal_punch"

        case "def_internal_kicks":
            return "def_internal_kick"

        case "def_external_punches":
            return "def_external_punch"

        case "def_external_kicks":
            return "def_external_kick"

        default:
            return nil
        }
    }
    
    private func containsAny(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.contains { t.contains(norm($0)) }
    }

    private func containsAll(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return keywords.allSatisfy { t.contains(norm($0)) }
    }

    private func containsNone(_ text: String, keywords: [String]) -> Bool {
        if keywords.isEmpty { return true }
        let t = norm(text)
        return !keywords.contains { t.contains(norm($0)) }
    }

    private func itemPasses(_ item: String, subTopicTitle: String?) -> Bool {
        let combined = (subTopicTitle ?? "") + " " + item

        if let hint = subject.subTopicHint, !hint.isEmpty {
            let ok = norm(subTopicTitle ?? "").contains(norm(hint)) || norm(item).contains(norm(hint))
            if !ok { return false }
        }

        if !subject.includeItemKeywords.isEmpty {
            if !containsAny(combined, keywords: subject.includeItemKeywords) { return false }
        }

        if !containsAll(combined, keywords: subject.requireAllItemKeywords) { return false }

        if !containsNone(combined, keywords: subject.excludeItemKeywords) { return false }

        return true
    }

    private func appendHardSectionTree(
        _ sec: HardSectionsCatalog.Section,
        belt: Belt,
        into out: inout [UiSection],
        parentPath: [String] = []
    ) {
        let currentPath = parentPath + [sec.title]
        let items = HardSectionsCatalog.shared.itemsFor(sec, belt: belt)

        if !items.isEmpty {
            let uiItems = items.map { raw in
                UiItem(
                    id: "\(belt.id)::\(sec.id)::\(raw)",
                    displayName: raw,
                    topicTitle: currentPath.joined(separator: " / ")
                )
            }

            out.append(
                UiSection(
                    id: "\(belt.id)::\(sec.id)",
                    title: sec.title,
                    items: uiItems
                )
            )
        }

        for child in sec.subSections {
            appendHardSectionTree(
                child,
                belt: belt,
                into: &out,
                parentPath: currentPath
            )
        }
    }

    private func toSharedSubject(_ local: KMI_iOS.SubjectTopic) -> Shared.SubjectTopic {
        Shared.SubjectTopic(
            id: local.id,
            titleHeb: local.titleHeb,
            topicsByBelt: local.topicsByBelt,
            subTopicHint: local.subTopicHint,
            includeItemKeywords: local.includeItemKeywords,
            requireAllItemKeywords: local.requireAllItemKeywords,
            excludeItemKeywords: local.excludeItemKeywords
        )
    }
    
    private func sections(for belt: Belt) -> [UiSection] {

        if let hardId = hardSubjectId(for: subject),
           let hardSections = HardSectionsCatalog.shared.sectionsForSubject(subjectId: hardId),
           !hardSections.isEmpty {

            let filteredHardSections: [HardSectionsCatalog.Section]
            if let forcedSectionTitle, !forcedSectionTitle.isEmpty {
                filteredHardSections = hardSections.filter { $0.title == forcedSectionTitle }
            } else {
                filteredHardSections = hardSections
            }

            var hardOut: [UiSection] = []

            for sec in filteredHardSections {

                appendHardSectionTree(
                    sec,
                    belt: belt,
                    into: &hardOut
                )
            }

            if !hardOut.isEmpty {
                return hardOut
            }
        }

        let sharedSubject = toSharedSubject(subject)

        let rawSections = SubjectItemsResolver.shared
            .resolveBySubject(belt: belt, subject: sharedSubject)

        let uiSections: [SubjectItemsResolver.UiSection]
        if let forcedSectionTitle, !forcedSectionTitle.isEmpty {
            uiSections = rawSections.filter { $0.title == forcedSectionTitle }
        } else {
            uiSections = rawSections
        }

        var out: [UiSection] = []

        for sec in uiSections {
            let items = sec.items

            if !items.isEmpty {
                let uiItems = items.enumerated().map { index, item in
                    UiItem(
                        id: "\(belt.id)::\(sec.title)::\(index)::\(item.displayName)",
                        displayName: item.displayName,
                        topicTitle: sec.title
                    )
                }

                out.append(
                    UiSection(
                        id: "\(belt.id)::\(sec.title)",
                        title: sec.title,
                        items: uiItems
                    )
                )
            }
        }

        return out
    }
    
    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(spacing: 8) {
                                Text(subject.titleHeb)
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .center)

                                if !subject.description.isEmpty {
                                    Text(subject.description)
                                        .font(.caption)
                                        .foregroundStyle(Color.black.opacity(0.55))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }

                        // ✅ קרוסלה אמיתית: Snap למרכז + מרכז מודגש
                        WhiteCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("חגורות")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.82))

                                BeltCarousel(
                                    belts: belts,
                                    selectedBelt: $selectedBelt,
                                    hasContent: { b in !sections(for: b).isEmpty },
                                    onSelect: { b in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            proxy.scrollTo(beltAnchorId(b), anchor: .top)
                                        }
                                    }
                                )
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }

                        ForEach(belts, id: \.self) { belt in

                            let secs = sections(for: belt)

                            if !secs.isEmpty {

                                VStack(spacing: 12) {

                                    HStack {
                                        Text("\(secs.reduce(0) { $0 + $1.items.count }) תרגילים")
                                            .font(.system(size: 15, weight: .heavy))
                                            .foregroundStyle(beltAccent(belt))

                                        Spacer()

                                        Text(beltTitleText(belt))
                                            .font(.system(size: 18, weight: .heavy))
                                            .foregroundStyle(beltAccent(belt))
                                    }
                                    .padding(.horizontal, 4)

                                    VStack(spacing: 10) {
                                        ForEach(secs) { sec in
                                            ForEach(sec.items) { it in
                                                NavigationLink {
                                                    ExerciseDetailView(
                                                        belt: belt,
                                                        topicTitle: it.topicTitle,
                                                        item: it.displayName
                                                    )
                                                } label: {
                                                    BeltExerciseRowCard(
                                                        title: it.displayName,
                                                        accent: beltAccent(belt)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(beltCardFill(belt))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(beltAccent(belt).opacity(0.18), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                                .id(beltAnchorId(belt))
                            }
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationTitle("לפי נושא")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for b in belts {
                if !sections(for: b).isEmpty {
                    selectedBelt = b
                    break
                }
            }
        }
    }

    private func beltAnchorId(_ belt: Belt) -> String {
        "belt::\(belt.id)"
    }

    private func beltCardFill(_ belt: Belt) -> Color {
        switch belt {
        case .yellow:
            return Color(red: 1.00, green: 0.97, blue: 0.86)
        case .orange:
            return Color(red: 0.99, green: 0.93, blue: 0.84)
        case .green:
            return Color(red: 0.91, green: 0.97, blue: 0.91)
        case .blue:
            return Color(red: 0.90, green: 0.95, blue: 1.00)
        case .brown:
            return Color(red: 0.95, green: 0.91, blue: 0.86)
        case .black:
            return Color(red: 0.90, green: 0.90, blue: 0.92)
        default:
            return Color.white.opacity(0.94)
        }
    }

    private func beltAccent(_ belt: Belt) -> Color {
        switch belt {
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
            return Color.black.opacity(0.25)
        }
    }

    private func beltTitleText(_ belt: Belt) -> String {
        switch belt {
        case .yellow: return "חגורה צהובה"
        case .orange: return "חגורה כתומה"
        case .green: return "חגורה ירוקה"
        case .blue: return "חגורה כחולה"
        case .brown: return "חגורה חומה"
        case .black: return "חגורה שחורה"
        default: return "חגורה"
        }
    }
}

private struct BeltExerciseRowCard: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Image(systemName: "star")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.gray.opacity(0.75))

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(accent)
                .frame(width: 6, height: 34)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - Belt carousel (Snap + Center highlight)
private struct BeltCarousel: View {

    let belts: [Belt]
    @Binding var selectedBelt: Belt
    let hasContent: (Belt) -> Bool
    let onSelect: (Belt) -> Void

    @State private var scrollId: Belt?

    var body: some View {
        GeometryReader { outer in
            let midX = outer.frame(in: .global).midX

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: -10) {   // ✅ חפיפה (כמו גלגל)
                    ForEach(belts, id: \.self) { b in
                        BeltWheelItem(
                            belt: b,
                            selectedBelt: $selectedBelt,
                            enabled: hasContent(b),
                            midX: midX
                        ) {
                            selectedBelt = b
                            scrollId = b
                            onSelect(b)
                        }
                        .id(b)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 86) // ✅ מקום ל"קשת"
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollId, anchor: .center)
            .onAppear { scrollId = selectedBelt }
            .onChange(of: selectedBelt) { _, newValue in scrollId = newValue }
        }
        .frame(height: 90)
    }
}

// MARK: - Single item with arc effect
private struct BeltWheelItem: View {

    let belt: Belt
    @Binding var selectedBelt: Belt
    let enabled: Bool
    let midX: CGFloat
    let onTap: () -> Void

    private var isSelected: Bool { selectedBelt == belt }

    var body: some View {
        GeometryReader { geo in
            let x = geo.frame(in: .global).midX
            let dist = abs(x - midX)

            // ✅ נורמליזציה של המרחק (0 במרכז, 1+ בצד)
            let t = min(dist / 160.0, 1.0)

            // ✅ מרכז גדול, צדדים קטנים
            let scale = (1.18 - (t * 0.35))

            // ✅ קשת: צדדים "עולים" למעלה
            let y = -(t * 16.0)

            Button {
                guard enabled else { return }
                onTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(beltColor(belt).opacity(isSelected ? 1.0 : 0.92))
                        .shadow(color: Color.black.opacity(isSelected ? 0.22 : 0.14),
                                radius: isSelected ? 10 : 7,
                                x: 0, y: isSelected ? 5 : 4)

                    // טבעת דקה כמו באנדרואיד
                    Circle()
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)

                    Text(beltShortHeb(belt))
                        .font(isSelected ? .headline.weight(.heavy) : .subheadline.weight(.bold))
                        .foregroundStyle(textColor(for: belt))
                        .padding(.horizontal, 8)
                }
                .frame(width: 60, height: 60)
                .opacity(enabled ? 1.0 : 0.30)
                .scaleEffect(scale)
                .offset(y: y)
                .animation(.easeInOut(duration: 0.16), value: isSelected)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
        .frame(width: 64, height: 86) // ✅ רוחב קטן + גובה לקשת
    }

    private func beltShortHeb(_ b: Belt) -> String {
        // קצר כדי שייכנס לעיגול (אפשר לשנות)
        switch b {
        case .white: return "לבן"
        case .yellow: return "צהוב"
        case .orange: return "כתום"
        case .green: return "ירוק"
        case .blue: return "כחול"
        case .brown: return "חום"
        case .black: return "שחור"
        default: return b.heb
        }
    }

    private func beltColor(_ b: Belt) -> Color {
        switch b {
        case .white:  return Color.white
        case .yellow: return Color(red: 0.98, green: 0.84, blue: 0.25)
        case .orange: return Color(red: 0.98, green: 0.62, blue: 0.20)
        case .green:  return Color(red: 0.20, green: 0.75, blue: 0.35)
        case .blue:   return Color(red: 0.22, green: 0.52, blue: 0.92)
        case .brown:  return Color(red: 0.55, green: 0.38, blue: 0.24)
        case .black:  return Color(red: 0.15, green: 0.15, blue: 0.16)
        default:      return Color.gray
        }
    }

    private func textColor(for b: Belt) -> Color {
        // טקסט כהה על לבן/צהוב/כתום, לבן על כחול/חום/שחור/ירוק
        switch b {
        case .white, .yellow, .orange:
            return Color.black.opacity(0.82)
        default:
            return Color.white.opacity(0.92)
        }
    }
}
