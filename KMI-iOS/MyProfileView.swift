import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import Shared

private extension String {
    func ifBlankDash() -> String {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "—" : clean
    }
}

private struct MyProfileBranchEntry: Identifiable {
    let id = UUID()
    let branch: String
    let address: String
    let group: String
    let coach: String
}

private struct MyProfileFirestoreInfo {
    var fullName: String = ""
    var email: String = ""
    var phone: String = ""
    var username: String = ""
    var region: String = ""
    var branch: String = ""
    var branchAddress: String = ""
    var group: String = ""
    var belt: String = ""
    var role: String = ""
    var coach: String = ""
    var nextTraining: String = ""
}

struct MyProfileView: View {

    // MARK: - Stored user data

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    @AppStorage("fullName") private var fullName: String = ""
    @AppStorage("email") private var email: String = ""
    @AppStorage("phone") private var phone: String = ""
    @AppStorage("username") private var username: String = ""
    @AppStorage("region") private var region: String = ""
    @AppStorage("branch") private var branch: String = ""
    @AppStorage("activeBranch") private var activeBranch: String = ""
    @AppStorage("active_branch") private var activeBranchSnake: String = ""
    @AppStorage("group") private var group: String = ""
    @AppStorage("activeGroup") private var activeGroup: String = ""
    @AppStorage("active_group") private var activeGroupSnake: String = ""
    @AppStorage("groupKey") private var groupKey: String = ""
    @AppStorage("age_group") private var ageGroup: String = ""
    @AppStorage("current_belt") private var currentBelt: String = ""
    @AppStorage("belt_current") private var beltCurrent: String = ""
    @AppStorage("belt") private var belt: String = ""
    @AppStorage("password") private var savedPassword: String = ""

    @AppStorage("coach") private var coach: String = ""
    @AppStorage("coachName") private var coachName: String = ""
    @AppStorage("headCoach") private var headCoach: String = ""
    @AppStorage("next_training") private var nextTraining: String = ""

    @AppStorage("branchAddress") private var branchAddress: String = ""
    @AppStorage("branch_address") private var branchAddressSnake: String = ""
    @AppStorage("address") private var address: String = ""

    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject
    private var demoPrivacy = DemoPrivacy.shared

    @State private var firestoreInfo = MyProfileFirestoreInfo()

    @State private var isLoadingFirestoreProfile: Bool = false

    @State private var passwordVisible: Bool = false

    @State private var showProfileShareSheet = false

    @State private var profileShareItems: [Any] = []

    @State private var profileShareErrorMessage: String?

    private var profilePrimaryTextColor: Color {
        KmiAppTheme.onSurface(
            for: colorScheme
        )
    }

    private var profileSecondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(
            for: colorScheme
        )
    }

    private var profileAccentTextColor: Color {
        KmiAppTheme.secondary(
            for: colorScheme
        )
    }

    private var profileCardColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
        .opacity(0.96)
    }

    private var profileCardBorderColor: Color {
        KmiAppTheme.outlineVariant(
            for: colorScheme
        )
    }

    private var effectiveLanguageCode: String {
        let orderedValues = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]

        for raw in orderedValues {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }

            if clean == "en" || clean == "english" {
                return "en"
            }
        }

        return "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var profileTextAlignment: TextAlignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var profileFrameAlignment: Alignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private var profileStackAlignment: HorizontalAlignment {
        isEnglish
            ? .leading
            : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func firstNonEmpty(_ values: String...) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private func profileBranchList(from raw: String) -> [String] {
        raw
            .components(separatedBy: CharacterSet(charactersIn: "\n|;,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "—" }
            .reduce(into: [String]()) { result, branch in
                if !result.contains(branch) {
                    result.append(branch)
                }
            }
    }
    
    private var resolvedFullName: String {
        firstNonEmpty(
            firestoreInfo.fullName,
            fullName,
            Auth.auth().currentUser?.displayName ?? "",
            username,
            Auth.auth().currentUser?.email ?? ""
        )
    }

    private var resolvedEmail: String {
        firstNonEmpty(
            firestoreInfo.email,
            email,
            Auth.auth().currentUser?.email ?? ""
        )
    }

    private var resolvedPhone: String {
        firstNonEmpty(
            firestoreInfo.phone,
            phone
        )
    }

    private var resolvedUsername: String {
        firstNonEmpty(
            firestoreInfo.username,
            username,
            Auth.auth().currentUser?.email ?? ""
        )
    }

    private var resolvedRegion: String {
        firstNonEmpty(
            firestoreInfo.region,
            region
        )
    }

    private var resolvedBranch: String {
        firstNonEmpty(
            firestoreInfo.branch,
            activeBranch,
            activeBranchSnake,
            branch
        )
    }

    private var resolvedGroup: String {
        firstNonEmpty(
            firestoreInfo.group,
            activeGroup,
            activeGroupSnake,
            groupKey,
            ageGroup,
            group
        )
    }

    private var resolvedBeltId: String {
        firstNonEmpty(
            firestoreInfo.belt,
            currentBelt,
            beltCurrent,
            belt
        )
    }

    private var resolvedPassword: String {
        firstNonEmpty(savedPassword, "••••••••")
    }

    private var displayedUserName: String {
        _ = demoPrivacy.isEnabled

        let mappedName =
            TraineeDisplayNameMapper.displayName(
                realName: resolvedFullName,
                stableKey:
                    Auth.auth().currentUser?.uid
                    ?? resolvedUsername,
                demoIndex: 0,
                isEnglish: isEnglish
            )

        return mappedName.isEmpty
            ? tr(
                "משתמש ללא שם",
                "Unnamed user"
            )
            : mappedName
    }

    private var displayedBranch: String {
        let branches = profileBranchList(from: resolvedBranch)

        guard !branches.isEmpty else {
            return "—"
        }

        return branches.joined(separator: "\n")
    }

    private var branchAddressEntries: [MyProfileBranchEntry] {
        let branches = profileBranchList(from: resolvedBranch)

        guard !branches.isEmpty else {
            return []
        }

        let explicitAddress = firstNonEmpty(
            firestoreInfo.branchAddress,
            branchAddress,
            branchAddressSnake,
            address
        )

        let explicitAddresses = profileBranchList(from: explicitAddress)

        return branches.enumerated().map { index, branchValue in
            let explicitForBranch = explicitAddresses.indices.contains(index) ? explicitAddresses[index] : ""

            let resolvedAddress = firstNonEmpty(
                explicitForBranch,
                branchAddressFallback(for: branchValue)
            )
            .ifBlankDash()

            return MyProfileBranchEntry(
                branch: branchValue,
                address: resolvedAddress,
                group: displayedGroup,
                coach: displayedCoach
            )
        }
    }

    private var displayedGroup: String {
        resolvedGroup.isEmpty ? "—" : resolvedGroup
    }

    private var displayedEmail: String {
        resolvedEmail.isEmpty ? "—" : resolvedEmail
    }

    private var displayedPhone: String {
        resolvedPhone.isEmpty ? "—" : resolvedPhone
    }

    private var displayedUsername: String {
        resolvedUsername.isEmpty ? "—" : resolvedUsername
    }

    private var displayedBelt: String {
        beltDisplayNameForUi(resolvedBeltId)
    }

    private var resolvedNextBeltId: String {
        nextBeltIdForUi(resolvedBeltId)
    }

    private var displayedNextBelt: String {
        nextBeltDisplayNameForUi(resolvedBeltId)
    }

    private var displayedCoach: String {
        firstNonEmpty(
            firestoreInfo.coach,
            coachName,
            coach,
            nextTrainingCoachFromCatalog()
        )
        .ifBlankDash()
    }

    private var displayedNextTraining: String {
        firstNonEmpty(
            firestoreInfo.nextTraining,
            nextTraining,
            nextTrainingTextFromCatalog()
        )
        .ifBlankDash()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                profileBackground

                ScrollView(
                    .vertical,
                    showsIndicators: false
                ) {
                    VStack(spacing: 14) {
                        profileGlassCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(
                        .bottom,
                        max(
                            34,
                            geo.safeAreaInsets.bottom + 24
                        )
                    )
                }

                if isLoadingFirestoreProfile {
                    KmiLoadingOverlay()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
        .toolbar(
            .hidden,
            for: .navigationBar
        )
        .onAppear {
            loadFirestoreProfileIfNeeded()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in
            guard
                let request =
                    notification.object
                    as? NSMutableDictionary
            else {
                return
            }

            request["handled"] = true
            shareProfilePDF()
        }
        .sheet(
            isPresented: $showProfileShareSheet,
            onDismiss: {
                profileShareItems.removeAll()
            }
        ) {
            KmiShareSheet(
                items: profileShareItems
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(.visible)
        }
        .alert(
            tr(
                "לא ניתן לשתף",
                "Unable to Share"
            ),
            isPresented: Binding(
                get: {
                    profileShareErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        profileShareErrorMessage = nil
                    }
                }
            )
        ) {
            Button(
                tr("אישור", "OK"),
                role: .cancel
            ) {
                profileShareErrorMessage = nil
            }
        } message: {
            Text(
                profileShareErrorMessage ?? ""
            )
        }
    }

    // MARK: - Background

    private var profileBackground: some View {
        LinearGradient(
            colors:
                KmiAppTheme.screenBackgroundColors(
                    for: colorScheme
                ),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Main card

    private var profileGlassCard: some View {
        VStack(alignment: profileStackAlignment, spacing: 0) {
            headerSection

            Spacer().frame(height: 12)

            editProfileButton

            Spacer().frame(height: 14)

            profileInfoSections

            Spacer().frame(height: 10)

            trainingTowardBeltCard
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(profileCardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    profileCardBorderColor,
                    lineWidth: 1
                )
        )
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 8) {
            if isEnglish {
                profileBeltImage
                    .frame(width: 118, height: 76)
                    .padding(.top, -12)

                headerTextBlock(
                    alignment: .leading,
                    frameAlignment: .leading,
                    textAlignment: .leading
                )
            } else {
                headerTextBlock(
                    alignment: .trailing,
                    frameAlignment: .trailing,
                    textAlignment: .trailing
                )

                profileBeltImage
                    .frame(width: 104, height: 82)
                    .padding(.top, -10)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func headerTextBlock(
        alignment: HorizontalAlignment,
        frameAlignment: Alignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(displayedUserName)
                .kmiFont(size: 24, weight: .heavy)
                .foregroundStyle(profilePrimaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(displayedBelt)
                .kmiFont(size: 15, weight: .semibold)
                .foregroundStyle(profileAccentTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
    }

    private var profileBeltImage: some View {
        Image(
            profileBeltImageName(
                for: resolvedBeltId
            )
        )
        .resizable()
        .scaledToFit()
        .rotationEffect(.degrees(-24))
        .accessibilityHidden(true)
    }

    private var editProfileButton: some View {
        Button {
            AppNavModel.sharedInstance?
                .push(.editProfile)
        } label: {
            Text(
                tr(
                    "עריכת פרופיל",
                    "Edit profile"
                )
            )
            .kmiFont(
                size: 16,
                weight: .heavy
            )
            .foregroundStyle(
                KmiAppTheme.sectionHeaderContentColor
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(
                    KmiAppTheme.graniteActionBrush
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "עריכת פרופיל",
                "Edit profile"
            )
        )
    }

    private var profileInfoSections: some View {
        VStack(spacing: 0) {
            branchAddressListBlock(
                label: tr("סניפים וכתובות:", "Branches and addresses:"),
                entries: branchAddressEntries
            )

            labeledValueBlock(
                label: tr("אימון הבא:", "Next training:"),
                value: displayedNextTraining
            )

            labeledValueBlock(
                label: tr("מייל:", "Email:"),
                value: displayedEmail
            )

            labeledValueBlock(
                label: tr("טלפון:", "Phone:"),
                value: displayedPhone
            )

            labeledValueBlock(
                label: tr("שם משתמש:", "Username:"),
                value: displayedUsername
            )

            passwordRow(
                label: tr("סיסמה", "Password"),
                password: resolvedPassword
            )
        }
    }

    private func labeledValueBlock(
        label: String,
        value: String
    ) -> some View {
        VStack(
            alignment: profileStackAlignment,
            spacing: 3
        ) {
            Text(label)
                .kmiFont(size: 13, weight: .medium)
                .foregroundStyle(profileSecondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: profileFrameAlignment
                )
                .multilineTextAlignment(profileTextAlignment)

            Text(
                value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
                    ? "—"
                    : value
            )
            .kmiFont(
                size: 15,
                weight: .heavy
            )
            .foregroundStyle(profilePrimaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: profileFrameAlignment
            )
            .multilineTextAlignment(
                profileTextAlignment
            )
            .lineLimit(4)
            .minimumScaleFactor(0.72)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Spacer()
                .frame(height: 5)

            Rectangle()
                .fill(profileCardBorderColor)
                .frame(height: 1)
        }
        .frame(
            maxWidth: .infinity,
            alignment: profileFrameAlignment
        )
        .padding(.vertical, 5)
    }

    private func branchAddressListBlock(
        label: String,
        entries: [MyProfileBranchEntry]
    ) -> some View {
        VStack(alignment: profileStackAlignment, spacing: 8) {
            Text(label)
                .kmiFont(size: 13, weight: .medium)
                .foregroundStyle(profileSecondaryTextColor)
                .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                .multilineTextAlignment(profileTextAlignment)

            if entries.isEmpty {
                Text("—")
                    .kmiFont(size: 15, weight: .bold)
                    .foregroundStyle(profilePrimaryTextColor)
                    .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                    .multilineTextAlignment(profileTextAlignment)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: profileStackAlignment, spacing: 4) {
                        Text(entry.branch.ifBlankDash())
                            .kmiFont(size: 15, weight: .heavy)
                            .foregroundStyle(profileAccentTextColor)
                            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                            .multilineTextAlignment(profileTextAlignment)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(
                            entry.address.ifBlankDash()
                        )
                        .kmiFont(
                            size: 14,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            profileSecondaryTextColor
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: profileFrameAlignment
                        )
                        .multilineTextAlignment(
                            profileTextAlignment
                        )

                        Spacer()
                            .frame(height: 4)

                        Text(tr("קבוצה:", "Group:"))
                            .kmiFont(size: 13, weight: .medium)
                            .foregroundStyle(profileSecondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                            .multilineTextAlignment(profileTextAlignment)

                        Text(entry.group.ifBlankDash())
                            .kmiFont(size: 14, weight: .heavy)
                            .foregroundStyle(profilePrimaryTextColor)
                            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                            .multilineTextAlignment(profileTextAlignment)

                        Spacer()
                            .frame(height: 2)

                        Text(tr("מאמן:", "Coach:"))
                            .kmiFont(size: 13, weight: .medium)
                            .foregroundStyle(profileSecondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                            .multilineTextAlignment(profileTextAlignment)

                        Text(entry.coach.ifBlankDash())
                            .kmiFont(size: 14, weight: .heavy)
                            .foregroundStyle(profilePrimaryTextColor)
                            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                            .multilineTextAlignment(profileTextAlignment)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .fill(
                            index.isMultiple(of: 2)
                                ? KmiAppTheme.surfaceVariant(
                                    for: colorScheme
                                )
                                : KmiAppTheme.surface(
                                    for: colorScheme
                                )
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                        .stroke(
                            profileCardBorderColor,
                            lineWidth: 1
                        )
                    )
                    .padding(
                        .bottom,
                        index == entries.count - 1 ? 0 : 8
                    )
                }
            }

            Rectangle()
                .fill(profileCardBorderColor)
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    private func passwordRow(
        label: String,
        password: String
    ) -> some View {
        VStack(
            alignment: profileStackAlignment,
            spacing: 5
        ) {
            Text(label)
                .kmiFont(size: 13, weight: .medium)
                .foregroundStyle(profileSecondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: profileFrameAlignment
                )
                .multilineTextAlignment(profileTextAlignment)

            HStack(spacing: 8) {
                if isEnglish {
                    Button {
                        passwordVisible.toggle()
                    } label: {
                        passwordVisibilityIcon
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        passwordVisible
                            ? tr(
                                "הסתרת סיסמה",
                                "Hide password"
                            )
                            : tr(
                                "הצגת סיסמה",
                                "Show password"
                            )
                    )

                    Text(
                        passwordVisible
                            ? password
                            : "••••••••"
                    )
                        .kmiFont(size: 15, weight: .heavy)
                        .foregroundStyle(profilePrimaryTextColor)

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    Text(
                        passwordVisible
                            ? password
                            : "••••••••"
                    )
                    .kmiFont(
                        size: 15,
                        weight: .heavy
                    )
                    .foregroundStyle(
                        profilePrimaryTextColor
                    )

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        passwordVisibilityIcon
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        passwordVisible
                            ? tr(
                                "הסתרת סיסמה",
                                "Hide password"
                            )
                            : tr(
                                "הצגת סיסמה",
                                "Show password"
                            )
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .accessibilityElement(
                children: .combine
            )
            .accessibilityValue(
                passwordVisible
                    ? password
                    : tr(
                        "הסיסמה מוסתרת",
                        "Password hidden"
                    )
            )

            Rectangle()
                .fill(profileCardBorderColor)
                .frame(height: 1)
        }
        .frame(
            maxWidth: .infinity,
            alignment: profileFrameAlignment
        )
        .padding(.vertical, 5)
    }

    private var passwordVisibilityIcon: some View {
        Image(
            systemName:
                passwordVisible
                    ? "eye.slash"
                    : "eye"
        )
        .kmiFont(
            size: 18,
            weight: .bold
        )
        .foregroundStyle(profileAccentTextColor)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .accessibilityLabel(
            passwordVisible
                ? tr(
                    "הסתרת סיסמה",
                    "Hide password"
                )
                : tr(
                    "הצגת סיסמה",
                    "Show password"
                )
        )
    }

    private var trainingTowardBeltCard: some View {
        VStack(
            alignment: profileStackAlignment,
            spacing: 7
        ) {
            Text(
                tr(
                    "מתאמן לחגורה",
                    "Training toward belt"
                )
            )
            .kmiFont(
                size: 13,
                weight: .bold
            )
            .foregroundStyle(
                profileSecondaryTextColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: profileFrameAlignment
            )
            .multilineTextAlignment(
                profileTextAlignment
            )
            .lineLimit(1)

            HStack(spacing: 10) {
                if isEnglish {
                    Image(
                        profileBeltImageName(
                            for: resolvedNextBeltId
                        )
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 38)
                    .rotationEffect(.degrees(-5))
                    .accessibilityHidden(true)

                    Text(displayedNextBelt)
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            profileAccentTextColor
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    Text(displayedNextBelt)
                        .kmiFont(
                            size: 18,
                            weight: .heavy
                        )
                        .foregroundStyle(
                            profileAccentTextColor
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Image(
                        profileBeltImageName(
                            for: resolvedNextBeltId
                        )
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 38)
                    .rotationEffect(.degrees(5))
                    .accessibilityHidden(true)
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surfaceVariant(
                    for: colorScheme
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                profileCardBorderColor,
                lineWidth: 1
            )
        )
    }
    
    // MARK: - PDF and Share

    @MainActor
    private func shareProfilePDF() {
        guard !showProfileShareSheet else {
            return
        }

        guard !isLoadingFirestoreProfile else {
            profileShareErrorMessage =
                tr(
                    "יש להמתין לסיום טעינת הפרופיל.",
                    "Please wait for the profile to finish loading."
                )
            return
        }

        guard let pdfURL = createProfilePDF() else {
            profileShareErrorMessage =
                tr(
                    "יצירת קובץ הפרופיל נכשלה.",
                    "The profile PDF could not be created."
                )
            return
        }

        profileShareItems = [pdfURL]
        showProfileShareSheet = true
    }

    @MainActor
    private func createProfilePDF() -> URL? {
        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let fileName =
            isEnglish
                ? "KMI_My_Profile.pdf"
                : "KMI_הפרופיל_שלי.pdf"

        let fileURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    fileName,
                    isDirectory: false
                )

        let branchDetails =
            branchAddressEntries
                .map { entry in
                    [
                        entry.branch.ifBlankDash(),
                        entry.address.ifBlankDash()
                    ]
                    .joined(separator: " — ")
                }
                .joined(separator: "\n")
                .ifBlankDash()

        let profileRows: [(String, String)] = [
            (
                tr("שם", "Name"),
                displayedUserName
            ),
            (
                tr("חגורה נוכחית", "Current belt"),
                displayedBelt
            ),
            (
                tr("סניפים וכתובות", "Branches and addresses"),
                branchDetails
            ),
            (
                tr("קבוצה", "Group"),
                displayedGroup
            ),
            (
                tr("מאמן", "Coach"),
                displayedCoach
            ),
            (
                tr("אימון הבא", "Next training"),
                displayedNextTraining
            ),
            (
                tr("מתאמן לחגורה", "Training toward belt"),
                displayedNextBelt
            ),
            (
                tr("מייל", "Email"),
                displayedEmail
            ),
            (
                tr("טלפון", "Phone"),
                displayedPhone
            ),
            (
                tr("שם משתמש", "Username"),
                displayedUsername
            ),
            (
                tr("סיסמה", "Password"),
                resolvedPassword
            )
        ]

        let renderer =
            UIGraphicsPDFRenderer(
                bounds: pageRect
            )

        let pdfData =
            renderer.pdfData { context in
                MainActor.assumeIsolated {
                    let cg = context.cgContext
                    let pageWidth = pageRect.width
                    let horizontalMargin: CGFloat = 34
                    let contentWidth =
                        pageWidth -
                        horizontalMargin * 2
                    let contentBottom =
                        pageRect.height -
                        KmiPdfFooter
                            .CONTENT_BOTTOM_PADDING

                    let textAlignment:
                        NSTextAlignment =
                            isEnglish
                                ? .left
                                : .right

                    let writingDirection:                        NSWritingDirection =
                            isEnglish
                                ? .leftToRight
                                : .rightToLeft

                    var pageNumber = 0
                    var currentY =
                        KmiPdfHeader.CONTENT_TOP

                    func paragraphStyle(
                        alignment: NSTextAlignment
                    ) -> NSMutableParagraphStyle {
                        let style =
                            NSMutableParagraphStyle()

                        style.alignment = alignment
                        style.baseWritingDirection =
                            writingDirection
                        style.lineBreakMode =
                            .byWordWrapping

                        return style
                    }

                    func drawFooter() {
                        KmiPdfFooter.draw(
                            context: cg,
                            pageWidth: pageRect.width,
                            pageHeight: pageRect.height,
                            pageNumber: pageNumber,
                            isEnglish: isEnglish
                        )
                    }

                    func beginPage() {
                        context.beginPage()
                        pageNumber += 1

                        KmiPdfHeader.draw(
                            context: cg,
                            pageWidth: pageRect.width,
                            isEnglish: isEnglish,
                            titleHebrew: "הפרופיל שלי",
                            titleEnglish: "My Profile",
                            subtitleHebrew: displayedUserName,
                            subtitleEnglish: displayedUserName
                        )

                        currentY =
                            KmiPdfHeader.CONTENT_TOP
                    }

                    func textHeight(
                        _ text: String,
                        width: CGFloat,
                        font: UIFont
                    ) -> CGFloat {
                        let attributes:
                            [NSAttributedString.Key: Any] = [
                                .font: font,
                                .paragraphStyle:
                                    paragraphStyle(
                                        alignment:
                                            textAlignment
                                    )
                            ]

                        return ceil(
                            NSString(string: text)
                                .boundingRect(
                                    with: CGSize(
                                        width: width,
                                        height:
                                            CGFloat
                                                .greatestFiniteMagnitude
                                    ),
                                    options: [
                                        .usesLineFragmentOrigin,
                                        .usesFontLeading
                                    ],
                                    attributes: attributes,
                                    context: nil
                                )
                                .height
                        )
                    }

                    func drawText(
                        _ text: String,
                        rect: CGRect,
                        font: UIFont,
                        color: UIColor
                    ) {
                        let attributes:
                            [NSAttributedString.Key: Any] = [
                                .font: font,
                                .foregroundColor: color,
                                .paragraphStyle:
                                    paragraphStyle(
                                        alignment:
                                            textAlignment
                                    )
                            ]

                        NSString(string: text)
                            .draw(
                                with: rect,
                                options: [
                                    .usesLineFragmentOrigin,
                                    .usesFontLeading
                                ],
                                attributes: attributes,
                                context: nil
                            )
                    }

                    beginPage()

                    for row in profileRows {
                        let labelFont =
                            UIFont.systemFont(
                                ofSize: 11,
                                weight: .semibold
                            )

                        let valueFont =
                            UIFont.systemFont(
                                ofSize: 14,
                                weight: .bold
                            )

                        let labelHeight =
                            textHeight(
                                row.0,
                                width: contentWidth,
                                font: labelFont
                            )

                        let value =
                            row.1
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )
                                .ifBlankDash()

                        let valueHeight =
                            max(
                                18,
                                textHeight(
                                    value,
                                    width: contentWidth,
                                    font: valueFont
                                )
                            )

                        let rowHeight =
                            labelHeight +
                            valueHeight +
                            22

                        if currentY + rowHeight >
                            contentBottom {
                            drawFooter()
                            beginPage()
                        }

                        drawText(
                            row.0,
                            rect: CGRect(
                                x: horizontalMargin,
                                y: currentY,
                                width: contentWidth,
                                height: labelHeight + 4
                            ),
                            font: labelFont,
                            color: UIColor(
                                red: 0.30,
                                green: 0.35,
                                blue: 0.42,
                                alpha: 1
                            )
                        )

                        currentY += labelHeight + 5

                        drawText(
                            value,
                            rect: CGRect(
                                x: horizontalMargin,
                                y: currentY,
                                width: contentWidth,
                                height: valueHeight + 4
                            ),
                            font: valueFont,
                            color: UIColor(
                                red: 0.09,
                                green: 0.13,
                                blue: 0.20,
                                alpha: 1
                            )
                        )

                        currentY += valueHeight + 8

                        cg.setStrokeColor(
                            UIColor(
                                red: 0.82,
                                green: 0.86,
                                blue: 0.90,
                                alpha: 1
                            )
                            .cgColor
                        )
                        cg.setLineWidth(0.7)
                        cg.move(
                            to: CGPoint(
                                x: horizontalMargin,
                                y: currentY
                            )
                        )
                        cg.addLine(
                            to: CGPoint(
                                x:
                                    horizontalMargin +
                                    contentWidth,
                                y: currentY
                            )
                        )
                        cg.strokePath()

                        currentY += 9
                    }

                    drawFooter()
                }
            }

        do {
            try pdfData.write(
                to: fileURL,
                options: .atomic
            )
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Firestore

    private func loadFirestoreProfileIfNeeded() {
    guard
        let uid = Auth.auth().currentUser?.uid,
        !uid.isEmpty
    else {
        return
    }

        guard !isLoadingFirestoreProfile else {
            return
        }

        isLoadingFirestoreProfile = true

        Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    defer {
                        isLoadingFirestoreProfile = false
                    }

                    guard
                        let data = snapshot?.data(),
                        snapshot?.exists == true
                    else {
                        return
                    }

                    let loaded = MyProfileFirestoreInfo(
                        fullName: firstFirestoreString(
                            data,
                            keys: [
                                "fullName",
                                "name",
                                "displayName"
                            ]
                        ),
                        email: firstFirestoreString(
                            data,
                            keys: [
                                "email"
                            ]
                        ),
                        phone: firstFirestoreString(
                            data,
                            keys: [
                                "phone",
                                "phoneNumber",
                                "phone_number"
                            ]
                        ),
                        username: firstFirestoreString(
                            data,
                            keys: [
                                "username",
                                "userName",
                                "accountUserName"
                            ]
                        ),
                        region: firstFirestoreString(
                            data,
                            keys: [
                                "region",
                                "activeRegion",
                                "active_region"
                            ]
                        ),
                        branch: firstFirestoreString(
                            data,
                            keys: [
                                "branches",
                                "branchesCsv",
                                "selectedBranches",
                                "selected_branches",
                                "branch",
                                "activeBranch",
                                "active_branch"
                            ]
                        ),
                        branchAddress: firstFirestoreString(
                            data,
                            keys: [
                                "branchAddress",
                                "branch_address",
                                "address",
                                "branchLocation",
                                "branch_location"
                            ]
                        ),
                        group: firstFirestoreString(
                            data,
                            keys: [
                                "groups",
                                "groupsCsv",
                                "selectedGroups",
                                "selected_groups",
                                "ageGroups",
                                "age_groups",
                                "group",
                                "primaryGroup",
                                "groupKey",
                                "group_key",
                                "age_group",
                                "activeGroup",
                                "active_group"
                            ]
                        ),
                        belt: firstFirestoreString(
                            data,
                            keys: [
                                "current_belt",
                                "belt_current",
                                "belt",
                                "rank"
                            ]
                        ),
                        role: firstFirestoreString(
                            data,
                            keys: [
                                "role",
                                "user_role",
                                "userType",
                                "type"
                            ]
                        ),
                        coach: firstFirestoreString(
                            data,
                            keys: [
                                "coach",
                                "coachName",
                                "coach_name",
                                "trainer",
                                "trainerName",
                                "instructor"
                            ]
                        ),
                        nextTraining: firstFirestoreString(
                            data,
                            keys: [
                                "nextTraining",
                                "next_training",
                                "upcomingTraining",
                                "upcoming_training"
                            ]
                        )
                    )

                    firestoreInfo = loaded
                    syncLoadedProfileToDefaults(loaded)
                }
            }
    }

    private func firstFirestoreString(
        _ data: [String: Any],
        keys: [String]
    ) -> String {
        for key in keys {
            let raw = data[key]

            if let value = raw as? String {
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    return clean
                }
            }

            if let values = raw as? [Any] {
                let joined = values
                    .map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")

                if !joined.isEmpty {
                    return joined
                }
            }
        }

        return ""
    }

    private func syncLoadedProfileToDefaults(_ info: MyProfileFirestoreInfo) {
        let defaults = UserDefaults.standard

        if !info.fullName.isEmpty {
            defaults.set(info.fullName, forKey: "fullName")
        }

        if !info.email.isEmpty {
            defaults.set(info.email, forKey: "email")
        }

        if !info.phone.isEmpty {
            defaults.set(info.phone, forKey: "phone")
        }

        if !info.username.isEmpty {
            defaults.set(info.username, forKey: "username")
        }

        if !info.region.isEmpty {
            defaults.set(info.region, forKey: "region")
        }

        if !info.branch.isEmpty {
            defaults.set(info.branch, forKey: "branch")
            defaults.set(info.branch, forKey: "activeBranch")
            defaults.set(info.branch, forKey: "active_branch")
        }

        if !info.branchAddress.isEmpty {
            defaults.set(info.branchAddress, forKey: "branchAddress")
            defaults.set(info.branchAddress, forKey: "branch_address")
            defaults.set(info.branchAddress, forKey: "address")
        }

        if !info.group.isEmpty {
            defaults.set(info.group, forKey: "group")
            defaults.set(info.group, forKey: "activeGroup")
            defaults.set(info.group, forKey: "active_group")
            defaults.set(info.group, forKey: "groupKey")
            defaults.set(info.group, forKey: "age_group")
        }

        if !info.belt.isEmpty {
            defaults.set(info.belt, forKey: "belt")
            defaults.set(info.belt, forKey: "current_belt")
            defaults.set(info.belt, forKey: "belt_current")
        }

        if !info.role.isEmpty {
            defaults.set(info.role, forKey: "user_role")
        }

        if !info.coach.isEmpty {
            defaults.set(info.coach, forKey: "coach")
            defaults.set(info.coach, forKey: "coachName")
        }

        if !info.nextTraining.isEmpty {
            defaults.set(info.nextTraining, forKey: "next_training")
        }
    }

    // MARK: - Belt helpers

    private func profileBeltImageName(for raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch clean {
        case "white", "לבנה":
            return "belt_white"
        case "yellow", "צהובה":
            return "belt_yellow"
        case "orange", "כתומה":
            return "belt_orange"
        case "green", "ירוקה":
            return "belt_green"
        case "blue", "כחולה":
            return "belt_blue"
        case "brown", "חומה":
            return "belt_brown"
        case "black",
             "שחורה",
             "שחורה דאן 1",
             "שחורה דאן 2",
             "שחורה דאן 3",
             "שחורה דאן 4",
             "שחורה דאן 5",
             "שחורה דאן 6",
             "שחורה דאן 7",
             "שחורה דאן 8",
             "שחורה דאן 9",
             "שחורה דאן 10",
             "black_dan_2",
             "black_dan_3",
             "black_dan_4",
             "black_dan_5",
             "black_dan_6",
             "black_dan_7",
             "black_dan_8",
             "black_dan_9",
             "black_dan_10":
            return "belt_black"
        default:
            return "belt_orange"
        }
    }
    
    private func beltDisplayNameForUi(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if isEnglish {
            switch clean {
            case "white", "לבנה":
                return "White"
            case "yellow", "צהובה":
                return "Yellow"
            case "orange", "כתומה":
                return "Orange"
            case "green", "ירוקה":
                return "Green"
            case "blue", "כחולה":
                return "Blue"
            case "brown", "חומה":
                return "Brown"
            case "black", "שחורה", "שחורה דאן 1":
                return "Black Dan 1"
            case "black_dan_2", "שחורה דאן 2":
                return "Black Dan 2"
            case "black_dan_3", "שחורה דאן 3":
                return "Black Dan 3"
            case "black_dan_4", "שחורה דאן 4":
                return "Black Dan 4"
            case "black_dan_5", "שחורה דאן 5":
                return "Black Dan 5"
            case "black_dan_6", "שחורה דאן 6":
                return "Black Dan 6"
            case "black_dan_7", "שחורה דאן 7":
                return "Black Dan 7"
            case "black_dan_8", "שחורה דאן 8":
                return "Black Dan 8"
            case "black_dan_9", "שחורה דאן 9":
                return "Black Dan 9"
            case "black_dan_10", "שחורה דאן 10":
                return "Black Dan 10"
            default:
                return raw.isEmpty ? "Not set" : raw
            }
        } else {
            switch clean {
            case "white", "לבנה":
                return "לבנה"
            case "yellow", "צהובה":
                return "צהובה"
            case "orange", "כתומה":
                return "כתומה"
            case "green", "ירוקה":
                return "ירוקה"
            case "blue", "כחולה":
                return "כחולה"
            case "brown", "חומה":
                return "חומה"
            case "black", "שחורה", "שחורה דאן 1":
                return "שחורה דאן 1"
            case "black_dan_2", "שחורה דאן 2":
                return "שחורה דאן 2"
            case "black_dan_3", "שחורה דאן 3":
                return "שחורה דאן 3"
            case "black_dan_4", "שחורה דאן 4":
                return "שחורה דאן 4"
            case "black_dan_5", "שחורה דאן 5":
                return "שחורה דאן 5"
            case "black_dan_6", "שחורה דאן 6":
                return "שחורה דאן 6"
            case "black_dan_7", "שחורה דאן 7":
                return "שחורה דאן 7"
            case "black_dan_8", "שחורה דאן 8":
                return "שחורה דאן 8"
            case "black_dan_9", "שחורה דאן 9":
                return "שחורה דאן 9"
            case "black_dan_10", "שחורה דאן 10":
                return "שחורה דאן 10"
            default:
                return raw.isEmpty ? "לא הוגדר" : raw
            }
        }
    }

    private func nextBeltIdForUi(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch clean {
        case "white", "לבנה":
            return "yellow"
        case "yellow", "צהובה":
            return "orange"
        case "orange", "כתומה":
            return "green"
        case "green", "ירוקה":
            return "blue"
        case "blue", "כחולה":
            return "brown"
        case "brown", "חומה":
            return "black"
        case "black", "שחורה", "שחורה דאן 1":
            return "black_dan_2"
        case "black_dan_2", "שחורה דאן 2":
            return "black_dan_3"
        case "black_dan_3", "שחורה דאן 3":
            return "black_dan_4"
        case "black_dan_4", "שחורה דאן 4":
            return "black_dan_5"
        case "black_dan_5", "שחורה דאן 5":
            return "black_dan_6"
        case "black_dan_6", "שחורה דאן 6":
            return "black_dan_7"
        case "black_dan_7", "שחורה דאן 7":
            return "black_dan_8"
        case "black_dan_8", "שחורה דאן 8":
            return "black_dan_9"
        case "black_dan_9", "שחורה דאן 9":
            return "black_dan_10"
        default:
            return ""
        }
    }
        
    private func nextBeltDisplayNameForUi(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if isEnglish {
            switch clean {
            case "white", "לבנה":
                return "Yellow"
            case "yellow", "צהובה":
                return "Orange"
            case "orange", "כתומה":
                return "Green"
            case "green", "ירוקה":
                return "Blue"
            case "blue", "כחולה":
                return "Brown"
            case "brown", "חומה":
                return "Black Dan 1"
            case "black", "שחורה", "שחורה דאן 1":
                return "Black Dan 2"
            case "black_dan_2", "שחורה דאן 2":
                return "Black Dan 3"
            case "black_dan_3", "שחורה דאן 3":
                return "Black Dan 4"
            case "black_dan_4", "שחורה דאן 4":
                return "Black Dan 5"
            case "black_dan_5", "שחורה דאן 5":
                return "Black Dan 6"
            case "black_dan_6", "שחורה דאן 6":
                return "Black Dan 7"
            case "black_dan_7", "שחורה דאן 7":
                return "Black Dan 8"
            case "black_dan_8", "שחורה דאן 8":
                return "Black Dan 9"
            case "black_dan_9", "שחורה דאן 9":
                return "Black Dan 10"
            case "black_dan_10", "שחורה דאן 10":
                return "—"
            default:
                return "—"
            }
        } else {
            switch clean {
            case "white", "לבנה":
                return "צהובה"
            case "yellow", "צהובה":
                return "כתומה"
            case "orange", "כתומה":
                return "ירוקה"
            case "green", "ירוקה":
                return "כחולה"
            case "blue", "כחולה":
                return "חומה"
            case "brown", "חומה":
                return "שחורה דאן 1"
            case "black", "שחורה", "שחורה דאן 1":
                return "שחורה דאן 2"
            case "black_dan_2", "שחורה דאן 2":
                return "שחורה דאן 3"
            case "black_dan_3", "שחורה דאן 3":
                return "שחורה דאן 4"
            case "black_dan_4", "שחורה דאן 4":
                return "שחורה דאן 5"
            case "black_dan_5", "שחורה דאן 5":
                return "שחורה דאן 6"
            case "black_dan_6", "שחורה דאן 6":
                return "שחורה דאן 7"
            case "black_dan_7", "שחורה דאן 7":
                return "שחורה דאן 8"
            case "black_dan_8", "שחורה דאן 8":
                return "שחורה דאן 9"
            case "black_dan_9", "שחורה דאן 9":
                return "שחורה דאן 10"
            case "black_dan_10", "שחורה דאן 10":
                return "—"
            default:
                return "—"
            }
        }
    }

    private func branchAddressFallback(for branchValue: String) -> String {
        let clean = branchValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty, clean != "—" else {
            return "—"
        }

        let catalogAddress = TrainingCatalogIOS.addressFor(clean)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !catalogAddress.isEmpty && catalogAddress != clean {
            return catalogAddress
        }

        let separators = CharacterSet(charactersIn: "–-")
        let parts = clean
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return "\(parts[1]), \(parts[0])"
        }

        return "—"
    }

    private func normalizedProfileGroup(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        switch clean {
        case "נוער + בוגרים":
            return "נוער + בוגרים"
        case "נוער", "Teen", "Teens":
            return "נוער"
        case "בוגרים", "Adults":
            return "בוגרים"
        case "ילדים", "Kids":
            return "ילדים"
        default:
            return clean
        }
    }

    private func nextTrainingTextFromCatalog() -> String {
        let branchValue = displayedBranch
            .components(separatedBy: CharacterSet(charactersIn: "\n|;,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "—" } ?? ""

        guard !branchValue.isEmpty else {
            return ""
        }

        let groupValue = normalizedProfileGroup(displayedGroup)

        let regionValue = firstNonEmpty(
            resolvedRegion,
            "השרון"
        )

        let upcoming = TrainingCatalogIOS.upcomingFor(
            region: regionValue,
            branch: branchValue,
            group: groupValue,
            count: 1
        )
        .first

        guard let upcoming else {
            return ""
        }

        let locale = isEnglish ? Locale(identifier: "en_US") : Locale(identifier: "he_IL")

        let dayFormatter = DateFormatter()
        dayFormatter.locale = locale
        dayFormatter.dateFormat = "EEEE"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateFormat = "HH:mm"

        let day = dayFormatter.string(from: upcoming.date)
        let time = timeFormatter.string(from: upcoming.date)

        let place = upcoming.place
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if place.isEmpty {
            return "\(day) • \(time)"
        }

        return "\(day) • \(time)\n\(place)"
    }

    private func nextTrainingCoachFromCatalog() -> String {
        let branchValue = displayedBranch
            .components(separatedBy: CharacterSet(charactersIn: "\n|;,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && $0 != "—" } ?? ""

        guard !branchValue.isEmpty else {
            return ""
        }

        let groupValue = normalizedProfileGroup(displayedGroup)

        let regionValue = firstNonEmpty(
            resolvedRegion,
            "השרון"
        )

        let upcoming = TrainingCatalogIOS.upcomingFor(
            region: regionValue,
            branch: branchValue,
            group: groupValue,
            count: 1
        )
        .first

        guard let upcoming else {
            return ""
        }

        return upcoming.coach
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

