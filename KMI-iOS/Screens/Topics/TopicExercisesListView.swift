import SwiftUI
import Shared

/// מסך תרגילים של נושא בתוך חגורה (כמו Android)
struct TopicExercisesListView: View {
    let belt: Belt
    let topic: CatalogData.Topic
    let forcedSubTopicTitle: String?

    // ✅ ניווט גלובאלי מגיע מה-Environment
    @EnvironmentObject private var nav: AppNavModel

    // MARK: - Persistence (UserDefaults)
    fileprivate enum Mark: String {
        case done
        case notDone
    }

    private func markKey(item: String) -> String {
        let b = belt.id
        let t = topic.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = forcedSubTopicTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "__ALL__"
        let i = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return "kmi.mark.\(b).\(t).\(s).\(i)"
    }

    private func loadMark(item: String) -> Mark? {
        let key = markKey(item: item)
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return Mark(rawValue: raw)
    }

    private func setMark(_ mark: Mark?, item: String) {
        let key = markKey(item: item)
        if let mark {
            UserDefaults.standard.set(mark.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - UI state
    @State private var infoItem: String? = nil
    @State private var showInfoMenu: Bool = false
    @State private var infoFrames: [String: CGRect] = [:]
    @State private var goSummary: Bool = false
    @State private var goPractice: Bool = false
    @State private var marksCache: [String: Mark?] = [:]

    private func currentMark(for item: String) -> Mark? {
        if let cached = marksCache[item] { return cached }
        return loadMark(item: item)
    }

    private func toggleMark(_ mark: Mark, item: String) {
        let cur = currentMark(for: item)
        let next: Mark? = (cur == mark) ? nil : mark
        setMark(next, item: item)
        marksCache[item] = next
    }

    private func resetAllMarks() {
        for item in allItems {
            setMark(nil, item: item)
        }
        marksCache.removeAll()
    }

    private var allItems: [String] {
        var out: [String] = []

        if let forcedSubTopicTitle,
           let sub = topic.subTopics.first(where: { $0.title == forcedSubTopicTitle }) {
            out.append(contentsOf: sub.items)
        } else {
            out.append(contentsOf: topic.items)
            for st in topic.subTopics {
                out.append(contentsOf: st.items)
            }
        }

        var seen = Set<String>()
        return out
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private static func popupPosition(anchor: CGRect) -> CGPoint {
        let x = anchor.maxX - 120
        let y = anchor.maxY + 110
        return CGPoint(x: max(140, x), y: max(140, y))
    }

    var body: some View {
        KmiRootLayout(
            title: forcedSubTopicTitle ?? topic.title,
            nav: nav,
            roleLabel: "מצב\nמתאמן",
            selectedIcon: nil,
            rightText: "חגורה \(belt.heb) • \(allItems.count)",
            titleColor: KmiBeltPalette.color(for: belt)
        ) {
            ZStack {
                BeltTopicsGradientBackground()

                ScrollView {
                    VStack(spacing: 12) {

                        WhiteCard {
                            VStack(spacing: 6) {
                                Text(forcedSubTopicTitle ?? topic.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .center)

                                Text("חגורה: \(belt.heb) • תרגילים: \(allItems.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        WhiteCard {
                            VStack(spacing: 0) {
                                ForEach(Array(allItems.enumerated()), id: \.offset) { idx, item in
                                    ExerciseRow(
                                        title: item,
                                        mark: currentMark(for: item),
                                        onMarkDone: { toggleMark(.done, item: item) },
                                        onMarkNotDone: { toggleMark(.notDone, item: item) },
                                        onInfo: {
                                            infoItem = item
                                            withAnimation(.easeOut(duration: 0.12)) {
                                                showInfoMenu = true
                                            }
                                        }
                                    )

                                    if idx != allItems.count - 1 {
                                        Divider().opacity(0.25)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 18)
                    }
                    .padding(.bottom, 120)
                }

                if showInfoMenu, let item = infoItem, let anchor = infoFrames[item] {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        }

                    InfoPopupMenu(
                        itemTitle: item,
                        onClose: {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        },
                        onInfo: {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        },
                        onFavorite: {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        },
                        onRemoveFromTraining: {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        },
                        onHelpOrNote: {
                            withAnimation(.easeOut(duration: 0.12)) {
                                showInfoMenu = false
                            }
                        }
                    )
                    .position(Self.popupPosition(anchor: anchor))
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(5)
                }
            }
            .coordinateSpace(name: "ROOT")
            .onPreferenceChange(InfoFramePreferenceKey.self) { frames in
                infoFrames = frames
            }
            .safeAreaInset(edge: .bottom) {
                BottomActionBar(
                    onReset: { resetAllMarks() },
                    onPractice: { goPractice = true },
                    onSummary: { goSummary = true }
                )
            }
            .navigationDestination(isPresented: $goSummary) {
                SummaryView(belt: belt, nav: nav)
            }
            .sheet(isPresented: $goPractice) {
                RandomPracticeView(
                    nav: nav,
                    belt: belt,
                    topicTitle: forcedSubTopicTitle ?? topic.title,
                    items: allItems
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Row UI
private struct ExerciseRow: View {
    let title: String
    let mark: TopicExercisesListView.Mark?

    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            HStack(spacing: 10) {
                CircleButton(
                    systemName: "xmark",
                    isSelected: mark == .notDone,
                    selectedFill: Color.red.opacity(0.75),
                    unselectedFill: Color.red.opacity(0.18),
                    onTap: onMarkNotDone
                )

                CircleButton(
                    systemName: "checkmark",
                    isSelected: mark == .done,
                    selectedFill: Color.green.opacity(0.75),
                    unselectedFill: Color.green.opacity(0.18),
                    onTap: onMarkDone
                )
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 10)

            Button(action: onInfo) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.purple.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.purple.opacity(0.15)))
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: InfoFramePreferenceKey.self,
                                    value: [title: proxy.frame(in: .named("ROOT"))]
                                )
                        }
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}

private struct CircleButton: View {
    let systemName: String
    let isSelected: Bool
    let selectedFill: Color
    let unselectedFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedFill : unselectedFill)
                    .frame(width: 38, height: 38)

                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.95 : 0.55))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info anchor frames
private struct InfoFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Popup menu UI
private struct InfoPopupMenu: View {
    let itemTitle: String
    let onClose: () -> Void
    let onInfo: () -> Void
    let onFavorite: () -> Void
    let onRemoveFromTraining: () -> Void
    let onHelpOrNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Button(action: onInfo) {
                menuRow("מידע")
            }
            Divider().opacity(0.15)

            Button(action: onFavorite) {
                menuRow("הוסף למועדפים")
            }
            Divider().opacity(0.15)

            Button(action: onRemoveFromTraining) {
                menuRow("חזרה (מבטל מהתרגול)")
            }
            Divider().opacity(0.15)

            Button(action: onHelpOrNote) {
                menuRow("עזר / מחק הערה")
            }
        }
        .frame(width: 240)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(radius: 14, y: 6)
    }

    private func menuRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Bottom bar
private struct BottomActionBar: View {
    let onReset: () -> Void
    let onPractice: () -> Void
    let onSummary: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onReset) {
                Text("איפוס")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.85))
                    )
            }
            .buttonStyle(.plain)

            Button(action: onPractice) {
                Text("תרגול")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.purple.opacity(0.75))
                    )
            }
            .buttonStyle(.plain)

            Button(action: onSummary) {
                Text("מסך סיכום")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.blue.opacity(0.75))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.96))
                .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
    }
}
