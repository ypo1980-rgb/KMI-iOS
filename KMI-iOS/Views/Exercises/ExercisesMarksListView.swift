import SwiftUI
import Shared

// MARK: - Storage (UserDefaults) for Favorites / Unknown
// תואם ל-Android: fav_<beltId>_<topicKey>  |  unknown_<beltId>_<topicKey>
// נשמר כ-JSON של מערך מחרוזות.
private enum MarksStore {

    static func readSet(_ key: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)).map(Set.init) ?? []
    }

    static func writeSet(_ set: Set<String>, key: String) {
        let arr = Array(set).sorted()
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func toggle(_ id: String, key: String) -> Bool {
        var s = readSet(key)
        if s.contains(id) {
            s.remove(id)
            writeSet(s, key: key)
            return false
        } else {
            s.insert(id)
            writeSet(s, key: key)
            return true
        }
    }

    static func set(_ id: String, isOn: Bool, key: String) {
        var s = readSet(key)
        if isOn { s.insert(id) } else { s.remove(id) }
        writeSet(s, key: key)
    }
}

private enum MarksTab: Int, CaseIterable, Identifiable {
    case all = 0
    case unknown = 1
    case favorites = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "הכל"
        case .unknown: return "לא יודע"
        case .favorites: return "מועדפים"
        }
    }
}

struct ExercisesMarksListView: View {
    let belt: Belt
    let topic: String
    let subTopic: String?

    // ✅ ניווט גלובאלי
    @EnvironmentObject private var nav: AppNavModel

    init(belt: Belt, topic: String, subTopic: String? = nil) {
        self.belt = belt
        self.topic = topic
        self.subTopic = subTopic
    }

    // ✅ catalog source (Shared)
    private let catalog = CatalogData.shared.data

    // UI
    @State private var tab: MarksTab = .all
    @State private var query: String = ""

    // ✅ sheet state
    @State private var showDetails: Bool = false
    @State private var selectedItemText: String = ""

    // state של סטים
    @State private var favs: Set<String> = []
    @State private var unknowns: Set<String> = []

    private var topicKey: String {
        if let st = subTopic, !st.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(topic)__\(st)"
        }
        return topic
    }

    private var favKey: String { "fav_\(belt.id)_\(topicKey)" }
    private var unknownKey: String { "unknown_\(belt.id)_\(topicKey)" }

    // כל הפריטים למסך הזה
    private var allItems: [String] {
        let topics = catalog[belt]?.topics ?? []
        if let t = topics.first(where: { $0.title == topic }) {

            // אם אין subTopic -> items + subTopics.items
            if subTopic == nil || subTopic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                let base = t.items
                let subs = t.subTopics.flatMap { $0.items }
                return Array(Set(base + subs)).sorted()
            }

            // יש subTopic: נחפש subTopic מדויק
            if let st = subTopic, let sub = t.subTopics.first(where: { $0.title == st }) {
                return sub.items
            }

            // fallback: אם subTopic לא נמצא
            let base = t.items
            let subs = t.subTopics.flatMap { $0.items }
            return Array(Set(base + subs)).sorted()
        }

        return []
    }

    private var filteredItems: [String] {
        var items = allItems

        switch tab {
        case .all:
            break
        case .unknown:
            items = items.filter { unknowns.contains($0) }
        case .favorites:
            items = items.filter { favs.contains($0) }
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var subtitleText: String {
        topic + (subTopic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? " • \(subTopic!)" : "")
    }

    var body: some View {
        KmiRootLayout(
            title: "כרטיסיות תרגילים – \(belt.heb)",
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: subtitleText,
            titleColor: KmiBeltPalette.color(for: belt)
        ) {
            ZStack {
                MarksBackground()

                VStack(spacing: 12) {

                    // ✅ כרטיס עליון (בלי הכותרת הכפולה מעל החיפוש)
                    MarksCard {
                        VStack(alignment: .leading, spacing: 10) {

                            // Search
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(MarksTheme.textSecondary)

                                TextField("חיפוש תרגיל…", text: $query)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .foregroundStyle(MarksTheme.textPrimary)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    // Tabs
                    tabsRow
                        .padding(.horizontal, 14)

                    // List
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(filteredItems, id: \.self) { item in
                                row(item)
                            }

                            if filteredItems.isEmpty {
                                Text("אין תרגילים להצגה בטאב הזה.")
                                    .foregroundStyle(MarksTheme.textSecondary)
                                    .padding(.top, 18)
                            }

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                }
            }
        }
        .onAppear {
            favs = MarksStore.readSet(favKey)
            unknowns = MarksStore.readSet(unknownKey)
        }
        .sheet(isPresented: $showDetails) {
            detailsSheet(selectedItemText)
        }
    }
    
    // MARK: Tabs
    private var tabsRow: some View {
        let allCount = allItems.count
        let unknownCount = allItems.filter { unknowns.contains($0) }.count
        let favCount = allItems.filter { favs.contains($0) }.count

        return HStack(spacing: 0) {
            tabButton(.all, count: allCount)
            tabButton(.unknown, count: unknownCount)
            tabButton(.favorites, count: favCount)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tabButton(_ t: MarksTab, count: Int) -> some View {
        let selected = tab == t
        return Button {
            tab = t
        } label: {
            VStack(spacing: 4) {
                Text(t.title)
                    .font(.system(size: 13, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? Color.white : MarksTheme.textSecondary)

                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(selected ? 0.18 : 0.10))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? MarksTheme.accent.opacity(0.28) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: Row
    private func row(_ item: String) -> some View {
        let isFav = favs.contains(item)
        let isUnknown = unknowns.contains(item)

        return Button {
            selectedItemText = item
            showDetails = true
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: isUnknown ? "questionmark.circle.fill" : "questionmark.circle")
                        .foregroundStyle(isUnknown ? Color.yellow : MarksTheme.textSecondary)

                    Image(systemName: isFav ? "star.fill" : "star")
                        .foregroundStyle(isFav ? Color.yellow : MarksTheme.textSecondary)
                }
                .font(.system(size: 15, weight: .semibold))

                Spacer()

                Text(item)
                    .foregroundStyle(MarksTheme.textPrimary)
                    .font(.system(size: 15, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Sheet
    private func detailsSheet(_ item: String) -> some View {
        let isFavNow = favs.contains(item)
        let isUnknownNow = unknowns.contains(item)

        return VStack(spacing: 14) {

            // Header
            HStack {
                Button("סגור") { showDetails = false }
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Text("מידע")
                    .font(.system(size: 18, weight: .heavy))

                Spacer()

                // spacer כדי לשמור center
                Color.clear.frame(width: 44, height: 1)
            }
            .padding(.top, 8)

            Text(item)
                .font(.system(size: 18, weight: .heavy))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("כאן יוצג הסבר לתרגיל (HOOK לחיבור ל-Shared Explanations).")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer()

            VStack(spacing: 10) {

                Button {
                    _ = MarksStore.toggle(item, key: favKey)
                    favs = MarksStore.readSet(favKey)
                } label: {
                    HStack {
                        Image(systemName: isFavNow ? "star.slash" : "star.fill")
                        Text(isFavNow ? "הסר ממועדפים" : "הוסף למועדפים")
                        Spacer()
                    }
                    .padding(12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    MarksStore.set(item, isOn: !isUnknownNow, key: unknownKey)
                    unknowns = MarksStore.readSet(unknownKey)
                } label: {
                    HStack {
                        Image(systemName: isUnknownNow ? "checkmark.circle" : "questionmark.circle")
                        Text(isUnknownNow ? "סמן כידוע (הסר 'לא יודע')" : "סמן כ'לא יודע'")
                        Spacer()
                    }
                    .padding(12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Local theme (שמות ייחודיים כדי לא להתנגש עם KmiTheme אצלך)

private enum MarksTheme {
    static let bgTop = Color(red: 0.01, green: 0.05, blue: 0.14)
    static let bgMid = Color(red: 0.07, green: 0.10, blue: 0.23)
    static let bgBot = Color(red: 0.11, green: 0.33, blue: 0.80)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.75)
    static let accent = Color(red: 0.13, green: 0.83, blue: 0.93)
}

private struct MarksBackground: View {
    var body: some View {
        LinearGradient(
            colors: [MarksTheme.bgTop, MarksTheme.bgMid, MarksTheme.bgBot],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct MarksCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MarksTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MarksTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MarksTheme.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }
}
