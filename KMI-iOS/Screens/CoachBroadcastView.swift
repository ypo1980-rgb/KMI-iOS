import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import UIKit

struct CoachBroadcastView: View {

    @EnvironmentObject
    private var auth: AuthViewModel

    @EnvironmentObject
    private var nav: AppNavModel

    @State private var isBroadcastVisible = false
    @State private var hasBroadcastLoadingRequest = false

    @ObservedObject
    private var demoPrivacy = DemoPrivacy.shared

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("theme_mode")
    private var themeMode: String = "system"

    @State private var region: String = ""
    @State private var branch: String = ""
    @State private var message: String = ""

    @State private var recipients: [CoachBroadcastRecipient] = []

    @State private var isLoadingRecipients = false

    @State private var activeRecipientsRequestID = UUID()
    @State private var loadedRecipientsContext: RecipientsContext?

    private struct RecipientsContext: Equatable {
        let uid: String
        let region: String
        let branch: String
        let scope: String
        let groups: [String]
    }

    @State private var isPreloadingDefaults = false

    @State private var isSending = false

    @State private var alertText: String?

    @State private var showAlert = false

    @State private var pdfShareItem:
        CoachBroadcastPdfShareItem?

    @State private var sendScope: String = "groups"

    @State private var availableBranchGroups: [String] = []
    @State private var availableBranchGroupCounts: [String: Int] = [:]
    @State private var selectedTargetGroups: Set<String> = []

    @AppStorage("kmi_app_language") private var kmiAppLanguage: String = ""
    @AppStorage("app_language") private var appLanguage: String = ""
    @AppStorage("initial_language_code") private var initialLanguageCode: String = ""
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = ""

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        .leading
    }

    private var screenFrameAlignment: Alignment {
        .leading
    }

    private var normalizedThemeMode: String {
        themeMode
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    private var preferredScreenColorScheme: ColorScheme? {
        switch normalizedThemeMode {
        case "dark":
            return .dark

        case "light":
            return .light

        default:
            return nil
        }
    }

    private var isDarkMode: Bool {
        switch normalizedThemeMode {
        case "dark":
            return true

        case "light":
            return false

        default:
            return colorScheme == .dark
        }
    }

    private var activeColorScheme: ColorScheme {

        isDarkMode ? .dark : .light

    }

    private var backgroundColors: [Color] {

        KmiAppTheme.screenBackgroundColors(
            for: activeColorScheme
        )

    }

    private var primaryTextColor: Color {

        KmiAppTheme.onBackground(
            for: activeColorScheme
        )

    }

    private var secondaryTextColor: Color {

        KmiAppTheme.onSurfaceVariant(
            for: activeColorScheme
        )

    }

    private var panelColor: Color {

        KmiAppTheme.surface(
            for: activeColorScheme
        )

    }

    private var elevatedColor: Color {

        KmiAppTheme.surfaceVariant(
            for: activeColorScheme
        )

    }

    private var fieldColor: Color {

        KmiAppTheme.surface(
            for: activeColorScheme
        )

    }

    private var borderColor: Color {

        KmiAppTheme.outlineVariant(
            for: activeColorScheme
        )

    }

    private var accentColor: Color {

        KmiAppTheme.primary(
            for: activeColorScheme
        )

    }

    private var accentBorderColor: Color {

        KmiAppTheme.secondary(
            for: activeColorScheme
        )

    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }
                        
    private func normalizeRole(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isCoachRole(_ value: String) -> Bool {
        let role = normalizeRole(value)

        return role == "coach" ||
               role == "trainer" ||
               role == "instructor" ||
               role == "מאמן" ||
               role == "coach_user" ||
               role == "kmi_coach"
    }

    private var effectiveRole: String {
        let defaults = UserDefaults.standard

        let profileRole = normalizeRole(auth.userRole)

        let storedCandidates = [
            defaults.string(forKey: "user_role"),
            defaults.string(forKey: "role"),
            defaults.string(forKey: "userRole"),
            defaults.string(forKey: "profile_role")
        ]
        .compactMap { $0 }
        .map { normalizeRole($0) }
        .filter { !$0.isEmpty }

        // חשוב: אם אחד המקורות אומר מאמן — לא ניתקע על trainee ישן.
        if isCoachRole(profileRole) {
            return profileRole
        }

        if let coachStoredRole = storedCandidates.first(where: { isCoachRole($0) }) {
            return coachStoredRole
        }

        if let firstStoredRole = storedCandidates.first {
            return firstStoredRole
        }

        return profileRole
    }

    private var isCoach: Bool {
        isCoachRole(effectiveRole)
    }

    private var branchesByRegion: [String: [String]] {
        let defaults = UserDefaults.standard

        func clean(_ value: String) -> String {
            value
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .replacingOccurrences(
                    of: "־",
                    with: "-"
                )
                .replacingOccurrences(
                    of: "–",
                    with: "-"
                )
                .replacingOccurrences(
                    of: "—",
                    with: "-"
                )
                .replacingOccurrences(
                    of: "\\s+",
                    with: " ",
                    options: .regularExpression
                )
        }

        func splitValues(_ rawValue: String) -> [String] {
            rawValue
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: " • ", with: ",")
                .replacingOccurrences(of: "|", with: ",")
                .replacingOccurrences(of: "\n", with: ",")
                .split(whereSeparator: { character in
                    character == "," ||
                    character == ";" ||
                    character == "；"
                })
                .map {
                    clean(String($0))
                }
                .filter { !$0.isEmpty }
        }

        func storedValues(
            for keys: [String]
        ) -> [String] {
            var result: [String] = []

            for key in keys {
                if let array = defaults.array(
                    forKey: key
                ) {
                    result += array
                        .map {
                            clean("\($0)")
                        }
                        .filter { !$0.isEmpty }
                }

                if let rawValue = defaults.string(
                    forKey: key
                ) {
                    if let data = rawValue.data(
                        using: .utf8
                    ),
                       let jsonArray =
                        try? JSONSerialization.jsonObject(
                            with: data
                        ) as? [String] {
                        result += jsonArray
                            .map(clean)
                            .filter { !$0.isEmpty }
                    } else {
                        result += splitValues(
                            rawValue
                        )
                    }
                }
            }

            return result
        }

        func uniqueValues(
            _ values: [String]
        ) -> [String] {
            var seen = Set<String>()
            var result: [String] = []

            for value in values {
                let cleaned = clean(value)

                guard !cleaned.isEmpty else {
                    continue
                }

                let comparisonKey =
                    cleaned.lowercased()

                guard !seen.contains(
                    comparisonKey
                ) else {
                    continue
                }

                seen.insert(comparisonKey)
                result.append(cleaned)
            }

            return result
        }

        let regions = uniqueValues(
            [
                auth.userRegion,
                defaults.string(
                    forKey: "kmi.user.region"
                ) ?? "",
                defaults.string(
                    forKey: "region"
                ) ?? "",
                defaults.string(
                    forKey: "active_region"
                ) ?? "",
                defaults.string(
                    forKey: "activeRegion"
                ) ?? "",
                defaults.string(
                    forKey: "userRegion"
                ) ?? ""
            ]
        )

        let authBranches =
            splitValues(auth.userBranch)

        let storedBranches =
            storedValues(
                for: [
                    "branches",
                    "branches_json",
                    "selected_branches",
                    "branchesCsv",
                    "active_branch",
                    "activeBranch",
                    "branch",
                    "kmi.user.branch",
                    "branch2",
                    "branch3",
                    "coach_branch",
                    "selected_branch",
                    "current_branch"
                ]
            )

        let allBranches =
            uniqueValues(
                authBranches +
                storedBranches
            )

        guard let primaryRegion =
            regions.first else {
            return [:]
        }

        var result: [String: [String]] = [
            primaryRegion: allBranches
        ]

        /*
         * אם נשמרה מפת אזורים וסניפים כ־JSON,
         * ממזגים גם אותה בלי לאבד את הסניפים
         * שכבר נמצאו בפרופיל המשתמש.
         */
        let mappingKeys = [
            "branchesByRegion",
            "branches_by_region",
            "regions_branches_json"
        ]

        for key in mappingKeys {
            guard
                let rawValue = defaults.string(
                    forKey: key
                ),
                let data = rawValue.data(
                    using: .utf8
                ),
                let mapping =
                    try? JSONSerialization.jsonObject(
                        with: data
                    ) as? [String: [String]]
            else {
                continue
            }

            for (storedRegion, branches) in mapping {
                let cleanRegion =
                    clean(storedRegion)

                guard !cleanRegion.isEmpty else {
                    continue
                }

                result[cleanRegion] =
                    uniqueValues(
                        (result[cleanRegion] ?? []) +
                        branches
                    )
            }
        }

        return result
    }

    private var regionOptions: [String] {
        Array(branchesByRegion.keys)
            .sorted {
                $0.localizedCaseInsensitiveCompare(
                    $1
                ) == .orderedAscending
            }
    }

    private var branchOptions: [String] {
        let exactBranches =
            branchesByRegion[region] ?? []

        return exactBranches.sorted {
            $0.localizedCaseInsensitiveCompare(
                $1
            ) == .orderedAscending
        }
    }

    private var displayedRecipients: [CoachBroadcastRecipient] {

        recipients
            .enumerated()
            .map { index, recipient in

                CoachBroadcastRecipient(
                    id: recipient.id,
                    uid: recipient.uid,
                    name:
                        TraineeDisplayNameMapper.displayName(
                            realName: recipient.name,
                            stableKey:
                                recipient.uid.isEmpty
                                    ? recipient.id
                                    : recipient.uid,
                            demoIndex: index,
                            isEnglish: isEnglish
                        ),
                    phone: demoPrivacy.isEnabled ? "" : recipient.phone,
                    email: demoPrivacy.isEnabled ? "" : recipient.email,
                    selected: recipient.selected
                )

            }

    }

    private var selectedRecipients: [CoachBroadcastRecipient] {

        recipients.filter { $0.selected }

    }

    private var selectedPhones: [String] {

        var seenPhones = Set<String>()

        return selectedRecipients
            .map(\.phone)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .filter { phone in

                let comparisonKey =
                    phone.filter(\.isNumber)

                return seenPhones
                    .insert(comparisonKey)
                    .inserted

            }

    }

    private var selectedUids: [String] {

        var seenUids = Set<String>()

        return selectedRecipients
            .map(\.uid)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .filter { uid in

                seenUids
                    .insert(uid)
                    .inserted

            }

    }

    private var allSelected: Bool {
        !recipients.isEmpty && recipients.allSatisfy(\.selected)
    }

    private var coachGroupKey: String {
        let defaults = UserDefaults.standard

        let candidates = [
            defaults.string(forKey: "active_group"),
            defaults.string(forKey: "activeGroup"),
            defaults.string(forKey: "primaryGroup"),
            defaults.string(forKey: "groupKey"),
            defaults.string(forKey: "group_key"),
            defaults.string(forKey: "age_group"),
            defaults.string(forKey: "group"),
            auth.userGroup
        ]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return candidates.first ?? ""
    }

    private var effectiveGroupKeys: [String] {
        if sendScope == "branch" {
            return []
        }

        return selectedTargetGroups
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private var recipientsContext: RecipientsContext {
        RecipientsContext(
            uid: Auth.auth().currentUser?.uid ?? "",
            region: region.trimmingCharacters(in: .whitespacesAndNewlines),
            branch: branch.trimmingCharacters(in: .whitespacesAndNewlines),
            scope: sendScope,
            groups: effectiveGroupKeys
        )
    }

    private var canUseLoadedRecipients: Bool {
        isCoach &&
            !isLoadingRecipients &&
            loadedRecipientsContext == recipientsContext
    }

    private var selectedGroupsSummary: String {
        effectiveGroupKeys.joined(separator: ", ")
    }

    private var sendButtonText: String {
        if selectedUids.isEmpty {
            return tr("בחר מתאמנים לשליחה", "Select trainees to send")
        }

        if allSelected {
            return tr("שליחת הודעה לכל המתאמנים", "Send message to all trainees")
        }

        if selectedRecipients.count == 1 {
            return tr("שליחת הודעה למתאמן שנבחר", "Send message to selected trainee")
        }

        return tr(
            "שליחת הודעה ל-\(selectedRecipients.count) מתאמנים",
            "Send message to \(selectedRecipients.count) trainees"
        )
    }

    private var needsBroadcastLoading: Bool {
        !isPreloadingDefaults && (isLoadingRecipients || isSending)
    }

    private func syncBroadcastLoading() {
        let shouldRequestLoading = isBroadcastVisible && needsBroadcastLoading
        guard shouldRequestLoading != hasBroadcastLoadingRequest else { return }

        hasBroadcastLoadingRequest = shouldRequestLoading

        if shouldRequestLoading {
            nav.beginLoading()
        } else {
            nav.endLoading()
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !isCoach {
                VStack(spacing: 14) {
                    Spacer()

                    Image(
                        systemName:
                            "person.crop.circle.badge.exclamationmark"
                    )
                    .kmiFont(
                        size: 44,
                        weight: .bold
                    )
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                    Text(
                        tr(
                            "המסך זמין למאמנים בלבד",
                            "This screen is available to coaches only"
                        )
                    )
                    .kmiFont(
                        size: 24,
                        weight: .heavy
                    )
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .accessibilityAddTraits(
                        .isHeader
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(24)

            } else {

                VStack(spacing: 0) {

                    sectionHeader

                    ScrollView {

                        VStack(spacing: 12) {

                            inputFormCard
                            audienceCard
                            recipientsCard

                            if !branch.isEmpty,
                               !isLoadingRecipients,
                               !isSending,
                               !canUseLoadedRecipients {
                                Button {
                                    loadRecipients()
                                } label: {
                                    Label(
                                        tr("טען נמענים מחדש", "Reload recipients"),
                                        systemImage: "arrow.clockwise"
                                    )
                                    .kmiFont(size: 14, weight: .bold)
                                }
                                .buttonStyle(.bordered)
                                .tint(accentColor)
                            }

                            if canUseLoadedRecipients {
                                selectedCountCard
                            }

                            sendButtons

                        }
                        .padding(16)
                        .padding(.bottom, 84)

                    }
                    .scrollDismissesKeyboard(
                        .interactively
                    )
                    .safeAreaPadding(
                        .bottom,
                        8
                    )

                }

            }
        }

        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .preferredColorScheme(
            preferredScreenColorScheme
        )
        .onAppear {
            isBroadcastVisible = true
            activeRecipientsRequestID = UUID()
            isLoadingRecipients = false

            auth.reloadProfileIfSignedIn()
            preloadDefaults()
            syncBroadcastLoading()
        }
        .onChange(of: needsBroadcastLoading) { _, _ in
            syncBroadcastLoading()
        }
        .onDisappear {
            isBroadcastVisible = false
            syncBroadcastLoading()
        }
        .onChange(of: region) { _, _ in

            guard !isPreloadingDefaults else {

                return

            }

            activeRecipientsRequestID = UUID()
            isLoadingRecipients = false

            branch = ""
            recipients = []
            availableBranchGroups = []
            availableBranchGroupCounts = [:]
            selectedTargetGroups = []

        }
        .onChange(of: branch) { _, newBranch in

            guard !isPreloadingDefaults else {

                return

            }

            recipients = []
            availableBranchGroups = []
            availableBranchGroupCounts = [:]

            let cleanBranch =
                newBranch.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !cleanBranch.isEmpty else {

                activeRecipientsRequestID = UUID()
                selectedTargetGroups = []
                isLoadingRecipients = false
                return

            }

            if coachGroupKey.isEmpty {

                selectedTargetGroups = []
                loadRecipients()

            } else {

                let initialGroups =
                    Set([coachGroupKey])

                if selectedTargetGroups == initialGroups {

                    loadRecipients()

                } else {

                    selectedTargetGroups =
                        initialGroups

                }

            }

        }

        .onChange(of: sendScope) { _, newScope in

            guard !isPreloadingDefaults else {

                return

            }

            if newScope == "branch" {

                if selectedTargetGroups.isEmpty {

                    loadRecipients()

                } else {

                    selectedTargetGroups = []
                    loadRecipients()

                }

            } else if selectedTargetGroups.isEmpty,
                      !coachGroupKey.isEmpty {

                selectedTargetGroups.insert(
                    coachGroupKey
                )

            } else {

                loadRecipients()

            }

        }
        .onChange(of: selectedTargetGroups) { _, _ in

            guard
                !isPreloadingDefaults,
                sendScope != "branch"
            else {

                return

            }

            loadRecipients()

        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .coachBroadcastShareRequested
            )
        ) { _ in

            shareBroadcastPdf()

        }
        .alert(
            tr("הודעה", "Message"),
            isPresented: $showAlert
        ) {

            Button(
                tr("סגור", "Close"),
                role: .cancel
            ) { }

        } message: {

            Text(alertText ?? "")

        }
        .sheet(item: $pdfShareItem) { item in
            KmiShareSheet(items: [item.url])
        }

    }

    private var sectionHeader: some View {

        Text(
            tr(
                "פרטי ההודעה",
                "Message details"
            )
        )
        .kmiFont(
            size: 18,
            weight: .heavy
        )
        .foregroundStyle(
            KmiAppTheme.sectionHeaderContentColor
        )
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .frame(
            maxWidth: .infinity,
            minHeight: 54,
            maxHeight: 54,
            alignment: .center
        )
        .padding(.horizontal, 20)
        .background(
            KmiAppTheme.sectionHeaderBrush
        )
        .accessibilityAddTraits(
            .isHeader
        )

    }

    private var inputFormCard: some View {

        VStack(spacing: 10) {
            regionPickerCard

            if !region.isEmpty {
                branchPickerCard
            }

            messageCard
        }
        .padding(12)
        .background(panelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )

    }

    private var audienceCard: some View {
        Group {
            if !branch.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        tr(
                            "בחירת קבוצות לשליחה",
                            "Select groups to include"
                        )
                    )
                    .kmiFont(size: 15, weight: .heavy)
                    .foregroundStyle(primaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )

                    audienceButton(
                        title: tr(
                            "כל הסניף",
                            "Entire branch"
                        ),
                        subtitle: tr(
                            "\(recipients.count) מתאמנים פעילים",
                            "\(recipients.count) active trainees"
                        ),
                        isSelected:
                            sendScope == "branch"
                    ) {

                        guard
                            !isLoadingRecipients,
                            !isSending
                        else {

                            return

                        }

                        sendScope = "branch"

                    }

                    if availableBranchGroups.isEmpty {

                        if isLoadingRecipients {

                            Color.clear
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: 42
                                )
                                .accessibilityHidden(true)

                        }

                    } else {
                        Button {
                            sendScope = "groups"

                            if selectedTargetGroups
                                .isSuperset(
                                    of: availableBranchGroups
                                ) {
                                selectedTargetGroups = []
                            } else {
                                selectedTargetGroups =
                                    Set(availableBranchGroups)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(
                                    systemName:
                                        selectedTargetGroups
                                            .isSuperset(
                                                of:
                                                    availableBranchGroups
                                            )
                                        ? "checkmark.square.fill"
                                        : "square"
                                )
                                .kmiFont(
                                    size: 20,
                                    weight: .bold
                                )
                                .foregroundStyle(accentColor)
                                .accessibilityHidden(true)

                                Text(
                                    tr(
                                        "בחירת כל הקבוצות",
                                        "Select all groups"
                                    )
                                )
                                .kmiFont(
                                    size: 14,
                                    weight: .heavy
                                )
                                .foregroundStyle(
                                    primaryTextColor
                                )

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(elevatedColor)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )
                            .overlay(
                                RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                                .stroke(
                                    borderColor,
                                    lineWidth: 1
                                )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            isLoadingRecipients ||
                            isSending
                        )
                        .opacity(
                            isLoadingRecipients ||
                            isSending
                                ? 0.58
                                : 1
                        )
                        .accessibilityLabel(
                            tr(
                                "בחירת כל הקבוצות",
                                "Select all groups"
                            )
                        )
                        .accessibilityValue(
                            selectedTargetGroups
                                .isSuperset(
                                    of: availableBranchGroups
                                )
                                ? tr(
                                    "כל הקבוצות נבחרו",
                                    "All groups selected"
                                )
                                : tr(
                                    "לא כל הקבוצות נבחרו",
                                    "Not all groups selected"
                                )
                        )

                        VStack(spacing: 8) {
                            ForEach(
                                availableBranchGroups,
                                id: \.self
                            ) { groupName in
                                groupSelectionRow(
                                    groupName
                                )
                            }
                        }
                    }

                    Text(
                        sendScope == "branch"
                        ? tr(
                            "ההודעה תישלח לכל המתאמנים הפעילים בסניף שנבחר.",
                            "The message will be sent to all active trainees in the selected branch."
                        )
                        : effectiveGroupKeys.isEmpty
                        ? tr(
                            "סמן לפחות קבוצה אחת כדי להציג מתאמנים ולשלוח הודעה.",
                            "Select at least one group to show trainees and send a message."
                        )
                        : tr(
                            "ההודעה תישלח רק לקבוצות: \(selectedGroupsSummary)",
                            "The message will be sent only to: \(selectedGroupsSummary)"
                        )
                    )
                    .kmiFont(size: 12, weight: .semibold)
                    .foregroundStyle(
                        sendScope != "branch" &&
                        effectiveGroupKeys.isEmpty
                            ? KmiAppTheme.tertiary(
                                for: activeColorScheme
                            )
                            : secondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .padding(12)
                .background(panelColor)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20,
                        style: .continuous
                    )
                )
            }
        }
    }

    private func groupSelectionRow(
        _ groupName: String
    ) -> some View {
        let isSelected =
            sendScope != "branch" &&
            selectedTargetGroups.contains(groupName)

        return Button {
            sendScope = "groups"

            if isSelected {
                selectedTargetGroups.remove(groupName)
            } else {
                selectedTargetGroups.insert(groupName)
            }
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName:
                        isSelected
                            ? "checkmark.square.fill"
                            : "square"
                )
                .kmiFont(
                    size: 21,
                    weight: .bold
                )
                .foregroundStyle(
                    isSelected
                        ? accentColor
                        : secondaryTextColor
                )
                .accessibilityHidden(true)

                VStack(
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing,
                    spacing: 3
                ) {
                    Text(groupName)
                        .kmiFont(
                            size: 15,
                            weight: .heavy
                        )
                        .foregroundStyle(primaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: screenFrameAlignment
                        )

                    Text(
                        tr(
                            "\(availableBranchGroupCounts[groupName] ?? 0) מתאמנים",
                            "\(availableBranchGroupCounts[groupName] ?? 0) trainees"
                        )
                    )
                    .kmiFont(
                        size: 12,
                        weight: .semibold
                    )
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                isSelected
                ? accentColor.opacity(
                    isDarkMode ? 0.18 : 0.10
                )
                : elevatedColor
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    isSelected
                    ? accentBorderColor
                    : borderColor,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            isLoadingRecipients ||
            isSending
        )
        .opacity(
            isLoadingRecipients ||
            isSending
                ? 0.58
                : 1
        )
        .accessibilityLabel(
            tr(
                "קבוצה \(groupName)",
                "Group \(groupName)"
            )
        )
        .accessibilityValue(
            isSelected
                ? tr(
                    "נבחרה",
                    "Selected"
                )
                : tr(
                    "לא נבחרה",
                    "Not selected"
                )
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )

    }

    private func audienceButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .kmiFont(size: 17, weight: .heavy)
                    .foregroundStyle(
                        isSelected
                            ? KmiAppTheme.onPrimary(
                                for: activeColorScheme
                            )
                            : primaryTextColor
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .kmiFont(
                        size: 11,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        isSelected
                            ? KmiAppTheme.onPrimary(
                                for: activeColorScheme
                            ).opacity(0.82)
                            : secondaryTextColor
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 82)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? accentColor
                        : elevatedColor
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? accentBorderColor
                        : borderColor,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )

    }

    private var regionPickerCard: some View {

        KmiPremiumDropdown(
            title: tr(
                "אזור",
                "Region"
            ),
            options: regionOptions,
            selectedValue: $region,
            placeholder: tr(
                "בחר אזור",
                "Choose region"
            ),
            isEnglish: isEnglish,
            isEnabled:
                !regionOptions.isEmpty &&
                !isLoadingRecipients &&
                !isSending
        )

    }

    private var branchPickerCard: some View {

        KmiPremiumDropdown(
            title: tr(
                "סניף",
                "Branch"
            ),
            options: branchOptions,
            selectedValue: $branch,
            placeholder: tr(
                "בחר סניף",
                "Choose branch"
            ),
            isEnglish: isEnglish,
            isEnabled:
                !region.isEmpty &&
                !branchOptions.isEmpty &&
                !isLoadingRecipients &&
                !isSending
        )

    }

    private var messageCard: some View {

        VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing: 8
        ) {

            Text(
                tr(
                    "טקסט ההודעה",
                    "Message text"
                )
            )
            .kmiFont(
                size: 14,
                weight: .bold
            )
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            ZStack(alignment: .topLeading) {

                if message.isEmpty {

                    Text(
                        tr(
                            "כתוב הודעה למתאמנים...",
                            "Write a message to the trainees..."
                        )
                    )
                    .kmiFont(
                        size: 15,
                        weight: .medium
                    )
                    .foregroundStyle(
                        secondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)

                }

                TextEditor(
                    text: $message
                )
                .kmiFont(
                    size: 15,
                    weight: .medium
                )
                .foregroundStyle(
                    primaryTextColor
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 112,
                    alignment: .topLeading
                )
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.clear)
                .multilineTextAlignment(
                    screenTextAlignment
                )

            }
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .background(fieldColor)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    borderColor,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )

        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )

    }

    private var recipientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(recipientsTitleText)
                    .kmiFont(size: 14, weight: .bold)
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                selectAllButton
            }

            if isLoadingRecipients {

                Color.clear
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 54
                    )
                    .accessibilityHidden(true)

            } else if !branch.isEmpty && !canUseLoadedRecipients {
                Text(tr(
                    "יש לטעון מחדש את רשימת הנמענים.",
                    "Reload the recipient list."
                ))
                .kmiFont(size: 15, weight: .semibold)
                .foregroundStyle(secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .padding(.vertical, 10)

            } else if
                !region.isEmpty &&
                !branch.isEmpty &&
                recipients.isEmpty {

                Text(emptyRecipientsText)
                    .kmiFont(size: 15, weight: .bold)
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.vertical, 10)

            } else if recipients.isEmpty {
                Text(
                    tr(
                        "בחר אזור וסניף כדי לטעון נמענים.",
                        "Choose region and branch to load recipients."
                    )
                )
                .kmiFont(size: 15, weight: .medium)
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(
                    screenTextAlignment
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .padding(.vertical, 10)

            } else {

                LazyVStack(spacing: 8) {

                    ForEach(displayedRecipients) { recipient in

                        recipientRow(recipient)

                    }

                }
                .padding(8)
                .background(elevatedColor)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            }
        }
        .padding(14)
        .background(panelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private var recipientsTitleText: String {
        if sendScope == "branch" {
            return tr(
                "נמענים בסניף: \(recipients.count)",
                "Recipients in branch: \(recipients.count)"
            )
        }

        return tr(
            "נמענים בקבוצות שנבחרו: \(recipients.count)",
            "Recipients in selected groups: \(recipients.count)"
        )
    }

    private var emptyRecipientsText: String {
        if sendScope == "branch" {
            return tr(
                "לא נמצאו מתאמנים פעילים בסניף שנבחר.",
                "No active trainees were found in the selected branch."
            )
        }

        if effectiveGroupKeys.isEmpty {
            return tr(
                "לא נבחרו קבוצות לשליחה.",
                "No groups were selected for sending."
            )
        }

        return tr(
            "לא נמצאו מתאמנים פעילים בקבוצות שנבחרו.",
            "No active trainees were found in the selected groups."
        )
    }

    private var selectAllButton: some View {
        Button {
            let newValue = !allSelected

            recipients = recipients.map {
                var copy = $0
                copy.selected = newValue
                return copy
            }

        } label: {
            Text(
                allSelected
                    ? tr(
                        "בטל סימון לכולם",
                        "Unselect all"
                    )
                    : tr(
                        "סמן את כל חברי הקבוצה",
                        "Select all group members"
                    )
            )
            .kmiFont(size: 13, weight: .bold)
            .foregroundStyle(
                allSelected
                    ? KmiAppTheme.onPrimary(
                        for: activeColorScheme
                    )
                    : primaryTextColor
            )
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                allSelected
                    ? accentColor
                    : elevatedColor
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    allSelected
                        ? accentBorderColor
                        : borderColor,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            recipients.isEmpty ||
            isSending
        )
        .opacity(
            recipients.isEmpty
                ? 0.45
                : isSending
                ? 0.72
                : 1
        )
        .accessibilityLabel(
            allSelected
                ? tr(
                    "בטל סימון לכל המתאמנים",
                    "Unselect all trainees"
                )
                : tr(
                    "סמן את כל המתאמנים",
                    "Select all trainees"
                )
        )

    }

    private func recipientRow(
        _ recipient: CoachBroadcastRecipient
    ) -> some View {
        let isSelected =
            recipients.first(
                where: {
                    $0.id == recipient.id
                }
            )?.selected ?? recipient.selected

        let selectionBinding = Binding<Bool>(

            get: {

                recipients.first(
                    where: {
                        $0.id == recipient.id
                    }
                )?.selected ?? false

            },

            set: { newValue in

                recipients = recipients.map {

                    guard $0.id == recipient.id else {

                        return $0

                    }

                    var copy = $0
                    copy.selected = newValue
                    return copy

                }

            }

        )

        return Button {
            selectionBinding.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                recipientTexts(recipient, isSelected: isSelected)

                Toggle("", isOn: selectionBinding)
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? accentColor.opacity(
                        isDarkMode ? 0.28 : 0.15
                    )
                    : fieldColor
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? accentBorderColor
                        : borderColor,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .opacity(isSending ? 0.72 : 1)
        .accessibilityLabel(recipient.name)
        .accessibilityValue(
            isSelected
                ? tr(
                    "נבחר",
                    "Selected"
                )
                : tr(
                    "לא נבחר",
                    "Not selected"
                )
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )

    }

    private func recipientTexts(
        _ recipient: CoachBroadcastRecipient,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipient.name)
                .kmiFont(size: 16, weight: .bold)
                .foregroundStyle(primaryTextColor)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Text(
                demoPrivacy.isEnabled
                    ? tr("מספר מוסתר", "Hidden number")
                    : recipient.phone.isEmpty
                        ? tr("ללא מספר טלפון", "No phone number")
                        : recipient.phone
            )
            .kmiFont(size: 13, weight: .medium)
            .foregroundStyle(isSelected ? accentColor : secondaryTextColor)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedCountCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(
                sendScope == "branch"
                    ? tr(
                        "מתאמנים בסניף: \(recipients.count)",
                        "Trainees in branch: \(recipients.count)"
                    )
                    : tr(
                        "מתאמנים בקבוצות שנבחרו: \(recipients.count)",
                        "Trainees in selected groups: \(recipients.count)"
                    )
            )
            .kmiFont(size: 15, weight: .bold)
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(
                tr(
                    "מתאמנים נבחרים: \(selectedRecipients.count)",
                    "Selected trainees: \(selectedRecipients.count)"
                )
            )
            .kmiFont(size: 15, weight: .bold)
            .foregroundStyle(accentColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(12)
        .background(panelColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private var sendButtons: some View {
        let isDisabled =
            isSending ||
            !canUseLoadedRecipients ||
            message
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty ||
            selectedUids.isEmpty

        return Button {

            sendSmsToSelected()

        } label: {

            HStack(spacing: 8) {

                Image(systemName: "paperplane.fill")
                    .kmiIconSize(15)
                    .accessibilityHidden(true)

                Text(
                    isSending
                        ? tr(
                            "שולח הודעה...",
                            "Sending message..."
                        )
                        : sendButtonText
                )
                .kmiFont(
                    size: 15,
                    weight: .heavy
                )
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            }
            .foregroundStyle(
                KmiAppTheme.onPrimary(
                    for: activeColorScheme
                )
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(
                    KmiAppTheme.primary(
                        for: activeColorScheme
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    KmiAppTheme.outlineVariant(
                        for: activeColorScheme
                    ),
                    lineWidth: 1
                )
            )

        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(sendButtonText)
        .accessibilityHint(
            tr(
                "שומר את ההודעה ושולח אותה לנמענים שנבחרו",
                "Saves the message and sends it to the selected recipients"
            )
        )

    }

    private func preloadDefaults() {

        isPreloadingDefaults = true

        let resolvedRegion =
            region
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
                ? auth.userRegion.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                : region.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        region = resolvedRegion

        let availableBranches =
            branchesByRegion[resolvedRegion] ?? []

        let savedBranch =
            auth.userBranch
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let currentBranch =
            branch.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if
            !currentBranch.isEmpty,
            availableBranches.contains(currentBranch) {

            branch = currentBranch

        } else if availableBranches.contains(savedBranch) {

            branch = savedBranch

        } else {

            branch =
                availableBranches.first ?? ""

        }

        if selectedTargetGroups.isEmpty,
           !coachGroupKey.isEmpty {

            selectedTargetGroups =
                Set([coachGroupKey])

        }

        DispatchQueue.main.async {

            isPreloadingDefaults = false

            let cleanRegion =
                region.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let cleanBranch =
                branch.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard
                !cleanRegion.isEmpty,
                !cleanBranch.isEmpty
            else {

                isLoadingRecipients = false
                return

            }

            loadRecipients()

        }

    }

    private func loadRecipients() {
        let context = recipientsContext
        let requestID = UUID()
        activeRecipientsRequestID = requestID

        guard isCoach,
              !context.uid.isEmpty,
              !context.region.isEmpty,
              !context.branch.isEmpty else {
            isLoadingRecipients = false
            loadedRecipientsContext = nil
            recipients = []
            availableBranchGroups = []
            availableBranchGroupCounts = [:]
            return
        }

        let previousSelection = Dictionary(
            recipients.map { ($0.uid, $0.selected) },
            uniquingKeysWith: { first, _ in first }
        )

        isLoadingRecipients = true
        loadedRecipientsContext = nil

        Task { @MainActor in
            defer {
                if activeRecipientsRequestID == requestID {
                    isLoadingRecipients = false
                }
            }

            do {
                let result = try await Functions.functions()
                    .httpsCallable("loadSecureCoachBroadcastRecipients")
                    .call([
                        "branch": context.branch,
                        "groups": context.groups
                    ] as [String: Any])

                guard activeRecipientsRequestID == requestID,
                      recipientsContext == context else { return }

                guard let payload = result.data as? [String: Any],
                      let rawRecipients = payload["recipients"] as? [[String: Any]],
                      let rawGroups = payload["availableGroups"] as? [String] else {
                    showError(tr(
                        "השרת לא החזיר רשימת נמענים תקינה.",
                        "The server returned an invalid recipient list."
                    ))
                    return
                }

                let groups = Set(rawGroups.map(trimmedBroadcastValue).filter { !$0.isEmpty })
                availableBranchGroups = groups.sorted()

                let rawCounts = payload["groupCounts"] as? [String: Any] ?? [:]
                var counts: [String: Int] = [:]

                for (rawGroup, value) in rawCounts {
                    let group = trimmedBroadcastValue(rawGroup)
                    guard groups.contains(group) else { continue }

                    let count = (value as? NSNumber)?.intValue
                        ?? (value as? String).flatMap { Int(trimmedBroadcastValue($0)) }

                    if let count, count >= 0 {
                        counts[group] = count
                    }
                }

                availableBranchGroupCounts = counts

                let validGroups = Set(context.groups).intersection(groups)
                if context.scope != "branch", validGroups != Set(context.groups) {
                    recipients = []
                    selectedTargetGroups = validGroups
                    return
                }

                // קריאה עם groups ריק משמשת לגילוי קבוצות גם במצב בחירת קבוצות.
                // במצב הזה מציגים נמענים רק לאחר בחירת קבוצה.
                guard context.scope == "branch" || !context.groups.isEmpty else {
                    recipients = []
                    loadedRecipientsContext = context
                    return
                }

                var seenUids = Set<String>()
                recipients = rawRecipients.compactMap { data -> CoachBroadcastRecipient? in
                    let uid = trimmedBroadcastValue(data["uid"] as? String ?? "")
                    guard !uid.isEmpty, seenUids.insert(uid).inserted else { return nil }

                    let phone = trimmedBroadcastValue(data["phone"] as? String ?? "")
                    let email = trimmedBroadcastValue(data["email"] as? String ?? "")
                    let name = trimmedBroadcastValue(data["name"] as? String ?? "")
                    let displayName = [name, email, phone].first { !$0.isEmpty }
                        ?? tr("מתאמן ללא שם", "Unnamed trainee")

                    return CoachBroadcastRecipient(
                        id: uid,
                        uid: uid,
                        name: displayName,
                        phone: phone,
                        email: email,
                        selected: previousSelection[uid] ?? true
                    )
                }
                .sorted {
                    let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                    return order == .orderedSame ? $0.uid < $1.uid : order == .orderedAscending
                }

                loadedRecipientsContext = context
            } catch {
                guard activeRecipientsRequestID == requestID,
                      recipientsContext == context else { return }

                showError(tr(
                    "לא ניתן לאמת את רשימת הנמענים כרגע. יש לטעון אותה מחדש לפני השליחה.",
                    "Could not verify the recipient list. Reload it before sending."
                ))
            }
        }
    }

    private func trimmedBroadcastValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private func sendSmsToSelected() {
        guard !isSending, canUseLoadedRecipients else {
            return
        }

        let cleanMessage = message
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanMessage.isEmpty else {
            showError(
                tr(
                    "נא לכתוב טקסט להודעה",
                    "Please write a message"
                )
            )
            return
        }

        guard !selectedUids.isEmpty else {
            showError(
                tr(
                    "לא נבחרו נמענים – סמן לפחות מתאמן אחד",
                    "No recipients selected — select at least one trainee"
                )
            )
            return
        }

        let context = recipientsContext
        let targetUids = selectedUids
        let targetPhones = selectedPhones

        isSending = true

        persistBroadcast(
            context: context,
            message: cleanMessage,
            targetUids: targetUids
        ) { succeeded in
            guard succeeded else { return }

            openMessagesApp(
                message: cleanMessage,
                phones: targetPhones
            )
        }
    }

    private func openMessagesApp(
        message cleanMessage: String,
        phones: [String]
    ) {
        let smsNumberCount = phones.count
        let numbers = phones
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        guard !numbers.isEmpty else {
            isSending = false
            message = ""

            showError(
                tr(
                    "ההודעה נשמרה ונשלחה לעיבוד Push. לא נמצאו מספרי טלפון לפתיחת SMS.",
                    "The message was saved for Push delivery. No phone numbers were available for SMS."
                )
            )
            return
        }

        var components = URLComponents()
        components.scheme = "sms"
        components.path = numbers
        components.queryItems = [
            URLQueryItem(
                name: "body",
                value: cleanMessage
            )
        ]

        guard let url = components.url,
              UIApplication.shared.canOpenURL(url)
        else {
            isSending = false
            message = ""

            showError(
                tr(
                    "ההודעה נשמרה לעיבוד Push, אבל לא ניתן לפתוח את אפליקציית ההודעות.",
                    "The message was saved for Push delivery, but the messaging app could not be opened."
                )
            )
            return
        }

        UIApplication.shared.open(
            url,
            options: [:]
        ) { opened in
            DispatchQueue.main.async {
                isSending = false

                if opened {
                    message = ""

                    showError(
                        tr(
                            "השידור הועבר לעיבוד ונפתח מסך SMS עם \(smsNumberCount) מספרי טלפון.",
                            "The broadcast was queued and the SMS composer opened with \(smsNumberCount) phone numbers."
                        )
                    )
                } else {
                    showError(
                        tr(
                            "ההודעה נשמרה לעיבוד Push, אך אפליקציית ההודעות לא נפתחה.",
                            "The message was saved for Push delivery, but the messaging app did not open."
                        )
                    )
                }
            }
        }
    }

    private func shareBroadcastPdf() {
        guard isCoach,
              !isSending,
              !isLoadingRecipients,
              pdfShareItem == nil else { return }

        guard branch.isEmpty || canUseLoadedRecipients else {
            showError(tr(
                "יש לטעון מחדש את רשימת הנמענים לפני ייצוא הדוח.",
                "Reload the recipient list before exporting the report."
            ))
            return
        }

        do {

            let url = try createBroadcastPdf()

            pdfShareItem =
                CoachBroadcastPdfShareItem(
                    url: url
                )

        } catch {

            showError(
                tr(
                    "לא ניתן ליצור כרגע את קובץ ה־PDF.",
                    "The PDF file cannot be created right now."
                )
            )

        }

    }

    private func createBroadcastPdf() throws -> URL {

        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let pageBounds = CGRect(
            x: 0,
            y: 0,
            width: pageWidth,
            height: pageHeight
        )

        let margin: CGFloat = 32
        let contentRight =
            pageWidth - margin

        let contentBottom =
            pageHeight -
            KmiPdfFooter.CONTENT_BOTTOM_PADDING

        let textColor = UIColor(
            red: 15 / 255.0,
            green: 23 / 255.0,
            blue: 42 / 255.0,
            alpha: 1
        )

        let mutedTextColor = UIColor(
            red: 80 / 255.0,
            green: 100 / 255.0,
            blue: 120 / 255.0,
            alpha: 1
        )

        let accentPdfColor = UIColor(
            red: 36 / 255.0,
            green: 103 / 255.0,
            blue: 158 / 255.0,
            alpha: 1
        )

        let cardBackgroundColor = UIColor(
            red: 248 / 255.0,
            green: 250 / 255.0,
            blue: 252 / 255.0,
            alpha: 1
        )

        let cardBorderColor = UIColor(
            red: 226 / 255.0,
            green: 232 / 255.0,
            blue: 240 / 255.0,
            alpha: 1
        )

        let fileName =
            isEnglish
                ? "Broadcast Message.pdf"
                : "שידור הודעה.pdf"

        let directory =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "KmiSharedPdfs",
                    isDirectory: true
                )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let fileURL =
            directory.appendingPathComponent(
                fileName,
                isDirectory: false
            )

        let rendererFormat =
            UIGraphicsPDFRendererFormat()

        rendererFormat.documentInfo = [
            kCGPDFContextTitle as String:
                isEnglish
                    ? "KAMI Broadcast Message"
                    : "שידור הודעה לקבוצה",
            kCGPDFContextCreator as String:
                "KAMI"
        ]

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageBounds,
                format: rendererFormat
            )

        let selectedPdfRecipients = canUseLoadedRecipients
            ? displayedRecipients.filter { $0.selected }
            : []

        let cleanGroups =
            sendScope == "branch"
                ? []
                : effectiveGroupKeys

        let data = renderer.pdfData { rendererContext in

            let context =
                rendererContext.cgContext

            var pageNumber = 0
            var currentY =
                KmiPdfHeader.CONTENT_TOP

            func paragraphStyle(
                alignment: NSTextAlignment,
                lineBreakMode: NSLineBreakMode =
                    .byWordWrapping
            ) -> NSParagraphStyle {

                let style =
                    KmiPdfDirection
                        .paragraphStyle(
                            isEnglish: isEnglish
                        )
                        .mutableCopy()
                        as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()

                style.baseWritingDirection =
                    KmiPdfDirection.textDirection(
                        isEnglish: isEnglish
                    )

                style.alignment = alignment
                style.lineBreakMode = lineBreakMode

                return style

            }

            func textAttributes(
                font: UIFont,
                color: UIColor,
                alignment: NSTextAlignment
            ) -> [NSAttributedString.Key: Any] {

                [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle:
                        paragraphStyle(
                            alignment: alignment
                        )
                ]

            }

            func drawHeader() {

                KmiPdfHeader.draw(
                    context: context,
                    pageWidth: pageWidth,
                    isEnglish: isEnglish,
                    titleHebrew:
                        "שידור הודעה לקבוצה",
                    titleEnglish:
                        "Broadcast Message",
                    subtitleHebrew:
                        "דו״ח תקשורת מאמן",
                    subtitleEnglish:
                        "Coach communication report"
                )

            }

            func drawFooter() {

                KmiPdfFooter.draw(
                    context: context,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    pageNumber: pageNumber,
                    totalPages: nil,
                    isEnglish: isEnglish
                )

            }

            func beginPage() {

                if pageNumber > 0 {

                    drawFooter()

                }

                rendererContext.beginPage()

                pageNumber += 1
                currentY =
                    KmiPdfHeader.CONTENT_TOP

                drawHeader()

            }

            func ensureSpace(
                _ requiredHeight: CGFloat
            ) {

                if
                    currentY + requiredHeight >
                    contentBottom {

                    beginPage()

                }

            }

            func drawText(
                _ value: String,
                rect: CGRect,
                font: UIFont,
                color: UIColor = textColor,
                alignment: NSTextAlignment? = nil
            ) {

                let resolvedAlignment =
                    alignment ??
                    KmiPdfDirection.textAlign(
                        isEnglish: isEnglish
                    )

                (value as NSString).draw(
                    with: rect,
                    options: [
                        .usesLineFragmentOrigin,
                        .usesFontLeading
                    ],
                    attributes:
                        textAttributes(
                            font: font,
                            color: color,
                            alignment:
                                resolvedAlignment
                        ),
                    context: nil
                )

            }

            func measuredHeight(
                _ value: String,
                width: CGFloat,
                font: UIFont
            ) -> CGFloat {

                let attributes =
                    textAttributes(
                        font: font,
                        color: textColor,
                        alignment:
                            KmiPdfDirection.textAlign(
                                isEnglish: isEnglish
                            )
                    )

                let bounds =
                    (value as NSString).boundingRect(
                        with: CGSize(
                            width: width,
                            height:
                                .greatestFiniteMagnitude
                        ),
                        options: [
                            .usesLineFragmentOrigin,
                            .usesFontLeading
                        ],
                        attributes: attributes,
                        context: nil
                    )

                return ceil(bounds.height)

            }

            func drawSectionTitle(
                _ value: String
            ) {

                let height: CGFloat = 24

                ensureSpace(height + 8)

                drawText(
                    value,
                    rect: CGRect(
                        x: margin,
                        y: currentY,
                        width:
                            contentRight - margin,
                        height: height
                    ),
                    font:
                        .systemFont(
                            ofSize: 16,
                            weight: .bold
                        ),
                    color: accentPdfColor
                )

                currentY += height + 4

            }

            func drawInfoRow(
                label: String,
                value: String
            ) {

                let cleanValue =
                    value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard !cleanValue.isEmpty else {

                    return

                }

                let rowHeight: CGFloat = 38

                ensureSpace(rowHeight + 8)

                let rect = CGRect(
                    x: margin,
                    y: currentY,
                    width:
                        contentRight - margin,
                    height: rowHeight
                )

                let path =
                    UIBezierPath(
                        roundedRect: rect,
                        cornerRadius: 8
                    )

                cardBackgroundColor.setFill()
                path.fill()

                cardBorderColor.setStroke()
                path.lineWidth = 1
                path.stroke()

                drawText(
                    "\(label): \(cleanValue)",
                    rect: rect.insetBy(
                        dx: 12,
                        dy: 10
                    ),
                    font:
                        .systemFont(
                            ofSize: 11,
                            weight: .regular
                        )
                )

                currentY += rowHeight + 8

            }

            func drawWrappedBlock(
                _ value: String,
                font: UIFont,
                horizontalPadding: CGFloat = 0,
                verticalPadding: CGFloat = 0,
                backgroundColor: UIColor? = nil
            ) {

                let cleanValue =
                    value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                guard !cleanValue.isEmpty else {

                    return

                }

                let availableWidth =
                    contentRight -
                    margin -
                    horizontalPadding * 2

                let textHeight =
                    measuredHeight(
                        cleanValue,
                        width: availableWidth,
                        font: font
                    )

                let blockHeight =
                    max(
                        24,
                        textHeight +
                        verticalPadding * 2
                    )

                ensureSpace(blockHeight + 8)

                let blockRect = CGRect(
                    x: margin,
                    y: currentY,
                    width:
                        contentRight - margin,
                    height: blockHeight
                )

                if let backgroundColor {

                    let path =
                        UIBezierPath(
                            roundedRect: blockRect,
                            cornerRadius: 8
                        )

                    backgroundColor.setFill()
                    path.fill()

                    cardBorderColor.setStroke()
                    path.lineWidth = 1
                    path.stroke()

                }

                drawText(
                    cleanValue,
                    rect: blockRect.insetBy(
                        dx: horizontalPadding,
                        dy: verticalPadding
                    ),
                    font: font
                )

                currentY += blockHeight + 8

            }

            beginPage()

            drawSectionTitle(
                isEnglish
                    ? "Broadcast details"
                    : "פרטי השידור"
            )

            drawInfoRow(
                label:
                    isEnglish
                        ? "Region"
                        : "אזור",
                value: region
            )

            drawInfoRow(
                label:
                    isEnglish
                        ? "Branch"
                        : "סניף",
                value: branch
            )

            if sendScope == "branch" {

                drawInfoRow(
                    label:
                        isEnglish
                            ? "Audience"
                            : "קהל יעד",
                    value:
                        isEnglish
                            ? "Entire branch"
                            : "כל הסניף"
                )

            } else {

                drawInfoRow(
                    label:
                        isEnglish
                            ? "Groups"
                            : "קבוצות",
                    value:
                        cleanGroups.joined(
                            separator: ", "
                        )
                )

            }

            drawInfoRow(
                label:
                    isEnglish
                        ? "Selected recipients"
                        : "נמענים שנבחרו",
                value:
                    "\(selectedPdfRecipients.count)"
            )

            drawSectionTitle(
                isEnglish
                    ? "Message"
                    : "תוכן ההודעה"
            )

            drawWrappedBlock(
                message,
                font:
                    .systemFont(
                        ofSize: 11,
                        weight: .regular
                    ),
                horizontalPadding: 12,
                verticalPadding: 10,
                backgroundColor:
                    cardBackgroundColor
            )

            if !selectedPdfRecipients.isEmpty {

                drawSectionTitle(
                    isEnglish
                        ? "Recipients"
                        : "רשימת נמענים"
                )

                for (
                    index,
                    recipient
                ) in selectedPdfRecipients.enumerated() {

                    let recipientName =
                        recipient.name
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )

                    let resolvedName =
                        recipientName.isEmpty
                            ? (
                                isEnglish
                                    ? "Unnamed trainee"
                                    : "מתאמן ללא שם"
                            )
                            : recipientName

                    var line =
                        "\(index + 1). \(resolvedName)"

                    if
                        !demoPrivacy.isEnabled,
                        !recipient.phone
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            )
                            .isEmpty {

                        line +=
                            " · \(recipient.phone)"

                    }

                    let rowFont =
                        UIFont.systemFont(
                            ofSize: 10.5,
                            weight: .regular
                        )

                    let rowHeight =
                        max(
                            24,
                            measuredHeight(
                                line,
                                width:
                                    contentRight -
                                    margin -
                                    20,
                                font: rowFont
                            ) + 10
                        )

                    ensureSpace(rowHeight + 4)

                    drawText(
                        line,
                        rect: CGRect(
                            x: margin + 8,
                            y: currentY + 5,
                            width:
                                contentRight -
                                margin -
                                16,
                            height:
                                rowHeight - 10
                        ),
                        font: rowFont,
                        color: mutedTextColor
                    )

                    currentY += rowHeight + 4

                }

            }

            drawFooter()

        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL

    }

    private func persistBroadcast(
        context: RecipientsContext,
        message: String,
        targetUids: [String],
        completion: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            guard canUseLoadedRecipients,
                  recipientsContext == context,
                  !context.uid.isEmpty,
                  !context.branch.isEmpty,
                  !message.isEmpty,
                  !targetUids.isEmpty,
                  context.scope == "branch" || !context.groups.isEmpty else {
                isSending = false
                completion(false)
                return
            }

            do {
                _ = try await Functions.functions()
                    .httpsCallable("createSecureCoachBroadcast")
                    .call([
                        "region": context.region,
                        "branch": context.branch,
                        "message": message,
                        "groups": context.groups,
                        "targetUids": targetUids
                    ] as [String: Any])

                guard Auth.auth().currentUser?.uid == context.uid else {
                    isSending = false
                    completion(false)
                    return
                }

                completion(true)
            } catch {
                isSending = false
                showError(tr(
                    "לא ניתן לאשר את שליחת השידור. בדוק אם ההודעה כבר נשלחה לפני ניסיון חוזר.",
                    "Could not confirm the broadcast. Check whether the message was sent before trying again."
                ))
                completion(false)
            }
        }
    }


    private func showError(_ text: String) {
        alertText = text
        showAlert = true
    }
}

private struct CoachBroadcastPdfShareItem:
    Identifiable {

    let id = UUID()
    let url: URL

}

extension Notification.Name {

    static let coachBroadcastShareRequested =
        Notification.Name(
            "kmi.coachBroadcast.sharePdf"
        )

}

private struct CoachBroadcastRecipient: Identifiable {

    let id: String
    let uid: String
    let name: String
    let phone: String
    let email: String
    var selected: Bool
}
