import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct CoachBroadcastView: View {

    @EnvironmentObject
    private var auth: AuthViewModel

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("theme_mode")
    private var themeMode: String = "system"

    @State private var region: String = ""
    @State private var branch: String = ""
    @State private var message: String = ""

    @State private var recipients: [CoachBroadcastRecipient] = []
    @State private var isLoadingRecipients = false
    @State private var isSending = false

    @State private var alertText: String?
    @State private var showAlert = false

    @State private var sendScope: String = "group"

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
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
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

    private var backgroundColors: [Color] {
        isDarkMode
            ? [
                Color(
                    red: 0.01,
                    green: 0.02,
                    blue: 0.09
                ),
                Color(
                    red: 0.06,
                    green: 0.09,
                    blue: 0.16
                ),
                Color(
                    red: 0.12,
                    green: 0.23,
                    blue: 0.54
                ),
                Color(
                    red: 0.22,
                    green: 0.74,
                    blue: 0.97
                )
            ]
            : [
                Color(
                    red: 0.97,
                    green: 0.985,
                    blue: 1.00
                ),
                Color(
                    red: 0.90,
                    green: 0.95,
                    blue: 0.99
                ),
                Color(
                    red: 0.62,
                    green: 0.86,
                    blue: 0.97
                )
            ]
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.84)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.68)
            : Color.black.opacity(0.56)
    }

    private var sectionTitleColor: Color {
        isDarkMode
            ? Color(
                red: 0.88,
                green: 0.95,
                blue: 0.99
            )
            : Color(
                red: 0.04,
                green: 0.20,
                blue: 0.34
            )
    }

    private var panelColor: Color {
        isDarkMode
            ? Color(
                red: 0.04,
                green: 0.07,
                blue: 0.13
            )
            .opacity(0.92)
            : Color.white.opacity(0.90)
    }

    private var elevatedColor: Color {
        isDarkMode
            ? Color(
                red: 0.02,
                green: 0.09,
                blue: 0.18
            )
            : Color.white.opacity(0.97)
    }

    private var fieldColor: Color {
        isDarkMode
            ? Color(
                red: 0.02,
                green: 0.09,
                blue: 0.18
            )
            : Color.white.opacity(0.96)
    }

    private var borderColor: Color {
        isDarkMode
            ? Color.white.opacity(0.13)
            : Color.black.opacity(0.10)
    }

    private var accentColor: Color {
        Color(
            red: 0.05,
            green: 0.65,
            blue: 0.91
        )
    }

    private var accentBorderColor: Color {
        Color(
            red: 0.40,
            green: 0.91,
            blue: 0.98
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
        let region = auth.userRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)

        if !region.isEmpty, !branch.isEmpty {
            return [region: [branch]]
        }

        if !region.isEmpty {
            return [region: []]
        }

        return [:]
    }

    private var regionOptions: [String] {
        Array(branchesByRegion.keys).sorted()
    }

    private var branchOptions: [String] {
        branchesByRegion[region] ?? []
    }

    private var selectedRecipients: [CoachBroadcastRecipient] {
        recipients.filter { $0.selected }
    }

    private var selectedPhones: [String] {
        selectedRecipients
            .map(\.phone)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var selectedUids: [String] {
        selectedRecipients
            .map(\.uid)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private var effectiveGroupKey: String {
        sendScope == "branch" ? "" : coachGroupKey
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
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(accentColor)

                    Text(
                        tr(
                            "המסך זמין למאמנים בלבד",
                            "This screen is available to coaches only"
                        )
                    )
                    .kmiFont(size: 24, weight: .heavy)
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(24)

            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        inputFormCard

                        audienceCard

                        recipientsCard

                        selectedCountCard

                        sendButtons
                    }
                    .padding(16)
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
            auth.reloadProfileIfSignedIn()
            preloadDefaults()
        }
        .onChange(of: region) { _, _ in
            branch = ""
            recipients = []
        }
        .onChange(of: branch) { _, _ in
            loadRecipients()
        }
        .onChange(of: sendScope) { _, _ in
            loadRecipients()
        }
        .alert(tr("הודעה", "Message"), isPresented: $showAlert) {
            Button(tr("סגור", "Close"), role: .cancel) { }
        } message: {
            Text(alertText ?? "")
        }
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
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.16 : 0.07
            ),
            radius: 7,
            x: 0,
            y: 3
        )
    }

    private var audienceCard: some View {
        Group {
            if !coachGroupKey.isEmpty {
                VStack(
                    alignment: isEnglish ? .leading : .trailing,
                    spacing: 10
                ) {
                    Text(
                        tr(
                            "בחירת קהל יעד",
                            "Target audience"
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

                    HStack(spacing: 10) {
                        audienceButton(
                            title: tr(
                                "הקבוצה שלי",
                                "My group"
                            ),
                            subtitle: tr(
                                "רק המתאמנים של הקבוצה",
                                "Only this group's trainees"
                            ),
                            isSelected:
                                sendScope == "group"
                        ) {
                            sendScope = "group"
                        }

                        audienceButton(
                            title: tr(
                                "כל הסניף",
                                "Entire branch"
                            ),
                            subtitle: tr(
                                "כולל כל הקבוצות בסניף",
                                "Includes all groups in branch"
                            ),
                            isSelected:
                                sendScope == "branch"
                        ) {
                            sendScope = "branch"
                        }
                    }

                    Text(
                        sendScope == "group"
                            ? tr(
                                "ההודעה תישלח רק למתאמני הקבוצה: \(coachGroupKey)",
                                "The message will be sent only to trainees in: \(coachGroupKey)"
                            )
                            : tr(
                                "ההודעה תישלח לכל המתאמנים הפעילים בכל הקבוצות של הסניף שנבחר.",
                                "The message will be sent to all active trainees in all groups of the selected branch."
                            )
                    )
                    .kmiFont(size: 12, weight: .semibold)
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
                            ? Color.white
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
                            ? Color.white.opacity(0.82)
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
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private var regionPickerCard: some View {
        Menu {
            ForEach(regionOptions, id: \.self) { item in
                Button(item) {
                    region = item
                }
            }
        } label: {
            pickerCard(
                title: tr("אזור", "Region"),
                value: region.isEmpty ? tr("בחר אזור", "Choose region") : region
            )
        }
        .buttonStyle(.plain)
    }

    private var branchPickerCard: some View {
        Menu {
            ForEach(branchOptions, id: \.self) { item in
                Button(item) {
                    branch = item
                }
            }
        } label: {
            pickerCard(
                title: tr("סניף", "Branch"),
                value: branch.isEmpty ? tr("בחר סניף", "Choose branch") : branch
            )
        }
        .buttonStyle(.plain)
    }

    private var messageCard: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 8
        ) {
            Text(
                tr(
                    "טקסט ההודעה",
                    "Message text"
                )
            )
            .kmiFont(size: 14, weight: .bold)
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(
                screenTextAlignment
            )

            ZStack(
                alignment:
                    isEnglish
                    ? .topLeading
                    : .topTrailing
            ) {
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
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .kmiFont(
                        size: 15,
                        weight: .medium
                    )
                    .foregroundStyle(primaryTextColor)
                    .frame(minHeight: 112)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.clear)
                    .multilineTextAlignment(
                        screenTextAlignment
                    )
            }
            .background(fieldColor)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    accentColor.opacity(0.75),
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
    }

    private var recipientsCard: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            HStack(spacing: 10) {
                if isEnglish {
                    Text(recipientsTitleText)
                        .kmiFont(size: 14, weight: .bold)
                        .foregroundStyle(primaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .multilineTextAlignment(.leading)

                    selectAllButton

                } else {
                    selectAllButton

                    Text(recipientsTitleText)
                        .kmiFont(size: 14, weight: .bold)
                        .foregroundStyle(primaryTextColor)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .trailing
                        )
                        .multilineTextAlignment(.trailing)
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            if isLoadingRecipients {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(accentColor)
                        .controlSize(.large)

                    Text(
                        tr(
                            "טוען נמענים...",
                            "Loading recipients..."
                        )
                    )
                    .kmiFont(size: 14, weight: .bold)
                    .foregroundStyle(secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)

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
                    ForEach(recipients) { recipient in
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
        if effectiveGroupKey.isEmpty {
            return tr("נמענים בסניף: \(recipients.count)", "Recipients in branch: \(recipients.count)")
        }

        return tr("נמענים בקבוצה: \(recipients.count)", "Recipients in group: \(recipients.count)")
    }

    private var emptyRecipientsText: String {
        if effectiveGroupKey.isEmpty {
            return tr("לא נמצאו מתאמנים פעילים לסניף שנבחר.", "No active trainees were found for the selected branch.")
        }

        return tr("לא נמצאו מתאמנים פעילים לסניף ולקבוצה שנבחרו.", "No active trainees were found for the selected branch and group.")
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
                    ? Color.white
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
        .disabled(recipients.isEmpty)
        .opacity(recipients.isEmpty ? 0.45 : 1)
    }

    private func recipientRow(
        _ recipient: CoachBroadcastRecipient
    ) -> some View {
        let isSelected = recipient.selected

        let selectionBinding = Binding<Bool>(
            get: {
                recipient.selected
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
                if isEnglish {
                    recipientTexts(
                        recipient,
                        isSelected: isSelected
                    )

                    Toggle(
                        "",
                        isOn: selectionBinding
                    )
                    .labelsHidden()
                    .allowsHitTesting(false)

                } else {
                    Toggle(
                        "",
                        isOn: selectionBinding
                    )
                    .labelsHidden()
                    .allowsHitTesting(false)

                    recipientTexts(
                        recipient,
                        isSelected: isSelected
                    )
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
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
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private func recipientTexts(
        _ recipient: CoachBroadcastRecipient,
        isSelected: Bool
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 4
        ) {
            Text(recipient.name)
                .kmiFont(size: 16, weight: .bold)
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                        ? .leading
                        : .trailing
                )
                .multilineTextAlignment(
                    isEnglish
                    ? .leading
                    : .trailing
                )
                .lineLimit(2)

            Text(
                recipient.phone.isEmpty
                    ? tr(
                        "ללא מספר טלפון",
                        "No phone number"
                    )
                    : recipient.phone
            )
            .kmiFont(size: 13, weight: .medium)
            .foregroundStyle(
                isSelected
                    ? accentColor
                    : secondaryTextColor
            )
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish
                    ? .leading
                    : .trailing
            )
            .multilineTextAlignment(
                isEnglish
                    ? .leading
                    : .trailing
            )
            .lineLimit(2)
        }
        .frame(
            maxWidth: .infinity,
            alignment:
                isEnglish
                ? .leading
                : .trailing
        )
    }

    private var selectedCountCard: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 5
        ) {
            Text(
                effectiveGroupKey.isEmpty
                    ? tr(
                        "מתאמנים בסניף: \(recipients.count)",
                        "Trainees in branch: \(recipients.count)"
                    )
                    : tr(
                        "מתאמנים בקבוצה \(effectiveGroupKey): \(recipients.count)",
                        "Trainees in \(effectiveGroupKey): \(recipients.count)"
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
                if isSending {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Image(
                        systemName:
                            "paperplane.fill"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                }

                Text(
                    isSending
                        ? tr(
                            "שולח הודעה...",
                            "Sending message..."
                        )
                        : sendButtonText
                )
                .kmiFont(size: 15, weight: .heavy)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(accentColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    accentBorderColor,
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.24 : 0.12
                ),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private func pickerCard(
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                pickerTexts(
                    title: title,
                    value: value,
                    alignment: .leading,
                    textAlignment: .leading
                )

                Image(systemName: "chevron.down")
                    .font(
                        .system(
                            size: 13,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(accentColor)
                    .frame(width: 24)

            } else {
                Image(systemName: "chevron.down")
                    .font(
                        .system(
                            size: 13,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(accentColor)
                    .frame(width: 24)

                pickerTexts(
                    title: title,
                    value: value,
                    alignment: .trailing,
                    textAlignment: .trailing
                )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(14)
        .background(fieldColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                accentColor.opacity(0.75),
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

    private func pickerTexts(
        title: String,
        value: String,
        alignment: Alignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(
            alignment:
                textAlignment == .leading
                ? .leading
                : .trailing,
            spacing: 4
        ) {
            Text(title)
                .kmiFont(
                    size: 13,
                    weight: .semibold
                )
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: alignment
                )
                .multilineTextAlignment(
                    textAlignment
                )

            Text(value)
                .kmiFont(size: 18, weight: .bold)
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: alignment
                )
                .multilineTextAlignment(
                    textAlignment
                )
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(
            maxWidth: .infinity,
            alignment: alignment
        )
    }

    private func preloadDefaults() {
        if region.isEmpty {
            region = auth.userRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if branch.isEmpty {
            branch = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !branch.isEmpty {
            loadRecipients()
        }
    }

    private func loadRecipients() {
        func norm(_ value: String) -> String {
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

        func normalizedPhone(
            _ value: String
        ) -> String {
            var digits = value.filter {
                $0.isNumber
            }

            if digits.hasPrefix("00972") {
                digits = String(
                    digits.dropFirst(5)
                )

            } else if digits.hasPrefix("972") {
                digits = String(
                    digits.dropFirst(3)
                )

            } else if digits.hasPrefix("0") {
                digits = String(
                    digits.dropFirst()
                )
            }

            if digits.count >= 9 {
                digits = String(
                    digits.suffix(9)
                )
            }

            return digits
        }

        func primaryBranch(_ value: String) -> String {
            value
                .split(whereSeparator: { char in
                    char == "," || char == "•" || char == "|"
                })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func splitTokens(_ value: String) -> [String] {
            value
                .replacingOccurrences(of: " • ", with: ",")
                .replacingOccurrences(of: "|", with: ",")
                .replacingOccurrences(of: "\n", with: ",")
                .split(whereSeparator: { char in
                    char == "," || char == ";" || char == "；"
                })
                .map { norm(String($0)) }
                .filter { !$0.isEmpty }
        }

        func groupAliases(_ value: String) -> Set<String> {
            let clean = norm(value)
            var aliases = Set<String>()

            if !clean.isEmpty {
                aliases.insert(clean)
            }

            for token in splitTokens(clean) {
                aliases.insert(token)
            }

            if clean.contains("נוער") && clean.contains("בוגרים") {
                aliases.insert("נוער")
                aliases.insert("בוגרים")
                aliases.insert("נוער ובוגרים")
                aliases.insert("נוער + בוגרים")
            }

            if clean.localizedCaseInsensitiveContains("children") ||
                clean.localizedCaseInsensitiveContains("kids") {
                aliases.insert("ילדים")
            }

            if clean.localizedCaseInsensitiveContains("youth") {
                aliases.insert("נוער")
            }

            if clean.localizedCaseInsensitiveContains("adult") ||
                clean.localizedCaseInsensitiveContains("adults") {
                aliases.insert("בוגרים")
            }

            return Set(aliases.map { norm($0) }.filter { !$0.isEmpty })
        }

        func stringValue(_ data: [String: Any], _ key: String) -> String {
            (data[key] as? String) ?? ""
        }

        func stringArrayValue(_ data: [String: Any], _ key: String) -> [String] {
            (data[key] as? [String]) ?? []
        }

        func groupValues(from data: [String: Any]) -> Set<String> {
            var values = Set<String>()

            for value in stringArrayValue(data, "groups") {
                values.formUnion(groupAliases(value))
            }

            let keys = [
                "primaryGroup",
                "activeGroup",
                "active_group",
                "groupKey",
                "group_key",
                "group",
                "groupName",
                "groupsCsv",
                "groupCsv",
                "age_group"
            ]

            for key in keys {
                let rawValue = stringValue(data, key)
                let tokens = splitTokens(rawValue)

                if tokens.isEmpty, !norm(rawValue).isEmpty {
                    values.formUnion(groupAliases(rawValue))
                } else {
                    for token in tokens {
                        values.formUnion(groupAliases(token))
                    }
                }
            }

            return Set(values.map { norm($0) }.filter { !$0.isEmpty })
        }

        func hasSoftMatch(
            storedValues: Set<String>,
            candidates: Set<String>
        ) -> Bool {
            if candidates.isEmpty {
                return true
            }

            if !storedValues.isDisjoint(with: candidates) {
                return true
            }

            for stored in storedValues {
                for candidate in candidates {
                    if stored.count >= 2,
                       candidate.count >= 2,
                       stored.contains(candidate) || candidate.contains(stored) {
                        return true
                    }
                }
            }

            return false
        }

        let regionNorm = norm(region)
        let branchPrimary = primaryBranch(norm(branch))
        let groupCandidates = groupAliases(effectiveGroupKey)

        guard !regionNorm.isEmpty, !branchPrimary.isEmpty else {
            recipients = []
            return
        }

        var previousSelectionByPhone: [String: Bool] = [:]

        for recipient in recipients {
            let phoneKey = normalizedPhone(
                recipient.phone
            )

            guard !phoneKey.isEmpty else {
                continue
            }

            previousSelectionByPhone[phoneKey] =
                recipient.selected
        }

        isLoadingRecipients = true

        let branchCandidates = Set([
            branchPrimary,
            branchPrimary.replacingOccurrences(of: "-", with: "–"),
            branchPrimary.replacingOccurrences(of: "-", with: "—"),
            branchPrimary.replacingOccurrences(of: "-", with: "־"),
            branchPrimary.replacingOccurrences(of: "–", with: "-"),
            branchPrimary.replacingOccurrences(of: "—", with: "-"),
            branchPrimary.replacingOccurrences(of: "־", with: "-")
        ].map { norm($0) }.filter { !$0.isEmpty })

        let query = Firestore.firestore()
            .collection("users")
            .whereField("region", isEqualTo: regionNorm)
            .whereField("role", isEqualTo: "trainee")

        query.getDocuments { snapshot, error in
            isLoadingRecipients = false

            if let error {
                recipients = []

                showError(
                    tr(
                        "טעינת רשימת הנמענים נכשלה: \(error.localizedDescription)",
                        "Loading the recipients failed: \(error.localizedDescription)"
                    )
                )
                return
            }

            guard let docs = snapshot?.documents else {
                recipients = []

                showError(
                    tr(
                        "לא התקבלה רשימת נמענים מהשרת.",
                        "No recipient list was received from the server."
                    )
                )
                return
            }

            var uniqueByPhone:
                [String: CoachBroadcastRecipient] = [:]

            for doc in docs {
                let data = doc.data()

                let isActive = data["isActive"] as? Bool ?? true
                guard isActive else { continue }

                let branches = stringArrayValue(data, "branches").map { norm($0) }
                let branchSingle = norm(stringValue(data, "branch"))
                let activeBranch = norm(stringValue(data, "activeBranch"))
                let activeBranchSnake = norm(stringValue(data, "active_branch"))
                let branchesCsvRaw = stringValue(data, "branchesCsv")
                let branchesCsvItems = splitTokens(branchesCsvRaw)

                let branchMatches =
                    branches.contains { branchCandidates.contains($0) } ||
                    branchCandidates.contains(branchSingle) ||
                    branchCandidates.contains(activeBranch) ||
                    branchCandidates.contains(activeBranchSnake) ||
                    branchesCsvItems.contains { branchCandidates.contains($0) } ||
                    branchCandidates.contains(norm(branchesCsvRaw))

                guard branchMatches else { continue }

                let storedGroupValues = groupValues(from: data)
                let groupMatches = hasSoftMatch(
                    storedValues: storedGroupValues,
                    candidates: groupCandidates
                )

                guard groupMatches else { continue }

                let phone = (
                    stringValue(data, "phone").isEmpty
                    ? (
                        stringValue(data, "phoneNumber").isEmpty
                        ? stringValue(data, "phone_number")
                        : stringValue(data, "phoneNumber")
                    )
                    : stringValue(data, "phone")
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                let phoneKey = normalizedPhone(phone)

                guard !phoneKey.isEmpty else {
                    continue
                }

                let fullName = stringValue(
                    data,
                    "fullName"
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                let nameValue = stringValue(data, "name").trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = stringValue(data, "displayName").trimmingCharacters(in: .whitespacesAndNewlines)

                let name =
                    !fullName.isEmpty ? fullName :
                    !nameValue.isEmpty ? nameValue :
                    !displayName.isEmpty ? displayName :
                    phone

                let uidValue = stringValue(data, "uid").trimmingCharacters(in: .whitespacesAndNewlines)
                let uid = uidValue.isEmpty ? doc.documentID : uidValue

                let incomingRecipient =
                    CoachBroadcastRecipient(
                        id: uid,
                        uid: uid,
                        name: name,
                        phone: phone,
                        selected:
                            previousSelectionByPhone[phoneKey]
                            ?? true
                    )

                if let existing =
                    uniqueByPhone[phoneKey] {

                    let preferredName =
                        existing.name.count >= name.count
                        ? existing.name
                        : name

                    let preferredPhone =
                        existing.phone.count >= phone.count
                        ? existing.phone
                        : phone

                    uniqueByPhone[phoneKey] =
                        CoachBroadcastRecipient(
                            id: existing.id,
                            uid:
                                existing.uid.isEmpty
                                ? uid
                                : existing.uid,
                            name: preferredName,
                            phone: preferredPhone,
                            selected:
                                existing.selected ||
                                incomingRecipient.selected
                        )

                } else {
                    uniqueByPhone[phoneKey] =
                        incomingRecipient
                }
            }

            recipients = uniqueByPhone
                .map(\.value)
                .sorted { $0.name < $1.name }
        }
    }

    private func sendSmsToSelected() {
        guard !isSending else {
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

        isSending = true

        persistBroadcast(
            region: region,
            branch: branch,
            message: cleanMessage,
            targetUids: selectedUids,
            targetRecipients: selectedRecipients
        ) { succeeded in
            guard succeeded else {
                return
            }

            openMessagesApp(
                message: cleanMessage
            )
        }
    }

    private func openMessagesApp(
        message cleanMessage: String
    ) {
        let numbers = selectedPhones
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
                            "ההודעה נשמרה ונפתחה אפליקציית ההודעות עם \(selectedPhones.count) מתאמנים.",
                            "The message was saved and the messaging app opened with \(selectedPhones.count) trainees."
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

    private func persistBroadcast(
        region: String,
        branch: String,
        message: String,
        targetUids: [String],
        targetRecipients: [CoachBroadcastRecipient],
        completion: @escaping (Bool) -> Void
    ) {
        guard let currentUser =
            Auth.auth().currentUser else {

            isSending = false

            showError(
                tr(
                    "לא נמצא משתמש מחובר",
                    "No logged-in user was found"
                )
            )

            completion(false)
            return
        }

        let currentUid = currentUser.uid
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanTargetUids = targetUids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let recipientSnapshots: [[String: String]] = targetRecipients.map {
            [
                "uid": $0.uid,
                "name": $0.name,
                "phone": $0.phone
            ]
        }

        let targetPhones = targetRecipients
            .map(\.phone)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let targetNames = targetRecipients
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let coachName = [
            currentUser.displayName,
            currentUser.email
        ]
        .compactMap { $0 }
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .first { !$0.isEmpty }
        ?? tr("מאמן", "Coach")

        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let expiresAt = Date().addingTimeInterval(30 * 24 * 60 * 60)
        let expiresAtMillis = Int64(expiresAt.timeIntervalSince1970 * 1000)

        let docRef = Firestore.firestore()
            .collection("coachBroadcasts")
            .document()

        let broadcastId = docRef.documentID

        let data: [String: Any] = [
            "broadcastId": broadcastId,
            "type": "coach_broadcast",

            "authorUid": currentUid,
            "coachUid": currentUid,
            "coachName": coachName,

            "region": cleanRegion,
            "branch": cleanBranch,

            "text": cleanMessage,
            "message": cleanMessage,
            "body": cleanMessage,

            "targetUids": cleanTargetUids,
            "targetUidCount": cleanTargetUids.count,
            "targetCount": cleanTargetUids.count,

            "targetRecipients": recipientSnapshots,
            "targetPhones": targetPhones,
            "targetNames": targetNames,
            "targetRecipientSnapshotCount": recipientSnapshots.count,

            "pushEnabled": true,
            "pushTarget": "targetUids",
            "pushStatus": "pending",
            "pushCreatedBy": "ios_coach_broadcast",

            "createdAt": FieldValue.serverTimestamp(),
            "createdAtMillis": nowMillis,
            "sentAtMillis": nowMillis,

            "expiresAt": Timestamp(date: expiresAt),
            "expiresAtMillis": expiresAtMillis,

            "source": "ios_coach_broadcast"
        ]

        docRef.setData(
            data,
            merge: true
        ) { error in
            DispatchQueue.main.async {
                if let error {
                    isSending = false

                    showError(
                        tr(
                            "שמירת ההודעה נכשלה: \(error.localizedDescription)",
                            "Saving the message failed: \(error.localizedDescription)"
                        )
                    )

                    completion(false)

                } else {
                    completion(true)
                }
            }
        }
    }

    private func showError(_ text: String) {
        alertText = text
        showAlert = true
    }
}

private struct CoachBroadcastRecipient: Identifiable {
    let id: String
    let uid: String
    let name: String
    let phone: String
    var selected: Bool
}
