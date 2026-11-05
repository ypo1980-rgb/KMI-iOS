import SwiftUI
import Shared
import UIKit
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Carries the exact visible selection through the existing practice route.
/// ContentView must decode this before building RandomPracticeView (see integration patch).
struct ExerciseCardsPracticeSelection: Codable {
    let topic: String
    let items: [String]
    let sourceTopicsByItem: [String: [String]]

    private static let prefix = "__KMI_EXERCISE_CARDS__:"

    func encodedToken() throws -> String {
        Self.prefix + (try JSONEncoder().encode(self)).base64EncodedString()
    }

    static func decode(_ token: String) -> Self? {
        guard token.hasPrefix(prefix),
              let data = Data(base64Encoded: String(token.dropFirst(prefix.count)))
        else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

@MainActor
struct ExercisesTabsView: View {
    let belt: Belt
    let topicTitle: String
    let subTopicTitle: String?
    let onPractice: (Belt, String) -> Void
    let onHome: () -> Void

    private typealias Mark = MaterialsView.RowMark
    private typealias CoachStatus = MaterialsView.CoachMaterialStatus

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("kmi_app_language") private var language = ""
    @AppStorage("selected_language_code") private var selectedLanguage = ""
    @AppStorage("app_language") private var legacyLanguage = ""
    @AppStorage("initial_language_code") private var initialLanguage = ""
    @AppStorage("active_user_mode") private var activeMode = ""
    @AppStorage("last_active_app_role") private var lastMode = ""
    @AppStorage("user_role") private var userRole = ""
    @AppStorage("role") private var legacyRole = ""
    @AppStorage("userRole") private var camelRole = ""
    @AppStorage("profile_role") private var profileRole = ""

    @ObservedObject private var favorites = ExerciseFavoritesStore.shared
    @ObservedObject private var notes = ExerciseNotesStore.shared

    private struct Location: Hashable {
        let topicKey: String
        let statusID: String
        let canonicalID: String
    }

    private struct ExerciseItem: Identifiable {
        let id: String
        let raw: String
        let topic: String
        let subtopic: String?
        let identity: ExerciseIdentityResolverIOS.Identity
        let locations: [Location]
        let writeLocation: Location
        let sourceTopics: [String]
    }

    private struct RowState: Equatable {
        var mark: Mark?
        var markDate: Double = 0
        var coach: Set<CoachStatus> = []
        var coachDates: [CoachStatus: Double] = [:]
        var excluded = false
        var note = ""
        var noteConflict = false
    }

    private enum Filter: Int, Identifiable {
        case all, unknown, favorites, taught, practiced, reinforcement
        var id: Int { rawValue }
    }

    private struct NoteContext: Identifiable {
        let id: String
        let item: ExerciseItem
        let userID: String
        let beltID: String
        let original: String
    }

    @State private var selectedFilter: Filter = .all
    @State private var items: [ExerciseItem] = []
    @State private var states: [String: RowState] = [:]
    @State private var selectedInfo: ExerciseItem?
    @State private var noteContext: NoteContext?
    @State private var noteDraft = ""
    @State private var noteSaveFailed = false
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var isVisible = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var currentUserID = ""
    @State private var loadRequestID = UUID()
    @State private var exportRequestID = UUID()
    @State private var loadedScopeID: String?

    #if canImport(FirebaseAuth)
    @State private var authListener: AuthStateDidChangeListenerHandle?
    #endif

    private var isEnglish: Bool {
        for raw in [language, selectedLanguage, legacyLanguage, initialLanguage] {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if value == "en" || value == "english" || value.hasPrefix("en-") { return true }
            if value == "he" || value == "hebrew" || value == "עברית" || value.hasPrefix("he-") { return false }
        }
        return false
    }

    private var isCoach: Bool {
        let role = [activeMode, lastMode, userRole, legacyRole, camelRole, profileRole]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { !$0.isEmpty } ?? ""
        return ["coach", "trainer", "instructor", "מאמן", "מדריך", "coach_user", "kmi_coach"].contains(role)
    }

    private var direction: LayoutDirection { isEnglish ? .leftToRight : .rightToLeft }
    private var primary: Color { KmiAppTheme.onSurface(for: colorScheme) }
    private var secondary: Color { KmiAppTheme.onSurfaceVariant(for: colorScheme) }
    private var accent: Color {
        belt == .white ? KmiAppTheme.secondary(for: colorScheme) : KmiBeltPalette.color(for: belt)
    }
    private var practiceContentColor: Color {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let color = UIColor(KmiBeltPalette.color(for: belt)).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return KmiAppTheme.onSecondary(for: colorScheme)
        }
        func linear(_ value: CGFloat) -> Double {
            let channel = Double(value)
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance < 0.55 ? KmiAppTheme.onSecondary(for: .light) : KmiAppTheme.onSurface(for: .light)
    }
    private var scopeID: String { [belt.id, topicTitle, subTopicTitle ?? ""].joined(separator: "||") }
    private var filters: [Filter] {
        isCoach ? [.all, .taught, .practiced, .reinforcement] : [.all, .unknown, .favorites]
    }
    private var filteredItems: [ExerciseItem] { items.filter { matches($0, filter: selectedFilter) } }
    private var practiceItems: [ExerciseItem] { filteredItems.filter { !state($0).excluded } }

    private func tr(_ he: String, _ en: String) -> String { isEnglish ? en : he }
    private func clean(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func decodeTitle(_ value: String) -> String { clean(value.removingPercentEncoding ?? value) }
    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && seen.insert($0).inserted }
    }
    private func title(_ item: ExerciseItem) -> String {
        KmiEnglishTitleResolver.title(for: item.identity.displayTitle, isEnglish: isEnglish)
    }
    private func state(_ item: ExerciseItem) -> RowState { states[item.id] ?? RowState() }
    private func label(_ filter: Filter) -> String {
        switch filter {
        case .all: return tr("הכול", "All")
        case .unknown: return tr("לא יודע", "Unknown")
        case .favorites: return tr("מועדפים", "Favorites")
        case .taught: return tr("נלמד", "Taught")
        case .practiced: return tr("לתרגול", "Practice")
        case .reinforcement: return tr("לשיפור", "Improve")
        }
    }
    private func matches(_ item: ExerciseItem, filter: Filter) -> Bool {
        let value = state(item)
        switch filter {
        case .all: return true
        case .unknown: return value.mark == .unknown
        case .favorites: return favorites.contains(item.raw)
        case .taught: return value.coach.contains(.taught)
        case .practiced: return value.coach.contains(.practiced)
        case .reinforcement: return value.coach.contains(.needsReinforcement)
        }
    }

    var body: some View {
        ZStack {
            KmiAppBackground()
            VStack(spacing: 0) {
                filterBar
                ScrollView {
                    LazyVStack(spacing: 7) {
                        if !isLoading && filteredItems.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredItems) { item in
                                exerciseCard(item)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            if isLoading || isExporting { KmiLoadingOverlay() }
        }
        .environment(\.layoutDirection, direction)
        .safeAreaInset(edge: .bottom, spacing: 0) { practiceBar }
        .task(id: scopeID) { await loadCatalog() }
        .onAppear {
            isVisible = true
            startAuthListener()
        }
        .onDisappear {
            isVisible = false
            loadRequestID = UUID()
            exportRequestID = UUID()
            isExporting = false
            stopAuthListener()
            selectedInfo = nil
            noteContext = nil
            noteDraft = ""
        }
        .onChange(of: isCoach) { _, _ in
            selectedFilter = .all
            exportRequestID = UUID()
            isExporting = false
            refreshStates()
        }
        .onChange(of: selectedFilter) { _, _ in
            exportRequestID = UUID()
            isExporting = false
        }
        .onChange(of: isEnglish) { _, _ in
            exportRequestID = UUID()
            isExporting = false
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
        ) { _ in
            guard isVisible, !isLoading else { return }
            // Read-only refresh: no migration writes or reload loops.
            refreshStates()
        }
        .onReceive(notes.$revision) { _ in
            guard isVisible, !isLoading else { return }
            refreshStates()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KMI_GLOBAL_SHARE_REQUEST"))) { notification in
            guard isVisible, selectedInfo == nil, noteContext == nil,
                  let request = notification.object as? NSMutableDictionary,
                  request["handled"] as? Bool != true else { return }
            request["handled"] = true
            guard !isLoading, !isExporting, !showShare else { return }
            exportPDF()
        }
        .sheet(item: $selectedInfo, onDismiss: { refreshStates() }) { item in
            ExerciseExplanationDialog(
                belt: belt, topic: item.topic, item: item.raw,
                branch: "", groupKey: "", isEnglish: isEnglish
            )
        }
        .sheet(item: $noteContext, onDismiss: {
            noteDraft = ""
            noteSaveFailed = false
            refreshStates()
        }) { context in
            ExerciseNoteSheet(
                title: title(context.item), noteText: $noteDraft,
                isEnglish: isEnglish,
                onSave: { saveNote(context) },
                shouldDismissAfterSave: { !noteSaveFailed }
            )
            .alert(tr("לא ניתן לשמור", "Unable to save"), isPresented: $noteSaveFailed) {
                Button(tr("אישור", "OK"), role: .cancel) {}
            } message: {
                Text(tr(
                    "החשבון או ההערה השתנו. הטיוטה נשארה פתוחה וההערה הקיימת לא נדרסה.",
                    "The account or note has changed. Your draft remains open and the existing note was not overwritten."
                ))
            }
        }
        .sheet(isPresented: $showShare, onDismiss: { shareItems.removeAll() }) {
            KmiShareSheet(items: shareItems)
        }
        .alert(tr("כרטיסיות תרגילים", "Exercise Cards"), isPresented: $showMessage) {
            Button(tr("אישור", "OK"), role: .cancel) {}
        } message: { Text(message) }
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(filters) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    VStack(spacing: 4) {
                        Text(label(filter))
                            .kmiTypography(.secondary).fontWeight(.black)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text("\(items.filter { matches($0, filter: filter) }.count)")
                            .kmiTypography(.secondary).fontWeight(.bold).monospacedDigit()
                        Capsule()
                            .fill(KmiAppTheme.sectionHeaderContentColor)
                            .frame(width: 30, height: 3)
                            .opacity(selectedFilter == filter ? 1 : 0)
                    }
                    .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                    .padding(.horizontal, 4).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                if filter != filters.last {
                    Rectangle().fill(KmiAppTheme.sectionHeaderContentColor.opacity(0.65))
                        .frame(width: 1, height: 46)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(KmiAppTheme.sectionHeaderBrush)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack").kmiIconSize(30).foregroundStyle(secondary)
            Text(tr("אין תרגילים להצגה", "No exercises to display"))
                .kmiTypography(.sectionTitle).fontWeight(.bold)
            Text(tr("בחר כרטיסייה אחרת כדי לראות תרגילים נוספים.", "Choose another tab to see more exercises."))
                .kmiTypography(.body).foregroundStyle(secondary)
        }
        .foregroundStyle(primary).multilineTextAlignment(.center)
        .padding(22).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(KmiAppTheme.surface(for: colorScheme)))
    }

    private var practiceBar: some View {
        Button(action: openPractice) {
            Label(tr("תרגול", "Practice"), systemImage: "figure.martial.arts")
                .kmiTypography(.action).fontWeight(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .foregroundStyle(practiceContentColor)
                .background(RoundedRectangle(cornerRadius: 16).fill(KmiBeltPalette.color(for: belt)))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isExporting || practiceItems.isEmpty)
        .opacity(practiceItems.isEmpty ? 0.55 : 1)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(KmiAppTheme.surface(for: colorScheme).ignoresSafeArea(edges: .bottom))
    }

    private func exerciseCard(_ item: ExerciseItem) -> some View {
        let value = state(item)
        return VStack(alignment: .leading, spacing: 10) {
            Button { selectedInfo = item } label: {
                Text(title(item))
                    .kmiTypography(.cardTitle).fontWeight(.bold)
                    .foregroundStyle(primary).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                if !value.note.isEmpty || value.noteConflict {
                    metaBadge(tr("הערה", "Note"), icon: "note.text", tint: KmiAppTheme.warning(for: colorScheme))
                }
                if favorites.contains(item.raw) {
                    metaBadge(tr("מועדף", "Favorite"), icon: "star.fill", tint: KmiAppTheme.warning(for: colorScheme))
                }
                if value.excluded {
                    metaBadge(tr("מוחרג", "Excluded"), icon: "minus.circle", tint: secondary)
                }
            }

            if isCoach {
                HStack(alignment: .top, spacing: 4) {
                    ForEach([CoachStatus.taught, .practiced, .needsReinforcement], id: \.rawValue) { status in
                        statusCell(
                            coachLabel(status), color: coachColor(status),
                            selected: value.coach.contains(status),
                            timestamp: value.coachDates[status] ?? 0
                        ) { updateCoach(status, item: item) }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 4) {
                    statusCell(tr("יודע", "Known"), color: KmiAppTheme.success(for: colorScheme),
                               selected: value.mark == .mastered, timestamp: value.mark == .mastered ? value.markDate : 0) {
                        updateMark(value.mark == .mastered ? nil : .mastered, item: item)
                    }
                    statusCell(tr("חלקית", "Partial"), color: KmiAppTheme.warning(for: colorScheme),
                               selected: value.mark == .partiallyKnown, timestamp: value.mark == .partiallyKnown ? value.markDate : 0) {
                        updateMark(value.mark == .partiallyKnown ? nil : .partiallyKnown, item: item)
                    }
                    statusCell(tr("לא יודע", "Unknown"), color: KmiAppTheme.error(for: colorScheme),
                               selected: value.mark == .unknown, timestamp: value.mark == .unknown ? value.markDate : 0) {
                        updateMark(value.mark == .unknown ? nil : .unknown, item: item)
                    }
                }
            }

            HStack(spacing: 6) {
                iconAction("info.circle", label: tr("מידע", "Information"), tint: accent) { selectedInfo = item }
                iconAction(favorites.contains(item.raw) ? "star.fill" : "star", label: favorites.contains(item.raw)
                           ? tr("הסר ממועדפים", "Remove from favorites") : tr("הוסף למועדפים", "Add to favorites"),
                           tint: favorites.contains(item.raw) ? KmiAppTheme.warning(for: colorScheme) : secondary) {
                    toggleFavorite(item)
                }
                iconAction("note.text", label: tr("עריכת הערה", "Edit note"), tint: secondary) { openNote(item) }
                iconAction(value.excluded ? "plus.circle" : "minus.circle", label: value.excluded
                           ? tr("בטל החרגה", "Include in practice") : tr("החרג מתרגול", "Exclude from practice"), tint: secondary) {
                    toggleExclusion(item)
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KmiAppTheme.surface(for: colorScheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.clear, KmiAppTheme.surfaceVariant(for: colorScheme).opacity(0.26), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
        }
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme).opacity(0.45), lineWidth: 1))
    }

    private func metaBadge(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .kmiTypography(.caption).fontWeight(.bold).foregroundStyle(tint)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.10)))
    }

    private func statusCell(_ text: String, color: Color, selected: Bool, timestamp: Double,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(text).kmiTypography(.caption).fontWeight(.bold)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if selected && timestamp > 0 {
                    Text(dateText(timestamp)).kmiTypography(.caption).monospacedDigit()
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .foregroundStyle(selected ? color : secondary)
            .padding(.horizontal, 4).padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 9).fill(selected ? color.opacity(0.13) : KmiAppTheme.surfaceVariant(for: colorScheme)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? color.opacity(0.5) : KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func iconAction(_ icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).kmiIconSize(18).fontWeight(.semibold)
                .foregroundStyle(tint).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func coachLabel(_ status: CoachStatus) -> String {
        switch status {
        case .notTaught: return tr("לא נלמד", "Not taught")
        case .taught: return tr("נלמד", "Taught")
        case .practiced: return tr("תורגל", "Practiced")
        case .needsReinforcement: return tr("חיזוק", "Reinforcement")
        }
    }
    private func coachColor(_ status: CoachStatus) -> Color {
        switch status {
        case .notTaught: return secondary
        case .taught: return KmiAppTheme.warning(for: colorScheme)
        case .practiced: return KmiAppTheme.success(for: colorScheme)
        case .needsReinforcement: return KmiAppTheme.secondary(for: colorScheme)
        }
    }
    private func dateText(_ timestamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: isEnglish ? "en_GB" : "he_IL")
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    // MARK: - ContentRepo catalog and exact MaterialsView storage identities

    private func loadCatalog() async {
        if loadedScopeID == scopeID {
            refreshStates()
            isLoading = false
            return
        }
        let request = UUID()
        loadRequestID = request
        isLoading = true
        selectedInfo = nil
        noteContext = nil
        selectedFilter = .all
        await Task.yield()
        guard !Task.isCancelled, request == loadRequestID else { return }
        let built = buildCatalog()
        guard !Task.isCancelled, request == loadRequestID else { return }
        items = built
        importLegacyFavorites(built)
        refreshStates()
        loadedScopeID = scopeID
        isLoading = false
    }

    private func buildCatalog() -> [ExerciseItem] {
        let requested = decodeTitle(topicTitle)
        var requestedSub = subTopicTitle.map(decodeTitle).flatMap { $0.isEmpty ? nil : $0 }
        var roots = requested == "__ALL__"
            ? TopicsEngine.shared.topicTitlesFor(belt: belt)
            : [requested]
        if requested != "__ALL__", requestedSub == nil {
            let allRoots = TopicsEngine.shared.topicTitlesFor(belt: belt)
            if !allRoots.contains(where: { clean($0) == requested }) {
                findParent: for parentRoot in allRoots {
                    for sub in ContentRepo.shared.getSubTopicsFor(belt: belt, topicTitle: parentRoot) {
                        if clean(sub.title) == requested {
                            roots = [parentRoot]
                            requestedSub = requested
                            break findParent
                        }
                        let nested = ContentRepo.shared.getNestedSubTopicTitles(belt: belt, topicTitle: parentRoot, subTopicTitle: sub.title)
                        if nested.contains(where: { clean($0) == requested }) {
                            roots = [parentRoot]
                            requestedSub = requested
                            break findParent
                        }
                    }
                }
            }
        }
        var result: [ExerciseItem] = []
        var resultIndex: [String: Int] = [:]

        for rawRoot in roots {
            let root = clean(rawRoot)
            guard !root.isEmpty else { continue }
            // Each list is registered before de-duplication across scopes.
            var lists: [(key: String, sub: String?, items: [String])] = []
            let direct = unique(ContentRepo.shared.getAllItemsFor(belt: belt, topicTitle: root, subTopicTitle: nil))
            lists.append((root, nil, direct))
            for sub in ContentRepo.shared.getSubTopicsFor(belt: belt, topicTitle: root) {
                let parent = clean(sub.title)
                guard !parent.isEmpty else { continue }
                let parentItems = unique(ContentRepo.shared.getAllItemsFor(belt: belt, topicTitle: root, subTopicTitle: parent))
                lists.append(("\(root)__\(parent)", parent, parentItems))
                var combined: [String] = []
                for rawNested in ContentRepo.shared.getNestedSubTopicTitles(belt: belt, topicTitle: root, subTopicTitle: parent) {
                    let nested = clean(rawNested)
                    let nestedItems = unique(ContentRepo.shared.getNestedItemsFor(belt: belt, topicTitle: root, subTopicTitle: parent, nestedSubTopicTitle: nested))
                    lists.append(("\(root)__\(parent)__\(nested)", nested, nestedItems))
                    combined.append(contentsOf: nestedItems)
                }
                if !combined.isEmpty { lists.append(("\(root)__\(parent)", parent, unique(combined))) }
            }

            var locationsByRaw: [String: [Location]] = [:]
            for list in lists {
                for (index, raw) in list.items.enumerated() {
                    let normalized = clean(raw)
                    let location = Location(
                        topicKey: list.key,
                        statusID: "status_\(belt.id)_\(list.key)_\(index)_\(normalized)",
                        canonicalID: "\(belt.id)||\(root)||\(list.sub ?? "")||\(raw.trimmingCharacters(in: .whitespacesAndNewlines))"
                    )
                    if !(locationsByRaw[normalized] ?? []).contains(location) {
                        locationsByRaw[normalized, default: []].append(location)
                    }
                }
            }

            let selectedLists = lists.filter { list in
                requestedSub == nil || list.sub == requestedSub || list.key.hasPrefix("\(root)__\(requestedSub ?? "")__")
            }
            var seenInRoot = Set<String>()
            for list in selectedLists {
                for raw in list.items {
                    let normalized = clean(raw)
                    guard seenInRoot.insert(normalized).inserted,
                          let identity = ExerciseIdentityResolverIOS.resolve(belt: belt, topic: root, rawItem: raw),
                          let locations = locationsByRaw[normalized], !locations.isEmpty
                    else { continue }
                    let writeLocation = locations.first { $0.topicKey == list.key } ?? locations[0]
                    let dedupKey = requested == "__ALL__" ? normalized : "\(root)||\(normalized)"
                    if let previousIndex = resultIndex[dedupKey] {
                        let previous = result[previousIndex]
                        result[previousIndex] = ExerciseItem(
                            id: previous.id, raw: previous.raw, topic: previous.topic,
                            subtopic: previous.subtopic, identity: previous.identity,
                            locations: Array(Set(previous.locations + locations)).sorted { $0.statusID < $1.statusID },
                            writeLocation: previous.writeLocation,
                            sourceTopics: unique(previous.sourceTopics + [root])
                        )
                    } else {
                        resultIndex[dedupKey] = result.count
                        result.append(ExerciseItem(
                            id: "\(belt.id)||\(root)||\(identity.primaryID)", raw: raw, topic: root,
                            subtopic: list.sub, identity: identity, locations: locations,
                            writeLocation: writeLocation, sourceTopics: [root]
                        ))
                    }
                }
            }
        }
        return result
    }

    private func parseMark(_ raw: String) -> Mark? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mastered", "known", "know", "done": return .mastered
        case "partiallyknown", "partially_known", "partial": return .partiallyKnown
        case "unknown", "dontknow", "notdone", "not_done": return .unknown
        default: return nil
        }
    }
    private func timestamp(_ value: Double, milliseconds: Bool) -> Double {
        guard value.isFinite, value > 0 else { return 0 }
        return milliseconds ? value / 1_000 : value
    }
    private func coachKey(_ location: Location) -> String {
        "coach_material_progress_\(belt.id)_\(location.topicKey)_\(location.statusID)"
    }
    private func traineeDateKey(_ location: Location) -> String {
        "trainee_material_updated_at_\(belt.id)_\(location.topicKey)_\(location.statusID)"
    }
    private func practiceID(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: " ", with: "_").lowercased()
    }

    private func subjectMarkKeys(_ item: ExerciseItem, topic: String) -> [String] {
        unique([
            item.raw.trimmingCharacters(in: .whitespacesAndNewlines),
            item.identity.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            ExerciseTitleFormatter.shared.displayName(raw: item.raw)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        ]).map { "kmi.subject.mark.\(belt.id).\(topic.trimmingCharacters(in: .whitespacesAndNewlines)).\($0)" }
    }

    private var subjectCoachMappings: [(material: CoachStatus, subject: KmiCoachExerciseStatus)] {
        [(.taught, .taught), (.practiced, .practiced), (.needsReinforcement, .needsReinforcement)]
    }

    private func refreshStates() {
        let defaults = UserDefaults.standard
        var updated: [String: RowState] = [:]
        for item in items {
            var value = RowState()
            var markFound = false
            var newestCoach: Double = -1
            for location in item.locations {
                if let raw = defaults.string(forKey: "mark.\(location.statusID)") {
                    let date = timestamp(defaults.double(forKey: traineeDateKey(location)), milliseconds: true)
                    if !markFound || date > value.markDate {
                        markFound = true
                        value.mark = parseMark(raw)
                        value.markDate = date
                    }
                }
                let base = coachKey(location)
                let statuses: [CoachStatus] = [.taught, .practiced, .needsReinforcement]
                let hasFields = statuses.contains { defaults.object(forKey: "\(base)_\($0.rawValue)_selected") != nil }
                let legacy = defaults.string(forKey: "\(base)_status")
                var selected = Set<CoachStatus>()
                var dates: [CoachStatus: Double] = [:]
                var newest = timestamp(defaults.double(forKey: "\(base)_updated_at"), milliseconds: true)
                if hasFields {
                    for status in statuses where defaults.bool(forKey: "\(base)_\(status.rawValue)_selected") {
                        selected.insert(status)
                        let date = timestamp(defaults.double(forKey: "\(base)_\(status.rawValue)_updated_at"), milliseconds: true)
                        if date > 0 { dates[status] = date }
                        newest = max(newest, date)
                    }
                } else if let legacy, let status = CoachStatus(rawValue: legacy), status != .notTaught {
                    selected.insert(status)
                    if newest > 0 { dates[status] = newest }
                }
                if (hasFields || legacy != nil) && newest > newestCoach {
                    newestCoach = newest
                    value.coach = Set(statuses.filter { selected.contains($0) }.prefix(2))
                    value.coachDates = dates
                }
                if defaults.bool(forKey: "excluded.\(location.canonicalID)") { value.excluded = true }
            }
            for topic in item.sourceTopics {
                for subjectKey in subjectMarkKeys(item, topic: topic) {
                if let raw = defaults.string(forKey: subjectKey) {
                    let date = timestamp(defaults.double(forKey: "\(subjectKey).updatedAt"), milliseconds: false)
                    if !markFound || date > value.markDate {
                        markFound = true
                        value.mark = parseMark(raw)
                        value.markDate = date
                    }
                }
                let coachBase = "kmi.subject.coach.\(subjectKey)"
                if let saved = defaults.stringArray(forKey: "\(coachBase).selected") {
                    let mappings = subjectCoachMappings.filter { saved.contains($0.subject.rawValue) }
                    var dates: [CoachStatus: Double] = [:]
                    var newest: Double = 0
                    for mapping in mappings {
                        let date = timestamp(defaults.double(forKey: "\(coachBase).\(mapping.subject.rawValue).updatedAt"), milliseconds: false)
                        if date > 0 { dates[mapping.material] = date }
                        newest = max(newest, date)
                    }
                    if newest > newestCoach {
                        newestCoach = newest
                        value.coach = Set(mappings.prefix(2).map(\.material))
                        value.coachDates = dates
                    }
                }
                }
                let practiceKey = "random_practice_status_\(belt.id)_\(practiceID(topic))_\(practiceID(item.raw))"
                let practiceDate = timestamp(defaults.double(forKey: "\(practiceKey).updatedAt"), milliseconds: false)
                if let raw = defaults.string(forKey: practiceKey) {
                    if !markFound || practiceDate > value.markDate {
                        markFound = true
                        value.mark = parseMark(raw)
                        value.markDate = practiceDate
                    }
                } else if practiceDate > 0, !markFound || practiceDate > value.markDate {
                    markFound = true
                    value.mark = nil
                    value.markDate = practiceDate
                }
            }
            let subjectExcluded = Set(defaults.stringArray(forKey: "kmi.subject.excluded.\(belt.id)") ?? [])
            let exclusionAliases = Set(item.sourceTopics.flatMap { subjectMarkKeys(item, topic: $0) })
                .union(item.identity.previousIDs).union([item.identity.primaryID])
            if !subjectExcluded.isDisjoint(with: exclusionAliases) {
                value.excluded = true
            }
            if !currentUserID.isEmpty {
                switch notes.loadCompatible(userID: currentUserID, beltID: belt.id, identity: noteIdentity(item)) {
                case .found(let text): value.note = text
                case .missing: break
                case .conflict: value.noteConflict = true
                }
            }
            updated[item.id] = value
        }
        if updated != states { states = updated }
    }

    private func importLegacyFavorites(_ built: [ExerciseItem]) {
        let defaults = UserDefaults.standard
        for item in built where item.locations.contains(where: { defaults.bool(forKey: "favorite.\($0.canonicalID)") }) {
            favorites.importLegacyFavorite(item.raw)
        }
    }

    private func updateMark(_ mark: Mark?, item: ExerciseItem) {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        for location in item.locations {
            defaults.set(mark?.rawValue ?? "unmarked", forKey: "mark.\(location.statusID)")
            defaults.set(now * 1_000, forKey: traineeDateKey(location))
        }
        for topic in item.sourceTopics {
            let subjectRaw: String
            let practiceRaw: String
            switch mark {
            case .mastered: subjectRaw = "know"; practiceRaw = "known"
            case .partiallyKnown: subjectRaw = "partiallyKnown"; practiceRaw = "partial"
            case .unknown: subjectRaw = "dontKnow"; practiceRaw = "unknown"
            case nil: subjectRaw = "unmarked"; practiceRaw = "unmarked"
            }
            for subjectKey in subjectMarkKeys(item, topic: topic) {
                defaults.set(subjectRaw, forKey: subjectKey)
                defaults.set(now, forKey: "\(subjectKey).updatedAt")
            }
            let practiceTopic = practiceID(topic)
            let practiceKey = "random_practice_status_\(belt.id)_\(practiceTopic)_\(practiceID(item.raw))"
            if mark == nil { defaults.removeObject(forKey: practiceKey) }
            else { defaults.set(practiceRaw, forKey: practiceKey) }
            defaults.set(now, forKey: "\(practiceKey).updatedAt")
            let wrongKey = "random_practice_wrong_\(belt.id)_\(practiceTopic)"
            var wrong = Set(defaults.stringArray(forKey: wrongKey) ?? [])
            if mark == .partiallyKnown || mark == .unknown { wrong.insert(item.raw) }
            else { wrong.remove(item.raw) }
            defaults.set(wrong.sorted(), forKey: wrongKey)
        }
        refreshStates()
    }

    private func updateCoach(_ status: CoachStatus, item: ExerciseItem) {
        var value = state(item)
        if value.coach.contains(status) {
            value.coach.remove(status)
            value.coachDates.removeValue(forKey: status)
        } else {
            guard value.coach.count < 2 else {
                notify(tr("ניתן לבחור עד שני סטטוסים.", "You can select up to two statuses."))
                return
            }
            value.coach.insert(status)
            value.coachDates[status] = Date().timeIntervalSince1970
        }
        let defaults = UserDefaults.standard
        for location in item.locations {
            let key = coachKey(location)
            for candidate in [CoachStatus.taught, .practiced, .needsReinforcement] {
                if value.coach.contains(candidate) {
                    defaults.set(true, forKey: "\(key)_\(candidate.rawValue)_selected")
                    defaults.set((value.coachDates[candidate] ?? 0) * 1_000, forKey: "\(key)_\(candidate.rawValue)_updated_at")
                } else {
                    defaults.removeObject(forKey: "\(key)_\(candidate.rawValue)_selected")
                    defaults.removeObject(forKey: "\(key)_\(candidate.rawValue)_updated_at")
                }
            }
            defaults.removeObject(forKey: "\(key)_status")
            defaults.removeObject(forKey: "\(key)_updated_at")
        }
        for topic in item.sourceTopics {
            for markKey in subjectMarkKeys(item, topic: topic) {
                let base = "kmi.subject.coach.\(markKey)"
                let selected = subjectCoachMappings.filter { value.coach.contains($0.material) }
                defaults.set(selected.map { $0.subject.rawValue }.sorted(), forKey: "\(base).selected")
                for mapping in subjectCoachMappings {
                    let dateKey = "\(base).\(mapping.subject.rawValue).updatedAt"
                    if let date = value.coachDates[mapping.material], value.coach.contains(mapping.material) {
                        defaults.set(date, forKey: dateKey)
                    } else { defaults.removeObject(forKey: dateKey) }
                }
            }
        }
        refreshStates()
    }

    private func toggleFavorite(_ item: ExerciseItem) {
        favorites.toggle(item.raw)
        // Keep legacy readers consistent without making them the source of truth.
        for location in item.locations {
            UserDefaults.standard.set(favorites.contains(item.raw), forKey: "favorite.\(location.canonicalID)")
        }
    }

    private func toggleExclusion(_ item: ExerciseItem) {
        let excluded = !state(item).excluded
        let defaults = UserDefaults.standard
        for location in item.locations {
            defaults.set(excluded, forKey: "excluded.\(location.canonicalID)")
        }
        let key = "kmi.subject.excluded.\(belt.id)"
        var ids = Set(defaults.stringArray(forKey: key) ?? [])
        let subjectKeys = Set(item.sourceTopics.flatMap { subjectMarkKeys(item, topic: $0) })
        let aliases = item.identity.previousIDs.union([item.identity.primaryID]).union(subjectKeys)
        if excluded { ids.formUnion(subjectKeys) }
        else { ids.subtract(aliases) }
        defaults.set(ids.sorted(), forKey: key)
        refreshStates()
    }

    // MARK: - Global notes, authenticated owner and conflict protection

    private func noteIdentity(_ item: ExerciseItem) -> ExerciseIdentityResolverIOS.Identity {
        var previous = item.identity.previousIDs
        previous.formUnion(item.locations.map { "materials-local:\($0.canonicalID)" })
        previous.formUnion(item.sourceTopics.flatMap { subjectMarkKeys(item, topic: $0).map { "subject-local:\($0)" } })
        if let known = notes.knownExerciseID(belt: belt, title: item.raw, topicKey: item.topic), known != item.identity.primaryID {
            previous.insert(known)
        }
        return .init(primaryID: item.identity.primaryID, displayTitle: item.identity.displayTitle, previousIDs: previous)
    }

    private func authenticatedUserID() -> String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? ""
        #else
        return ""
        #endif
    }

    private func startAuthListener() {
        currentUserID = authenticatedUserID()
        #if canImport(FirebaseAuth)
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            let userID = user?.uid ?? ""
            Task { @MainActor in
                guard isVisible, authenticatedUserID() == userID else { return }
                if currentUserID != userID {
                    currentUserID = userID
                    noteContext = nil
                    noteDraft = ""
                    selectedInfo = nil
                    exportRequestID = UUID()
                    isExporting = false
                }
                refreshStates()
            }
        }
        #endif
        refreshStates()
    }

    private func stopAuthListener() {
        #if canImport(FirebaseAuth)
        if let authListener { Auth.auth().removeStateDidChangeListener(authListener) }
        authListener = nil
        #endif
    }

    private func openNote(_ item: ExerciseItem) {
        let userID = authenticatedUserID()
        guard !userID.isEmpty else {
            notify(tr("יש להתחבר כדי לערוך הערה.", "Sign in to edit a note."))
            return
        }
        let original: String
        switch notes.loadCompatible(userID: userID, beltID: belt.id, identity: noteIdentity(item)) {
        case .found(let text): original = text
        case .missing: original = ""
        case .conflict:
            notify(tr("נמצאו הערות שונות לתרגיל. יש לפתור את הסתירה במסך התרגילים לפני עריכה.", "Different notes were found. Resolve the conflict in Materials before editing."))
            return
        }
        noteDraft = original
        noteSaveFailed = false
        noteContext = NoteContext(id: item.id, item: item, userID: userID, beltID: belt.id, original: original)
    }

    private func saveNote(_ context: NoteContext) {
        guard authenticatedUserID() == context.userID, belt.id == context.beltID,
              items.contains(where: { $0.id == context.item.id }) else {
            noteSaveFailed = true
            return
        }
        let current: String
        switch notes.loadCompatible(userID: context.userID, beltID: context.beltID, identity: noteIdentity(context.item)) {
        case .found(let text): current = text
        case .missing: current = ""
        case .conflict: noteSaveFailed = true; return
        }
        guard current == context.original else { noteSaveFailed = true; return }
        notes.save(noteDraft, userID: context.userID, beltID: context.beltID, exerciseID: context.item.identity.primaryID)
        noteSaveFailed = false
        refreshStates()
    }

    private func notify(_ text: String) { message = text; showMessage = true }

    // MARK: - Exact filtered practice selection

    private func openPractice() {
        let selected = practiceItems
        guard !selected.isEmpty else { return }
        var sources: [String: [String]] = [:]
        for item in selected { sources[item.raw] = item.sourceTopics }
        let selection = ExerciseCardsPracticeSelection(
            topic: decodeTitle(topicTitle), items: selected.map(\.raw), sourceTopicsByItem: sources
        )
        do { onPractice(belt, try selection.encodedToken()) }
        catch { notify(tr("לא ניתן לפתוח תרגול כרגע.", "Practice could not be opened.")) }
    }

    // MARK: - PDF for the current tab; global header, footer and share sheet

    private struct PDFRow {
        let title: String
        let topic: String
        let status: String
        let favorite: Bool
        let excluded: Bool
        let mark: Mark?
        let coach: Set<CoachStatus>
    }

    private func exportPDF() {
        let rows = filteredItems.map { item -> PDFRow in
            let value = state(item)
            let status: String
            if isCoach {
                let labels = [CoachStatus.taught, .practiced, .needsReinforcement]
                    .filter { value.coach.contains($0) }.map(coachLabel)
                status = labels.isEmpty ? coachLabel(.notTaught) : labels.joined(separator: " · ")
            } else {
                switch value.mark {
                case .mastered: status = tr("יודע", "Known")
                case .partiallyKnown: status = tr("חלקית", "Partially known")
                case .unknown: status = tr("לא יודע", "Unknown")
                case nil: status = tr("לא סומן", "Unmarked")
                }
            }
            return PDFRow(title: title(item), topic: KmiEnglishTitleResolver.title(for: item.topic, isEnglish: isEnglish),
                          status: status, favorite: favorites.contains(item.raw), excluded: value.excluded,
                          mark: value.mark, coach: value.coach)
        }
        guard !rows.isEmpty else {
            notify(tr("אין תרגילים ליצירת PDF בכרטיסייה הנוכחית.", "There are no exercises to export in this tab."))
            return
        }
        let english = isEnglish
        let tab = label(selectedFilter)
        let request = UUID()
        let scope = scopeID
        let userID = authenticatedUserID()
        let coach = isCoach
        exportRequestID = request
        isExporting = true
        Task { @MainActor in
            await Task.yield()
            guard request == exportRequestID, isVisible, scope == scopeID,
                  userID == authenticatedUserID(), coach == isCoach else {
                if request == exportRequestID { isExporting = false }
                return
            }
            defer { if request == exportRequestID { isExporting = false } }
            do {
                let data = try makePDF(rows: rows, tab: tab, english: english)
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("KmiExerciseCards", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(english ? "Exercise_Cards.pdf" : "כרטיסיות_תרגילים.pdf")
                try data.write(to: url, options: .atomic)
                shareItems = [url]
                showShare = true
            } catch {
                notify(tr("יצירת קובץ ה־PDF נכשלה. נסה שוב.", "The PDF could not be created. Please try again."))
            }
        }
    }

    private func makePDF(rows: [PDFRow], tab: String, english: Bool) throws -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 34
        let width = page.width - margin * 2
        let top = KmiPdfHeader.CONTENT_TOP
        let bottom = page.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING
        let foreground = UIColor(KmiAppTheme.onSurface(for: .light))
        let muted = UIColor(KmiAppTheme.onSurfaceVariant(for: .light))
        let background = UIColor(KmiAppTheme.surfaceVariant(for: .light))
        let outline = UIColor(KmiAppTheme.outlineVariant(for: .light))
        let numberFill = UIColor(KmiAppTheme.secondary(for: .light))
        let numberContent = UIColor(KmiAppTheme.onSecondary(for: .light))
        func local(_ he: String, _ en: String) -> String { english ? en : he }
        func attributes(size: CGFloat, bold: Bool, color: UIColor, centered: Bool = false) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = centered ? .center : (english ? .left : .right)
            paragraph.baseWritingDirection = english ? .leftToRight : .rightToLeft
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 3
            return [.font: UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular),
                    .foregroundColor: color, .paragraphStyle: paragraph]
        }
        func height(_ text: String, width: CGFloat, size: CGFloat, bold: Bool) -> CGFloat {
            ceil((text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes(size: size, bold: bold, color: foreground), context: nil).height)
        }
        func draw(_ text: String, rect: CGRect, size: CGFloat, bold: Bool, color: UIColor, centered: Bool = false) {
            (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes(size: size, bold: bold, color: color, centered: centered), context: nil)
        }
        func statusColor(_ row: PDFRow) -> UIColor {
            if isCoach {
                if row.coach.contains(.needsReinforcement) { return numberFill }
                if row.coach.contains(.practiced) { return UIColor(KmiAppTheme.success(for: .light)) }
                if row.coach.contains(.taught) { return UIColor(KmiAppTheme.warning(for: .light)) }
                return muted
            }
            switch row.mark {
            case .mastered: return UIColor(KmiAppTheme.success(for: .light))
            case .partiallyKnown: return UIColor(KmiAppTheme.warning(for: .light))
            case .unknown: return UIColor(KmiAppTheme.error(for: .light))
            case nil: return muted
            }
        }
        guard !rows.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        var summaryLines = [local("\(tab) · \(rows.count) תרגילים", "\(tab) · \(rows.count) exercises")]
        if isCoach {
            let taught = rows.filter { $0.coach.contains(.taught) }.count
            let practiced = rows.filter { $0.coach.contains(.practiced) }.count
            let reinforcement = rows.filter { $0.coach.contains(.needsReinforcement) }.count
            let unmarked = rows.filter { $0.coach.isEmpty }.count
            summaryLines.append(local("נלמד: \(taught) · תורגל: \(practiced)", "Taught: \(taught) · Practiced: \(practiced)"))
            summaryLines.append(local("חיזוק: \(reinforcement) · לא נלמד: \(unmarked)", "Reinforcement: \(reinforcement) · Not taught: \(unmarked)"))
        } else {
            let known = rows.filter { $0.mark == .mastered }.count
            let partial = rows.filter { $0.mark == .partiallyKnown }.count
            let unknown = rows.filter { $0.mark == .unknown }.count
            let unmarked = rows.filter { $0.mark == nil }.count
            summaryLines.append(local("יודע: \(known) · חלקית: \(partial)", "Known: \(known) · Partial: \(partial)"))
            summaryLines.append(local("לא יודע: \(unknown) · לא סומן: \(unmarked)", "Unknown: \(unknown) · Unmarked: \(unmarked)"))
        }
        let favoriteCount = rows.filter(\.favorite).count
        let excludedCount = rows.filter(\.excluded).count
        summaryLines.append(local("מועדפים: \(favoriteCount) · מוחרגים: \(excludedCount)", "Favorites: \(favoriteCount) · Excluded: \(excludedCount)"))
        let summaryText = summaryLines.joined(separator: "\n")
        let summaryHeight = height(summaryText, width: width - 24, size: 11, bold: true) + 24
        let firstTop = top + summaryHeight + 12
        guard firstTop < bottom else { throw CocoaError(.fileWriteUnknown) }

        let titleWidth = width - 150
        let statusWidth: CGFloat = 82
        var rendered: [(detail: String, titleHeight: CGFloat, detailHeight: CGFloat, statusHeight: CGFloat, height: CGFloat)] = []
        for row in rows {
            var metadata = [row.topic, row.favorite ? local("מועדף", "Favorite") : local("לא מועדף", "Not favorite")]
            if row.excluded { metadata.append(local("מוחרג", "Excluded")) }
            let detail = metadata.joined(separator: " · ")
            let titleHeight = height(row.title, width: titleWidth, size: 11.5, bold: true)
            let detailHeight = height(detail, width: titleWidth, size: 9, bold: false)
            let statusHeight = height(row.status, width: statusWidth, size: 9, bold: true)
            let cardHeight = max(64, max(titleHeight + detailHeight + 25, statusHeight + 39))
            guard cardHeight <= bottom - top else { throw CocoaError(.fileWriteUnknown) }
            rendered.append((detail, titleHeight, detailHeight, statusHeight, cardHeight))
        }
        var pages: [[Int]] = [[]]
        var used: CGFloat = 0
        for index in rendered.indices {
            let needed = rendered[index].height + 8
            let capacity = bottom - (pages.count == 1 ? firstTop : top)
            if used + needed > capacity {
                pages.append([])
                used = 0
            }
            guard used + rendered[index].height <= bottom - (pages.count == 1 ? firstTop : top) else {
                throw CocoaError(.fileWriteUnknown)
            }
            pages[pages.count - 1].append(index)
            used += needed
        }
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        let generated = formatter.string(from: Date())
        return renderer.pdfData { context in
            func card(_ rect: CGRect) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
                background.setFill()
                path.fill()
                outline.setStroke()
                path.lineWidth = 0.7
                path.stroke()
            }
            for (pageIndex, indices) in pages.enumerated() {
                context.beginPage()
                KmiPdfHeader.draw(context: context.cgContext, pageWidth: page.width, isEnglish: english,
                    titleHebrew: "כרטיסיות תרגילים", titleEnglish: "Exercise Cards",
                    subtitleHebrew: "\(belt.heb) · \(tab)",
                    subtitleEnglish: "\(belt.id.capitalized) Belt · \(tab)", generatedDate: generated)
                var y = top
                if pageIndex == 0 {
                    card(CGRect(x: margin, y: y, width: width, height: summaryHeight))
                    draw(summaryText, rect: CGRect(x: margin + 12, y: y + 12, width: width - 24, height: summaryHeight - 24),
                         size: 11, bold: true, color: foreground)
                    y = firstTop
                }
                for index in indices {
                    let row = rows[index]
                    let layout = rendered[index]
                    card(CGRect(x: margin, y: y, width: width, height: layout.height))
                    let numberX = english ? margin + 22 : page.width - margin - 22
                    let centerY = y + layout.height / 2
                    numberFill.setFill()
                    UIBezierPath(ovalIn: CGRect(x: numberX - 14, y: centerY - 14, width: 28, height: 28)).fill()
                    draw("\(index + 1)", rect: CGRect(x: numberX - 14, y: centerY - 7, width: 28, height: 17),
                         size: 10, bold: true, color: numberContent, centered: true)
                    let titleX = english ? margin + 48 : margin + 102
                    draw(row.title, rect: CGRect(x: titleX, y: y + 10, width: titleWidth, height: layout.titleHeight),
                         size: 11.5, bold: true, color: foreground)
                    draw(layout.detail, rect: CGRect(x: titleX, y: y + layout.height - layout.detailHeight - 10, width: titleWidth, height: layout.detailHeight),
                         size: 9, bold: false, color: muted)
                    let statusX = english ? page.width - margin - 45 : margin + 45
                    let tint = statusColor(row)
                    tint.setFill()
                    UIBezierPath(ovalIn: CGRect(x: statusX - 5, y: y + 12, width: 10, height: 10)).fill()
                    draw(row.status, rect: CGRect(x: statusX - statusWidth / 2, y: y + 29, width: statusWidth, height: layout.statusHeight),
                         size: 9, bold: true, color: tint, centered: true)
                    y += layout.height + 8
                }
                KmiPdfFooter.draw(context: context.cgContext, pageWidth: page.width, pageHeight: page.height,
                    pageNumber: pageIndex + 1, totalPages: pages.count, isEnglish: english)
            }
        }
    }

}
