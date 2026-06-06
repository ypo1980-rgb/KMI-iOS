import SwiftUI
import FirebaseAuth
import FirebaseFirestore

private extension String {
    func ifBlankDash() -> String {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "—" : clean
    }
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
    var headCoach: String = ""
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

    @Environment(\.dismiss) private var dismiss

    @State private var firestoreInfo = MyProfileFirestoreInfo()
    @State private var isLoadingFirestoreProfile: Bool = false
    @State private var passwordVisible: Bool = false

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
        isEnglish ? .leading : .trailing
    }

    private var profileFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var profileStackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
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
        let value = resolvedFullName
        return value.isEmpty ? tr("שם המשתמש", "User name") : value
    }

    private var displayedBranch: String {
        let branches = profileBranchList(from: resolvedBranch)

        guard !branches.isEmpty else {
            return "—"
        }

        return branches.joined(separator: "\n")
    }

    private var displayedBranchAddress: String {
        let explicitAddress = firstNonEmpty(
            firestoreInfo.branchAddress,
            branchAddress,
            branchAddressSnake,
            address
        )

        let branches = profileBranchList(from: resolvedBranch)

        if branches.count <= 1 {
            return firstNonEmpty(
                explicitAddress,
                branchAddressFallback(for: displayedBranch)
            )
            .ifBlankDash()
        }

        let explicitAddresses = profileBranchList(from: explicitAddress)

        if explicitAddresses.count == branches.count {
            return explicitAddresses.joined(separator: "\n").ifBlankDash()
        }

        let resolvedAddresses = branches.map { branchValue in
            branchAddressFallback(for: branchValue)
        }

        return resolvedAddresses.joined(separator: "\n").ifBlankDash()
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

    private var displayedNextBelt: String {
        nextBeltDisplayNameForUi(resolvedBeltId)
    }

    private var displayedHeadCoach: String {
        firstNonEmpty(
            firestoreInfo.headCoach,
            headCoach,
            tr("איציק ביטון", "Itzik Biton")
        )
        .ifBlankDash()
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
            VStack(spacing: 0) {
                profileTopChrome

                ZStack {
                    profileBackground

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            if isLoadingFirestoreProfile {
                                syncingBadge
                            }

                            profileGlassCard
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, max(34, geo.safeAreaInsets.bottom + 24))
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadFirestoreProfileIfNeeded()
        }
    }

    private var profileTopChrome: some View {
        VStack(spacing: 0) {
            KmiTopBar(
                roleLabel: tr("מצב\nמאמן", "Coach\nMode"),
                title: tr("הפרופיל שלי", "My Profile"),
                rightText: nil,
                titleColor: Color.black.opacity(0.86),
                onMenu: {
                    dismiss()
                }
            )
            .background(Color.white)

            HStack {
                Spacer()

                KmiIconStripBar(
                    items: KmiIconStripItem.allCases,
                    selected: nil
                ) { item in
                    handleProfileIconTap(item)
                }
                .frame(width: 330)

                Spacer()
            }
            .padding(.top, 0)
            .padding(.bottom, 4)
            .background(Color.white)
        }
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func handleProfileIconTap(_ item: KmiIconStripItem) {
        switch item {
        case .home:
            dismiss()

        case .settings:
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                AppNavModel.sharedInstance?.push(.settings)
            }

        case .assistant:
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                AppNavModel.sharedInstance?.push(.voiceAssistant)
            }

        case .search:
            // במסך הפרופיל נשאיר את החיפוש לסבב הבא כדי לא לפתוח Sheet כפול.
            break

        case .share:
            // שיתוף פרופיל נחבר בסבב הבא אם תרצה.
            break
        }
    }

    // MARK: - Background

    private var profileBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.086, blue: 0.188),
                Color(red: 0.122, green: 0.165, blue: 0.322),
                Color(red: 0.145, green: 0.459, blue: 0.737)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var syncingBadge: some View {
        Text(tr("מסנכרן פרופיל...", "Syncing profile..."))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
            )
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
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.91, green: 0.95, blue: 1.00))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(red: 0.74, green: 0.82, blue: 0.94), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 7)
        )
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if isEnglish {
                    headerTextBlock(
                        alignment: .leading,
                        frameAlignment: .leading,
                        textAlignment: .leading
                    )

                    closeButton
                } else {
                    closeButton

                    headerTextBlock(
                        alignment: .trailing,
                        frameAlignment: .trailing,
                        textAlignment: .trailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .leftToRight)

            profileBeltImage
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .padding(.horizontal, 8)
                .padding(.top, -2)
                .padding(.bottom, 2)
        }
    }

    private func headerTextBlock(
        alignment: HorizontalAlignment,
        frameAlignment: Alignment,
        textAlignment: TextAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(displayedUserName)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.18))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(displayedBelt)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color(red: 0.16, green: 0.24, blue: 0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
    }

    private var profileBeltImage: some View {
        Image(profileBeltImageName(for: resolvedBeltId))
            .resizable()
            .scaledToFit()
            .rotationEffect(.degrees(isEnglish ? -5 : 5))
            .shadow(color: Color.black.opacity(0.17), radius: 7, x: 0, y: 4)
            .accessibilityHidden(true)
    }

    private var beltSubtitleSection: some View {
        Text(displayedBelt)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(red: 0.16, green: 0.24, blue: 0.58))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
            .multilineTextAlignment(profileTextAlignment)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(red: 0.14, green: 0.17, blue: 0.25))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.96))
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.07), lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var editProfileButton: some View {
        Button {
            dismiss()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                AppNavModel.sharedInstance?.push(.editProfile)
            }
        } label: {
            Text(tr("עריכת פרופיל", "Edit profile"))
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.44, green: 0.30, blue: 0.74),
                                    Color(red: 0.30, green: 0.20, blue: 0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Color(red: 0.30, green: 0.20, blue: 0.62).opacity(0.25),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var thinDivider: some View {
        Rectangle()
            .fill(Color(red: 0.72, green: 0.79, blue: 0.89))
            .frame(height: 1)
    }

    private var thinDividerForLightCard: some View {
        Rectangle()
            .fill(Color(red: 0.72, green: 0.79, blue: 0.89))
            .frame(height: 1)
    }

    private var profileInfoSections: some View {
        VStack(spacing: 0) {
            labeledValueBlock(
                label: tr("סניף:", "Branch:"),
                value: displayedBranch
            )

            labeledValueBlock(
                label: tr("כתובת הסניף:", "Branch address:"),
                value: displayedBranchAddress
            )

            labeledValueBlock(
                label: tr("קבוצה:", "Group:"),
                value: displayedGroup
            )

            labeledValueBlock(
                label: tr("מאמן בכיר:", "Head coach:"),
                value: displayedHeadCoach
            )

            labeledValueBlock(
                label: tr("מאמן:", "Coach:"),
                value: displayedCoach
            )

            labeledValueBlock(
                label: tr("אימון הבא:", "Next training:"),
                value: displayedNextTraining
            )

            Spacer().frame(height: 4)

            thinDivider.opacity(0.75)

            Spacer().frame(height: 4)

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

    private func labeledValueBlock(label: String, value: String) -> some View {
        VStack(alignment: profileStackAlignment, spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.50))
                .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                .multilineTextAlignment(profileTextAlignment)

            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.18))
                .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                .multilineTextAlignment(profileTextAlignment)
                .lineLimit(4)
                .minimumScaleFactor(0.80)

            Spacer().frame(height: 5)

            Rectangle()
                .fill(Color(red: 0.72, green: 0.79, blue: 0.89))
                .frame(height: 1)
        }
        .padding(.vertical, 5)
    }

    private func passwordRow(label: String, password: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if isEnglish {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.50))

                    Spacer()

                    Text(passwordVisible ? password : "••••••••")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.18))

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.62))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0.28, green: 0.24, blue: 0.62))
                    }
                    .buttonStyle(.plain)

                    Text(passwordVisible ? password : "••••••••")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(red: 0.07, green: 0.10, blue: 0.18))

                    Spacer()

                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.50))
                }
            }
            .padding(.vertical, 7)

            Rectangle()
                .fill(Color(red: 0.72, green: 0.79, blue: 0.89))
                .frame(height: 1)
        }
    }

    private var trainingTowardBeltCard: some View {
        VStack(alignment: profileStackAlignment, spacing: 7) {
            Text(tr("מתאמן לחגורה", "Training toward belt"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.35, green: 0.40, blue: 0.50))
                .frame(maxWidth: .infinity, alignment: profileFrameAlignment)
                .multilineTextAlignment(profileTextAlignment)
                .lineLimit(1)

            HStack(spacing: 10) {
                if isEnglish {
                    Image(profileBeltImageName(for: displayedNextBelt))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 38)
                        .rotationEffect(.degrees(-5))
                        .accessibilityHidden(true)

                    Text(displayedNextBelt)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.16, green: 0.24, blue: 0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    Text(displayedNextBelt)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(red: 0.16, green: 0.24, blue: 0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Image(profileBeltImageName(for: displayedNextBelt))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 38)
                        .rotationEffect(.degrees(5))
                        .accessibilityHidden(true)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.70, green: 0.78, blue: 0.88), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - Firestore

    private func loadFirestoreProfileIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
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

                    guard let data = snapshot?.data(), snapshot?.exists == true else {
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
                                "activeBranch",
                                "active_branch",
                                "branch",
                                "branchesCsv",
                                "branches"
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
                                "activeGroup",
                                "active_group",
                                "primaryGroup",
                                "groupKey",
                                "group_key",
                                "age_group",
                                "group",
                                "groupsCsv",
                                "groups"
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
                        headCoach: firstFirestoreString(
                            data,
                            keys: [
                                "headCoach",
                                "head_coach",
                                "seniorCoach",
                                "senior_coach"
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

        if !info.headCoach.isEmpty {
            defaults.set(info.headCoach, forKey: "headCoach")
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

