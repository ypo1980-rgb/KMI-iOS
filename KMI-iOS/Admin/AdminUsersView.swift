import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseFunctions

struct AdminUsersView: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    @State private var users: [AdminUser] = []
    @State private var filteredUsers: [AdminUser] = []

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var sectionTitleColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var panelColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var elevatedPanelColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var fieldColor: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var borderColor: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var fieldTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var fieldIconColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    @State private var searchText: String = ""
    @State private var selectedRole: UserRoleFilter = .all
    @State private var filtersExpanded = false
    @State private var accessUser: AdminUser?
    @State private var selectedAccessType = "trainee"
    @State private var isSavingUserAccess = false
    @State private var userAccessSaveError: String?
    @State private var showUserAccessSaved = false

    @State private var selectedGender: AdminGenderFilter = .all
    @State private var selectedRegion: String? = nil
    @State private var selectedBelt: String? = nil
    @State private var selectedAgeBucket: String? = nil

    @State private var loading = true
    @State private var errorMessage: String? = nil
    @State private var unlikeQuestions: [AssistantFeedbackQuestion] = []
    @State private var usersPdfShare: AdminUsersPdfShare?
    @State private var showUsersPdfError = false

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

    private var rowChevronName: String {
        isEnglish ? "chevron.right" : "chevron.left"
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func accessTextForUi(_ accessType: String?) -> String {
        switch accessType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "trainee":
            return tr("מתאמן", "Trainee")
        case "coach":
            return tr("מאמן", "Coach")
        case "both":
            return tr("מתאמן ומאמן", "Trainee & Coach")
        default:
            return tr("הרשאה טרם הוגדרה", "Access not configured")
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var allRegionsForFilter: [String] {
        users
            .map { $0.region.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter {
                $0.caseInsensitiveCompare("לא ידוע") != .orderedSame &&
                $0.caseInsensitiveCompare("unknown") != .orderedSame &&
                $0.caseInsensitiveCompare("null") != .orderedSame &&
                $0 != "—"
            }
            .uniqueCaseInsensitiveSorted()
    }

    private var allBeltsForFilter: [String] {
        users
            .map { beltLabel($0.currentBeltId) }
            .filter { !$0.isEmpty }
            .uniqueCaseInsensitiveSorted()
    }

    private var allAgeBucketsForFilter: [String] {
        users
            .map { $0.ageBucket }
            .filter { $0 != "לא ידוע" }
            .uniqueCaseInsensitiveSorted()
            .sorted { ageBucketSortIndex($0) < ageBucketSortIndex($1) }
    }

    var body: some View {

        ZStack {
            KmiAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    screenHeader

                    headerStats

                    advancedFiltersPanel

                    distributionsDashboard

                    searchBar

                    if let errorMessage, !errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errorMessageCard(errorMessage)
                    }

                    if loading {
                        loadingUsersState

                    } else if filteredUsers.isEmpty {
                        emptyUsersState

                    } else {
                        usersSectionsList
                    }

                    if !demoPrivacy.isEnabled, !unlikeQuestions.isEmpty {
                        unlikeQuestionsCard
                            .padding(.horizontal, 14)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            loadUsers()
        }
        .onChange(of: searchText) { _, _ in
            applyFilter()
        }
        .sheet(item: $accessUser) { user in
            userAccessSheet(user)
        }
        .sheet(item: $usersPdfShare) { report in
            KmiShareSheet(items: [report.url])
        }
        .alert(
            tr("לא ניתן ליצור את הדוח", "Unable to create the report"),
            isPresented: $showUsersPdfError
        ) {
            Button(tr("אישור", "OK"), role: .cancel) {}
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showUserAccessSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .kmiIconSize(.small)
                        .foregroundStyle(Color.green)
                        .accessibilityHidden(true)

                    Text(
                        tr(
                            "הרשאת המשתמש נשמרה",
                            "User access saved"
                        )
                    )
                    .kmiTypography(.body)
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showUserAccessSaved = false
                    } label: {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .kmiIconSize(.tiny)
                            .foregroundStyle(fieldIconColor)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("סגור הודעה", "Dismiss message"))
                }
                .padding(.leading, 12)
                .background(panelColor, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor, lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .environment(\.layoutDirection, screenLayoutDirection)
            }
        }
    }

    private func displayName(for user: AdminUser) -> String {
        guard demoPrivacy.isEnabled else {
            return user.fullName
        }

        return TraineeDisplayNameMapper.displayName(
            realName: user.fullName,
            stableKey: user.id,
            demoIndex: users.firstIndex { $0.id == user.id },
            isEnglish: isEnglish
        )
    }

    private func userAccessSheet(_ user: AdminUser) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("ניהול הרשאת משתמש", "Manage user access"))
                        .kmiTypography(.sectionTitle)
                        .foregroundStyle(primaryTextColor)
                        .accessibilityAddTraits(.isHeader)

                    Text(displayName(for: user))
                        .kmiTypography(.body)
                        .foregroundStyle(secondaryTextColor)

                    userAccessOption("trainee", title: tr("מתאמן בלבד", "Trainee only"))
                    userAccessOption("coach", title: tr("מאמן בלבד", "Coach only"))
                    userAccessOption("both", title: tr("מתאמן ומאמן", "Trainee and coach"))

                    if let userAccessSaveError {
                        Text(userAccessSaveError)
                            .kmiTypography(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }

            Divider()

            VStack(spacing: 6) {
                Button {
                    let accessType = selectedAccessType
                    Task { await saveUserAccess(user, accessType: accessType) }
                } label: {
                    Text(
                        isSavingUserAccess
                            ? tr("שומר הרשאה…", "Saving access…")
                            : tr("שמור הרשאה", "Save access")
                    )
                    .kmiTypography(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSavingUserAccess || user.accessTargetUid == nil)

                Button(role: .cancel) {
                    accessUser = nil
                } label: {
                    Text(tr("ביטול", "Cancel"))
                        .kmiTypography(.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isSavingUserAccess)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(panelColor)
        .environment(\.layoutDirection, screenLayoutDirection)
        .interactiveDismissDisabled(isSavingUserAccess)
    }

    private func userAccessOption(_ value: String, title: String) -> some View {
        let isSelected = selectedAccessType == value

        return Button {
            selectedAccessType = value
            userAccessSaveError = nil
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(isSelected ? Color.accentColor : fieldIconColor)
                    .accessibilityHidden(true)

                Text(title)
                    .kmiTypography(.body)
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .disabled(isSavingUserAccess)
    }

    private var loadingUsersState: some View {
        VStack(spacing: 12) {
            KmiLoadingOverlay()
                .frame(height: 132)

            Text(
                tr(
                    "טוען משתמשים מהשרת...",
                    "Loading users from the server..."
                )
            )
            .kmiTypography(.cardTitle)
            .foregroundStyle(secondaryTextColor)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 40)
    }

    private var emptyUsersState: some View {
        VStack(spacing: 12) {
            Image(
                systemName:
                    "person.crop.circle.badge.questionmark"
            )
            .resizable()
            .scaledToFit()
            .kmiIconSize(.extraLarge)
            .foregroundStyle(
                isDarkMode
                    ? Color.white.opacity(0.92)
                    : Color(red: 0.08, green: 0.42, blue: 0.70)
            )

            Text(
                tr(
                    "לא נמצאו משתמשים תואמים",
                    "No matching users found"
                )
            )
            .kmiTypography(.sectionTitle)
            .foregroundStyle(primaryTextColor)
            .multilineTextAlignment(.center)

            Text(
                tr(
                    "נסה לשנות חיפוש או סינון",
                    "Try changing the search or filters"
                )
            )
            .kmiTypography(.body)
            .foregroundStyle(secondaryTextColor)
            .multilineTextAlignment(.center)

            Button {
                clearAllFilters()
            } label: {
                Text(
                    tr(
                        "נקה סינון",
                        "Clear filters"
                    )
                )
                .kmiTypography(.action)
                .foregroundStyle(
                    isDarkMode
                        ? Color.black.opacity(0.88)
                        : Color.white
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            isDarkMode
                                ? Color.white.opacity(0.94)
                                : Color(
                                    red: 0.03,
                                    green: 0.48,
                                    blue: 0.78
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 46)
        .padding(.bottom, 36)
    }
 
    // MARK: Users sections

    private var usersSectionsList: some View {

        let adminUsers = filteredUsers.filter { AdminUser.isAdminRole($0.role) }
        let regularUsers = filteredUsers.filter { !AdminUser.isAdminRole($0.role) }

        let traineeUsers = regularUsers.filter { userCategory($0) == .trainee }
        let coachUsers = regularUsers.filter { userCategory($0) == .coach }
        let bothUsers = regularUsers.filter { userCategory($0) == .both }

        return VStack(spacing: 12) {

            if selectedRole == .all || selectedRole == .trainee {
                userSectionCard(
                    title: tr("משתמשים – מתאמנים (\(traineeUsers.count))", "Users – trainees (\(traineeUsers.count))"),
                    users: traineeUsers,
                    emptyMessage: tr("אין מתאמנים מתאימים לפילטרים.", "No trainees match the selected filters.")
                )
            }

            if selectedRole == .all || selectedRole == .coach {
                userSectionCard(
                    title: tr("משתמשים – מאמנים (\(coachUsers.count))", "Users – coaches (\(coachUsers.count))"),
                    users: coachUsers,
                    emptyMessage: tr("אין מאמנים מתאימים לפילטרים.", "No coaches match the selected filters.")
                )
            }

            if selectedRole == .all || selectedRole == .both {
                userSectionCard(
                    title: tr("משתמשים – מתאמנים + מאמנים (\(bothUsers.count))", "Users – trainees + coaches (\(bothUsers.count))"),
                    users: bothUsers,
                    emptyMessage: tr("אין משתמשים בעלי הרשאה כפולה התואמים לסינון.", "No dual-access users match the selected filters.")
                )
            }

            if selectedRole == .all && !adminUsers.isEmpty {
                userSectionCard(
                    title: tr("משתמשים – מנהלים (\(adminUsers.count))", "Users – admins (\(adminUsers.count))"),
                    users: adminUsers,
                    emptyMessage: tr("אין מנהלים מתאימים לפילטרים.", "No admins match the selected filters.")
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private func userSectionCard(
        title: String,
        users: [AdminUser],
        emptyMessage: String
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(title)
                .kmiTypography(.sectionTitle)
                .foregroundStyle(sectionTitleColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(screenTextAlignment)
                .fixedSize(horizontal: false, vertical: true)

            if users.isEmpty {
                Text(emptyMessage)
                    .kmiTypography(.secondary)
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(screenTextAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)

            } else {
                LazyVStack(spacing: 8) {
                    ForEach(users) { user in
                        VStack(spacing: 0) {
                            if demoPrivacy.isEnabled || user.hasConflictingAccessAccounts {
                                userRow(user)
                            } else {
                                NavigationLink {
                                    AdminUserDetailsView(user: user)
                                } label: {
                                    userRow(user)
                                }
                                .buttonStyle(.plain)
                            }

                            Divider()
                                .padding(.horizontal, 12)

                            VStack(spacing: 4) {
                                Button {
                                    openUserAccess(user)
                                } label: {
                                    Text(tr("שינוי הרשאה", "Change access"))
                                        .kmiTypography(.body)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: screenFrameAlignment
                                        )
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .disabled(isSavingUserAccess || user.accessTargetUid == nil)

                                if user.accessTargetUid == nil {
                                    Text(
                                        tr(
                                            user.hasConflictingAccessAccounts
                                                ? "האימייל והטלפון משויכים לכמה חשבונות. כדי לשנות הרשאה נדרש חשבון מזוהה אחד."
                                                : "לא ניתן לאמת את מזהה החשבון לשינוי הרשאה.",
                                            user.hasConflictingAccessAccounts
                                                ? "This email and phone number match multiple accounts. Access can only be changed for a single identified account."
                                                : "The account ID could not be verified for an access change."
                                        )
                                    )
                                    .kmiTypography(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(screenTextAlignment)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: screenFrameAlignment
                                    )
                                    .padding(.bottom, 8)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(fieldColor)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(borderColor, lineWidth: 1)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            userBeltAccentColor(user).opacity(0.35),
                                            lineWidth: 1
                                        )
                                }
                                .allowsHitTesting(false)
                        }
                        .shadow(
                            color: Color.black.opacity(isDarkMode ? 0.14 : 0.08),
                            radius: 7,
                            x: 0,
                            y: 3
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(panelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.14 : 0.07
            ),
            radius: 7,
            x: 0,
            y: 3
        )
    }

    private var unlikeQuestionsCard: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "שאלות לסקירה (UNLIKE)",
                    "Questions for review (UNLIKE)"
                )
            )
            .kmiTypography(.sectionTitle)
            .foregroundStyle(sectionTitleColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                tr(
                    "רשימת שאלות שהעוזר לא ענה עליהן טוב – לסקירה ולשיפור מאגר התכנים.",
                    "Questions where the assistant response was marked as not helpful — for review and content improvement."
                )
            )
            .kmiTypography(.secondary)
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)

            LazyVStack(spacing: 8) {
                ForEach(unlikeQuestions.prefix(20)) { item in
                    unlikeQuestionRow(item)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(elevatedPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color(
                    red: 0.22,
                    green: 0.74,
                    blue: 0.97
                )
                .opacity(isDarkMode ? 0.36 : 0.24),
                lineWidth: 1
            )
        )
    }

    private func unlikeQuestionRow(
        _ item: AssistantFeedbackQuestion
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 4
        ) {
            Text("• \(item.question)")
                .kmiTypography(.body)
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            let meta = item.metaLine(
                isEnglish: isEnglish
            )

            if !meta.isEmpty {
                Text(meta)
                    .kmiTypography(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: screenFrameAlignment
                    )
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(fieldColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
    }

    // MARK: Screen header

    private var screenHeader: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 5
        ) {
            Text(
                tr(
                    "ניהול משתמשים",
                    "User management"
                )
            )
            .kmiTypography(.screenTitle)
            .foregroundStyle(primaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                tr(
                    "משתמשים אמיתיים מ־Firestore",
                    "Real users from Firestore"
                )
            )
            .kmiTypography(.secondary)
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                exportUsersPdf()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .resizable()
                        .scaledToFit()
                        .kmiIconSize(.small)
                        .accessibilityHidden(true)

                    Text(tr("שתף PDF", "Share PDF"))
                        .kmiTypography(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(loading || filteredUsers.isEmpty)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, screenLayoutDirection)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func errorMessageCard(
        _ message: String
    ) -> some View {
        HStack(spacing: 10) {
            if isEnglish {
                errorMessageIcon

                errorMessageText(message)
            } else {
                errorMessageText(message)

                errorMessageIcon
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                isDarkMode
                    ? Color(
                        red: 0.35,
                        green: 0.04,
                        blue: 0.08
                    )
                    .opacity(0.72)
                    : Color(
                        red: 1.00,
                        green: 0.91,
                        blue: 0.92
                    )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.red.opacity(
                    isDarkMode ? 0.30 : 0.20
                ),
                lineWidth: 1
            )
        )
        .padding(.horizontal, 14)
    }

    private var errorMessageIcon: some View {
        Image(
            systemName:
                "exclamationmark.triangle.fill"
        )
        .resizable()
        .scaledToFit()
        .kmiIconSize(.small)
        .foregroundStyle(
            isDarkMode
                ? Color(
                    red: 1.00,
                    green: 0.70,
                    blue: 0.70
                )
                : Color(
                    red: 0.72,
                    green: 0.08,
                    blue: 0.12
                )
        )
        .accessibilityHidden(true)
    }

    private func errorMessageText(
        _ message: String
    ) -> some View {
        Text(message)
            .kmiTypography(.secondary)
            .foregroundStyle(
                isDarkMode
                    ? Color(
                        red: 1.00,
                        green: 0.82,
                        blue: 0.82
                    )
                    : Color(
                        red: 0.55,
                        green: 0.04,
                        blue: 0.08
                    )
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

    // MARK: Header stats

    private var headerStats: some View {

        let totalUsers = users.count

        let branchCount = Set(
            users.flatMap { user in
                var values: [String] = []

                let singleBranch = user.branch.trimmingCharacters(in: .whitespacesAndNewlines)

                if !singleBranch.isEmpty {
                    values.append(singleBranch)
                }

                values.append(
                    contentsOf: user.branches
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                )

                return values
            }
            .map { $0.lowercased() }
        )
        .count

        let avgAge = users
            .compactMap { $0.age }
            .averageValue

        let totalAppOpens = users.reduce(0) { $0 + $1.appOpenCount }
        let activeUsers = users.filter { $0.appOpenCount > 0 }.count

        let avgAppOpens: Double? = totalUsers > 0
            ? Double(totalAppOpens) / Double(totalUsers)
            : nil

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                statItem(
                    tr("משתמשים", "Users"),
                    loading ? "…" : "\(totalUsers)",
                    icon: "person.3.fill"
                )

                statItem(
                    tr("סניפים", "Branches"),
                    loading ? "…" : "\(branchCount)",
                    icon: "building.2.fill"
                )

                statItem(
                    tr("גיל ממוצע", "Avg. age"),
                    loading ? "…" : avgAge.map { String(format: "%.1f", $0) } ?? "-",
                    icon: "calendar"
                )
            }

            HStack(spacing: 8) {
                statItem(
                    tr("שימושים", "App opens"),
                    loading ? "…" : "\(totalAppOpens)",
                    icon: "iphone.gen3"
                )

                statItem(
                    tr("פעילים", "Active"),
                    loading ? "…" : "\(activeUsers)",
                    icon: "bolt.fill"
                )

                statItem(
                    tr("ממוצע שימוש", "Avg. opens"),
                    loading ? "…" : avgAppOpens.map { String(format: "%.1f", $0) } ?? "-",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private func statItem(
        _ title: String,
        _ value: String,
        icon: String
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .kmiIconSize(.small)
                .foregroundStyle(
                    Color(
                        red: 0.08,
                        green: 0.58,
                        blue: 0.88
                    )
                )
                .frame(minHeight: 18)

            Text(value)
                .kmiTypography(.metric)
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .kmiTypography(.caption)
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 88)
        .padding(.horizontal, 6)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(elevatedPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                isDarkMode
                    ? Color(
                        red: 0.22,
                        green: 0.74,
                        blue: 0.97
                    )
                    .opacity(0.32)
                    : Color(
                        red: 0.08,
                        green: 0.48,
                        blue: 0.78
                    )
                    .opacity(0.20),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.14 : 0.08
            ),
            radius: 6,
            x: 0,
            y: 3
        )
    }

    // MARK: Advanced filters

    private var activeFilterLabels: [String] {
        var labels: [String] = []

        switch selectedRole {
        case .all:
            break
        case .trainee:
            labels.append(tr("מתאמנים", "Trainees"))
        case .coach:
            labels.append(tr("מאמנים", "Coaches"))
        case .both:
            labels.append(tr("מתאמנים + מאמנים", "Trainees + Coaches"))
        }

        switch selectedGender {
        case .all:
            break
        case .male:
            labels.append(genderLabel("male"))
        case .female:
            labels.append(genderLabel("female"))
        }

        if let selectedRegion {
            labels.append(selectedRegion)
        }

        if let selectedBelt {
            labels.append(selectedBelt)
        }

        if let selectedAgeBucket {
            labels.append(ageBucketLabel(selectedAgeBucket))
        }

        return labels
    }

    private var advancedFiltersPanel: some View {
        let filterLabels = activeFilterLabels

        return advancedFiltersPanelContent(filterLabels: filterLabels)
    }

    private func advancedFiltersPanelContent(filterLabels: [String]) -> some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    filtersExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            filtersExpanded
                                ? tr("הסתר מסננים", "Hide filters")
                                : tr("פתח מסננים", "Show filters")
                        )
                        .kmiTypography(.sectionTitle)
                        .foregroundStyle(primaryTextColor)

                        Text(
                            filterLabels.isEmpty
                                ? tr("אין מסננים פעילים", "No active filters")
                                : filterLabels.joined(separator: " • ")
                        )
                        .kmiTypography(.caption)
                        .foregroundStyle(
                            filterLabels.isEmpty ? secondaryTextColor : Color.accentColor
                        )
                        .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: filtersExpanded ? "chevron.up" : "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .kmiIconSize(.tiny)
                        .foregroundStyle(fieldIconColor)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .environment(\.layoutDirection, screenLayoutDirection)
            .accessibilityValue(
                filtersExpanded
                    ? tr("פתוח", "Expanded")
                    : tr("סגור", "Collapsed")
            )

            if filtersExpanded {
                if !filterLabels.isEmpty {
                    Button {
                        resetFilterSelections()
                        applyFilter()
                    } label: {
                        Text(tr("נקה את כל המסננים", "Clear all filters"))
                            .kmiTypography(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .environment(\.layoutDirection, screenLayoutDirection)
                }

                advancedFilterRows
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(panelColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .shadow(
            color: Color.black.opacity(isDarkMode ? 0.12 : 0.07),
            radius: 7,
            x: 0,
            y: 3
        )
        .padding(.horizontal, 14)
    }

    private var advancedFilterRows: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            let roleOptions: [(key: String, role: UserRoleFilter, label: String)] = [
                ("all", .all, tr("כולם", "All")),
                ("trainee", .trainee, tr("מתאמנים", "Trainees")),
                ("coach", .coach, tr("מאמנים", "Coaches")),
                ("both", .both, tr("מתאמנים + מאמנים", "Trainees + Coaches"))
            ]

            KmiPremiumDropdown(
                title: tr("הרשאה", "Access"),
                options: roleOptions.map { $0.key },
                selectedValue: Binding(
                    get: {
                        roleOptions.first { $0.role == selectedRole }?.key ?? "all"
                    },
                    set: { key in
                        guard let option = roleOptions.first(where: { $0.key == key }),
                              option.role != selectedRole else { return }

                        selectedRole = option.role
                        applyFilter()
                    }
                ),
                placeholder: tr("כולם", "All"),
                isEnglish: isEnglish,
                isEnabled: true,
                labelForOption: { key in
                    roleOptions.first { $0.key == key }?.label ?? key
                },
                titleInsideField: true
            )

            filterScrollRow(title: tr("מין", "Gender")) {
                filterChip(
                    title: tr("כל המינים", "All genders"),
                    isSelected: selectedGender == .all
                ) {
                    selectedGender = .all
                    applyFilter()
                }

                filterChip(
                    title: tr("זכר", "Male"),
                    isSelected: selectedGender == .male
                ) {
                    selectedGender = .male
                    applyFilter()
                }

                filterChip(
                    title: tr("נקבה", "Female"),
                    isSelected: selectedGender == .female
                ) {
                    selectedGender = .female
                    applyFilter()
                }
            }

            filterScrollRow(title: tr("אזור", "Region")) {
                filterChip(
                    title: tr("כל האזורים", "All regions"),
                    isSelected: selectedRegion == nil
                ) {
                    selectedRegion = nil
                    applyFilter()
                }

                ForEach(allRegionsForFilter, id: \.self) { region in
                    filterChip(
                        title: region,
                        isSelected: selectedRegion == region
                    ) {
                        selectedRegion = region
                        applyFilter()
                    }
                }
            }

            filterScrollRow(title: tr("חגורה", "Belt")) {
                filterChip(
                    title: tr("כל החגורות", "All belts"),
                    isSelected: selectedBelt == nil
                ) {
                    selectedBelt = nil
                    applyFilter()
                }

                ForEach(allBeltsForFilter, id: \.self) { belt in
                    filterChip(
                        title: belt,
                        isSelected: selectedBelt == belt
                    ) {
                        selectedBelt = belt
                        applyFilter()
                    }
                }
            }

            filterScrollRow(title: tr("קבוצת גיל", "Age group")) {
                filterChip(
                    title: tr("כל הגילאים", "All ages"),
                    isSelected: selectedAgeBucket == nil
                ) {
                    selectedAgeBucket = nil
                    applyFilter()
                }

                ForEach(allAgeBucketsForFilter, id: \.self) { bucket in
                    filterChip(
                        title: ageBucketLabel(bucket),
                        isSelected: selectedAgeBucket == bucket
                    ) {
                        selectedAgeBucket = bucket
                        applyFilter()
                    }
                }
            }
        }
    }

    private func filterScrollRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .kmiTypography(.caption)
                .foregroundStyle(sectionTitleColor)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, screenLayoutDirection)
    }

    private func filterChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let chipTextColor: Color = {
            if isSelected {
                return Color.white
            }

            return isDarkMode
                ? Color.white.opacity(0.90)
                : Color.black.opacity(0.72)
        }()

        let chipBackgroundColor: Color = {
            if isSelected {
                return Color(
                    red: 0.055,
                    green: 0.647,
                    blue: 0.914
                )
            }

            return isDarkMode
                ? Color.white.opacity(0.12)
                : Color.black.opacity(0.055)
        }()

        let chipBorderColor: Color = {
            if isSelected {
                return Color(
                    red: 0.13,
                    green: 0.70,
                    blue: 0.96
                )
            }

            return borderColor
        }()

        return Button(action: action) {
            Text(title)
                .kmiTypography(.action)
                .foregroundStyle(chipTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(chipBackgroundColor)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            chipBorderColor,
                            lineWidth: 1
                        )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    // MARK: Admin dashboard distributions

    private var distributionsDashboard: some View {

        VStack(spacing: 12) {
            genderDistributionCard
            beltDistributionCard
        }
        .padding(.horizontal, 14)
    }

    private var genderDistributionCard: some View {
        let maleCount = users.filter {
            isMaleGender($0.gender)
        }.count

        let femaleCount = users.filter {
            isFemaleGender($0.gender)
        }.count

        let unknownCount = max(
            0,
            users.count - maleCount - femaleCount
        )

        let maxValue = max(
            maleCount,
            femaleCount,
            unknownCount,
            1
        )

        return VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "חלוקה לפי מין",
                    "Gender distribution"
                )
            )
            .kmiTypography(.sectionTitle)
            .foregroundStyle(sectionTitleColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                distributionBarItem(
                    title: tr("זכר", "Male"),
                    value: loading ? nil : maleCount,
                    maxValue: maxValue,
                    accent: Color(
                        red: 0.22,
                        green: 0.74,
                        blue: 0.97
                    )
                )

                distributionBarItem(
                    title: tr("נקבה", "Female"),
                    value: loading ? nil : femaleCount,
                    maxValue: maxValue,
                    accent: Color(
                        red: 0.90,
                        green: 0.44,
                        blue: 0.78
                    )
                )

                distributionBarItem(
                    title: tr("לא ידוע", "Unknown"),
                    value: loading ? nil : unknownCount,
                    maxValue: maxValue,
                    accent: Color(
                        red: 0.62,
                        green: 0.68,
                        blue: 0.78
                    )
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(elevatedPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
    }

    private var beltDistributionCard: some View {
        let beltItems = beltDistributionItems

        let maxValue = max(
            beltItems.map { $0.count }.max() ?? 0,
            1
        )

        return VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "חלוקה לפי חגורה",
                    "Belt distribution"
                )
            )
            .kmiTypography(.sectionTitle)
            .foregroundStyle(sectionTitleColor)
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 10) {
                    ForEach(beltItems) { item in
                        beltDistributionItem(
                            item: item,
                            maxValue: maxValue
                        )
                    }
                }
                .padding(.vertical, 2)
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
            }
            .environment(
                \.layoutDirection,
                screenLayoutDirection
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(elevatedPanelColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
    }

    private func distributionBarItem(
        title: String,
        value: Int?,
        maxValue: Int,
        accent: Color
    ) -> some View {
        let safeValue = value ?? 0

        let ratio =
            CGFloat(safeValue) /
            CGFloat(max(maxValue, 1))

        let barHeight = max(
            8,
            58 * ratio
        )

        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(
                    cornerRadius: 999,
                    style: .continuous
                )
                .fill(
                    isDarkMode
                        ? Color(
                            red: 0.11,
                            green: 0.16,
                            blue: 0.25
                        )
                        .opacity(0.92)
                        : Color.black.opacity(0.08)
                )
                .frame(height: 58)

                RoundedRectangle(
                    cornerRadius: 999,
                    style: .continuous
                )
                .fill(accent.opacity(0.92))
                .frame(
                    height: value == nil
                        ? 18
                        : barHeight
                )
            }
            .frame(maxWidth: .infinity)

            Text(
                value.map { "\($0)" } ?? "…"
            )
            .kmiTypography(.caption)
            .foregroundStyle(primaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text(title)
                .kmiTypography(.caption)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
    }

    private func beltDistributionItem(
        item: BeltDistributionItem,
        maxValue: Int
    ) -> some View {
        let ratio =
            CGFloat(item.count) /
            CGFloat(max(maxValue, 1))

        let beltWidth = max(
            30,
            68 * ratio
        )

        return VStack(spacing: 5) {
            RoundedRectangle(
                cornerRadius: 999,
                style: .continuous
            )
            .fill(item.color.opacity(0.94))
            .frame(
                width: loading ? 42 : beltWidth,
                height: 34
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 999,
                    style: .continuous
                )
                .stroke(
                    isDarkMode
                        ? Color.white.opacity(0.18)
                        : Color.black.opacity(0.18),
                    lineWidth: 1
                )
            )

            Text(
                loading
                    ? "…"
                    : "\(item.count)"
            )
            .kmiTypography(.caption)
            .foregroundStyle(primaryTextColor)
            .lineLimit(1)
            .minimumScaleFactor(0.70)

            Text(item.label)
                .kmiTypography(.caption)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(width: 76)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(fieldIconColor)

                searchTextField
            } else {
                searchTextField

                Image(systemName: "magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.small)
                    .foregroundStyle(fieldIconColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(fieldColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.12 : 0.06
            ),
            radius: 5,
            x: 0,
            y: 2
        )
        .padding(.horizontal, 14)
    }

    private var searchTextField: some View {
        TextField(
            tr(
                "חיפוש משתמש...",
                "Search user..."
            ),
            text: $searchText
        )
        .kmiTypography(.body)
        .foregroundStyle(fieldTextColor)
        .multilineTextAlignment(
            isEnglish ? .leading : .trailing
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
    }

    // MARK: Row

    private func userRow(
        _ user: AdminUser
    ) -> some View {
        HStack(spacing: 8) {
            if isEnglish {
                userBeltAccent(user)
                userTexts(user)

                Image(systemName: rowChevronName)
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.tiny)
                    .foregroundStyle(fieldIconColor)
                    .frame(width: 18)

            } else {
                Image(systemName: rowChevronName)
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.tiny)
                    .foregroundStyle(fieldIconColor)
                    .frame(width: 18)

                userTexts(user)
                userBeltAccent(user)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: isEnglish ? .leading : .trailing
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func userBeltAccentColor(_ user: AdminUser) -> Color {
        let beltId = user.currentBeltId
        return beltLabel(beltId).isEmpty ? fieldIconColor : beltColor(beltId)
    }

    private func userBeltAccent(_ user: AdminUser) -> some View {
        Capsule()
            .fill(userBeltAccentColor(user))
            .frame(width: 4, height: 54)
            .overlay {
                Capsule()
                    .strokeBorder(fieldIconColor.opacity(0.45), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func userAvatar(displayName: String, accentColor: Color) -> some View {
        let initials = displayName
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
            .compactMap { $0.first }
            .filter { $0.isLetter || $0.isNumber }

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor, accentColor.opacity(0.75), fieldColor],
                        center: .center,
                        startRadius: 0,
                        endRadius: 19
                    )
                )

            Circle()
                .fill(Color.black.opacity(0.55))

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .kmiIconSize(.tiny)
            } else {
                Text(String(initials))
                    .kmiTypography(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.horizontal, 4)
            }
        }
        .foregroundStyle(Color.white)
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private func userTexts(
        _ user: AdminUser
    ) -> some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 6
        ) {
            HStack(spacing: 8) {
                let name = displayName(for: user)

                Text(name)
                    .kmiTypography(.cardTitle)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                userAvatar(
                    displayName: name,
                    accentColor: userBeltAccentColor(user)
                )
            }
            .environment(\.layoutDirection, screenLayoutDirection)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    roleBadge(user)
                    activityBadge(user)
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 4) {
                    roleBadge(user)
                    activityBadge(user)
                }
            }
            .frame(maxWidth: .infinity, alignment: isEnglish ? .leading : .trailing)
            .environment(\.layoutDirection, screenLayoutDirection)

            if !demoPrivacy.isEnabled,
               !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                Text(user.email)
                    .kmiTypography(.secondary)
                    .foregroundStyle(secondaryTextColor)
                    .frame(
                        maxWidth: .infinity,
                        alignment: isEnglish ? .leading : .trailing
                    )
                    .multilineTextAlignment(
                        isEnglish ? .leading : .trailing
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }

            if !demoPrivacy.isEnabled,
               !user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                Text(
                    isEnglish
                        ? "Phone: \(user.phone)"
                        : "טלפון: \(user.phone)"
                )
                .kmiTypography(.secondary)
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
                )
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            }

            Text(
                user.branchGroupLine(
                    isEnglish: isEnglish
                )
            )
            .kmiTypography(.secondary)
            .foregroundStyle(secondaryTextColor)
            .frame(
                maxWidth: .infinity,
                alignment: isEnglish ? .leading : .trailing
            )
            .multilineTextAlignment(
                isEnglish ? .leading : .trailing
            )
            .lineLimit(3)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(userMetaLine(user))
                .kmiTypography(.secondary)
                .foregroundStyle(secondaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
                )
                .lineLimit(3)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: isEnglish ? .leading : .trailing
        )
    }

    private func roleBadge(
        _ user: AdminUser
    ) -> some View {
        let access = user.accessType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let badgeRole = access == "both" ? "coach" : (access ?? user.role)

        return HStack(spacing: 5) {
            Image(systemName: roleIcon(badgeRole))
                .resizable()
                .scaledToFit()
                .kmiIconSize(.tiny)

            Text(accessTextForUi(access))
                .kmiTypography(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(roleColor(badgeRole))
        )
        .overlay(
            Capsule()
                .stroke(
                    Color.white.opacity(0.18),
                    lineWidth: 1
                )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func roleIcon(_ role: String) -> String {
        if AdminUser.isAdminRole(role) {
            return "person.badge.key.fill"
        }

        if AdminUser.isCoachRole(role) {
            return "figure.martial.arts"
        }

        return "person.fill"
    }

    private func roleColor(_ role: String) -> Color {
        if AdminUser.isAdminRole(role) {
            return Color.purple.opacity(0.92)
        }

        if AdminUser.isCoachRole(role) {
            return Color.blue.opacity(0.92)
        }

        return Color.green.opacity(0.88)
    }

    private func activityBadge(_ user: AdminUser) -> some View {
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1_000)
        let activeWindowMillis: Int64 = 30 * 24 * 60 * 60 * 1_000
        let activeFromMillis = nowMillis - activeWindowMillis

        let isActive = user.lastSeenAtMillis.map {
            (activeFromMillis...nowMillis).contains($0)
        } ?? false

        let color: Color = isActive ? .green : .red
        let label = isActive
            ? tr("פעיל", "Active")
            : tr("לא פעיל", "Inactive")

        return HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(label)
                .kmiTypography(.caption)
                .foregroundStyle(primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
    }

    private func userMetaLine(_ user: AdminUser) -> String {
        var parts: [String] = []

        let belt = beltLabel(user.currentBeltId)

        if !belt.isEmpty {
            parts.append(isEnglish ? "Belt: \(belt)" : "חגורה: \(belt)")
        }

        if let age = user.age {
            parts.append(isEnglish ? "Age: \(age)" : "גיל: \(age)")
        }

        let region = user.region.trimmingCharacters(in: .whitespacesAndNewlines)

        if !region.isEmpty {
            parts.append(isEnglish ? "Region: \(region)" : "אזור: \(region)")
        }

        if user.appOpenCount > 0 {
            parts.append(isEnglish ? "Opens: \(user.appOpenCount)" : "שימושים: \(user.appOpenCount)")
        }

        if parts.isEmpty {
            return isEnglish ? "No additional details" : "אין פרטים נוספים"
        }

        return parts.joined(separator: " • ")
    }

    private func genderLabel(_ raw: String) -> String {
        if isMaleGender(raw) {
            return tr("זכר", "Male")
        }

        if isFemaleGender(raw) {
            return tr("נקבה", "Female")
        }

        return tr("לא ידוע", "Unknown")
    }

    private func isMaleGender(_ raw: String) -> Bool {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "m" ||
            clean == "male" ||
            clean == "זכר" ||
            clean.hasPrefix("m")
    }

    private func isFemaleGender(_ raw: String) -> Bool {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "f" ||
            clean == "female" ||
            clean == "נקבה" ||
            clean.hasPrefix("f")
    }

    private var orderedBeltIds: [String] {
        [
            "",
            "white",
            "yellow",
            "orange",
            "green",
            "blue",
            "brown",
            "black",
            "black_dan_2",
            "black_dan_3",
            "black_dan_4",
            "black_dan_5",
            "black_dan_6",
            "black_dan_7",
            "black_dan_8",
            "black_dan_9",
            "black_dan_10"
        ]
    }

    private var beltDistributionItems: [BeltDistributionItem] {
        let rawCounts = Dictionary(
            grouping: users,
            by: { $0.currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        .mapValues { $0.count }

        return orderedBeltIds.compactMap { rawId in
            let label = rawId.isEmpty
                ? tr("ללא חגורה", "No belt")
                : beltLabel(rawId)

            guard !label.isEmpty else {
                return nil
            }

            let count: Int

            if rawId.isEmpty {
                count = users.filter {
                    $0.currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
            } else {
                count = rawCounts[rawId] ?? 0
            }

            if count == 0 && rawId != "" {
                return nil
            }

            return BeltDistributionItem(
                id: rawId.isEmpty ? "no_belt" : rawId,
                label: label,
                count: count,
                color: beltColor(rawId)
            )
        }
    }

    private func beltLabel(_ rawId: String) -> String {
        let clean = rawId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch clean {
        case "white":
            return tr("לבנה", "White")
        case "yellow":
            return tr("צהובה", "Yellow")
        case "orange":
            return tr("כתומה", "Orange")
        case "green":
            return tr("ירוקה", "Green")
        case "blue":
            return tr("כחולה", "Blue")
        case "brown":
            return tr("חומה", "Brown")
        case "black", "שחורה", "שחורה דאן 1":
            return tr("שחורה דאן 1", "Black Dan 1")
        case "black_dan_2":
            return tr("שחורה דאן 2", "Black Dan 2")
        case "black_dan_3":
            return tr("שחורה דאן 3", "Black Dan 3")
        case "black_dan_4":
            return tr("שחורה דאן 4", "Black Dan 4")
        case "black_dan_5":
            return tr("שחורה דאן 5", "Black Dan 5")
        case "black_dan_6":
            return tr("שחורה דאן 6", "Black Dan 6")
        case "black_dan_7":
            return tr("שחורה דאן 7", "Black Dan 7")
        case "black_dan_8":
            return tr("שחורה דאן 8", "Black Dan 8")
        case "black_dan_9":
            return tr("שחורה דאן 9", "Black Dan 9")
        case "black_dan_10":
            return tr("שחורה דאן 10", "Black Dan 10")
        default:
            return ""
        }
    }

    private func beltColor(_ rawId: String) -> Color {
        let clean = rawId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch clean {
        case "white", "":
            return Color.white.opacity(0.92)
        case "yellow":
            return Color.yellow.opacity(0.92)
        case "orange":
            return Color.orange.opacity(0.92)
        case "green":
            return Color.green.opacity(0.88)
        case "blue":
            return Color.blue.opacity(0.92)
        case "brown":
            return Color(red: 0.50, green: 0.27, blue: 0.12).opacity(0.94)
        default:
            return Color.black.opacity(0.92)
        }
    }

    private func ageBucketLabel(_ bucket: String) -> String {
        if bucket == "לא ידוע" {
            return tr("לא ידוע", "Unknown")
        }

        return bucket
    }

    private func ageBucketSortIndex(_ bucket: String) -> Int {
        switch bucket {
        case "0–12":
            return 0
        case "13–17":
            return 1
        case "18–25":
            return 2
        case "26–40":
            return 3
        case "41–60":
            return 4
        case "60+":
            return 5
        default:
            return 99
        }
    }

    // MARK: PDF

    @MainActor
    private func exportUsersPdf() {
        guard !loading, !filteredUsers.isEmpty else {
            return
        }

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 36
        let contentWidth = page.width - margin * 2
        let contentTop = KmiPdfHeader.CONTENT_TOP
        let contentBottom = page.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = isEnglish ? .left : .right
        paragraph.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft
        paragraph.lineBreakMode = .byWordWrapping

        let visibleUsers = filteredUsers.filter {
            !AdminUser.isAdminRole($0.role)
        }
        let adminUsers = selectedRole == .all
            ? filteredUsers.filter { AdminUser.isAdminRole($0.role) }
            : []

        let sections: [(title: String, users: [AdminUser])] = [
            (tr("מתאמנים", "Trainees"), visibleUsers.filter { userCategory($0) == .trainee }),
            (tr("מאמנים", "Coaches"), visibleUsers.filter { userCategory($0) == .coach }),
            (tr("מתאמנים + מאמנים", "Trainees + Coaches"), visibleUsers.filter { userCategory($0) == .both }),
            (tr("מנהלים", "Admins"), adminUsers)
        ]

        let reportUsers = visibleUsers + adminUsers
        let userCount = reportUsers.count
        let summary = tr("משתמשים בדוח: \(userCount)", "Users in report: \(userCount)")
        let isDemo = demoPrivacy.isEnabled

        let branches = reportUsers.flatMap { user in
            user.branches + [user.branch]
        }
        let branchCount = Set(branches.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty && $0 != "-" && $0 != "—" }).count

        let ages = reportUsers.compactMap(\.age)
        let averageAge = ages.averageValue.map {
            $0.formatted(.number.precision(.fractionLength(1)))
        } ?? "—"
        let appOpens = reportUsers.reduce(0) { $0 + $1.appOpenCount }
        let usersWithAppOpens = reportUsers.count { $0.appOpenCount > 0 }

        let beltCountsById = Dictionary(grouping: reportUsers) { user in
            user.currentBeltId.trimmingCharacters(in: .whitespacesAndNewlines)
        }.mapValues(\.count)

        let filters = activeFilterLabels

        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { renderer in
            let graphics = renderer.cgContext
            var pageNumber = 0
            var y = contentTop

            func drawFooter() {
                KmiPdfFooter.draw(
                    context: graphics,
                    pageWidth: page.width,
                    pageHeight: page.height,
                    pageNumber: pageNumber,
                    isEnglish: isEnglish
                )
            }

            func beginPage() {
                if pageNumber > 0 {
                    drawFooter()
                }

                renderer.beginPage()
                pageNumber += 1

                KmiPdfHeader.draw(
                    context: graphics,
                    pageWidth: page.width,
                    isEnglish: isEnglish,
                    titleHebrew: "דוח ניהול משתמשים",
                    titleEnglish: "User Management Report",
                    subtitleHebrew: summary,
                    subtitleEnglish: summary
                )

                y = contentTop
            }

            func drawText(_ text: String, font: UIFont, spacing: CGFloat) {
                let attributed = NSAttributedString(
                    string: text,
                    attributes: [
                        .font: font,
                        .foregroundColor: UIColor.black,
                        .paragraphStyle: paragraph
                    ]
                )

                let options: NSStringDrawingOptions = [
                    .usesLineFragmentOrigin,
                    .usesFontLeading
                ]
                let bounds = attributed.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: options,
                    context: nil
                )
                let maxHeight = contentBottom - contentTop - spacing
                let height = min(ceil(bounds.height) + 2, maxHeight)

                if y + height + spacing > contentBottom {
                    beginPage()
                }

                attributed.draw(
                    with: CGRect(x: margin, y: y, width: contentWidth, height: height),
                    options: options.union(.truncatesLastVisibleLine),
                    context: nil
                )
                y += height + spacing
            }

            func drawSectionTitle(_ title: String) {
                if y + 70 > contentBottom {
                    beginPage()
                }

                drawText(title, font: .boldSystemFont(ofSize: 15), spacing: 8)
            }

            beginPage()

            if !isDemo {
                drawSectionTitle(tr("סיכום", "Summary"))

                let summaryLines = [
                    tr("כל המשתמשים: \(users.count)", "Total users: \(users.count)"),
                    tr("משתמשים מסוננים: \(userCount)", "Filtered users: \(userCount)"),
                    tr("סניפים: \(branchCount)", "Branches: \(branchCount)"),
                    tr("גיל ממוצע: \(averageAge)", "Average age: \(averageAge)"),
                    tr("פתיחות אפליקציה: \(appOpens)", "App opens: \(appOpens)"),
                    tr(
                        "משתמשים שפתחו את האפליקציה: \(usersWithAppOpens)",
                        "Users who opened the app: \(usersWithAppOpens)"
                    )
                ]

                drawText(
                    summaryLines.joined(separator: "\n"),
                    font: .systemFont(ofSize: 11),
                    spacing: 14
                )

                drawSectionTitle(tr("מסננים פעילים", "Active filters"))
                drawText(
                    filters.isEmpty
                        ? tr("אין מסננים פעילים", "No active filters")
                        : filters.joined(separator: " • "),
                    font: .systemFont(ofSize: 11),
                    spacing: 14
                )

                drawSectionTitle(tr("חלוקה לפי חגורה", "Belt distribution"))
                for beltId in orderedBeltIds {
                    let label = beltId.isEmpty
                        ? tr("ללא חגורה", "No belt")
                        : beltLabel(beltId)
                    let count = beltCountsById[beltId, default: 0]

                    drawText(
                        "\(label) — \(count)",
                        font: .systemFont(ofSize: 11),
                        spacing: 6
                    )
                }
            }

            for section in sections where !section.users.isEmpty {
                if y + 70 > contentBottom {
                    beginPage()
                }

                drawText(
                    "\(section.title) (\(section.users.count))",
                    font: .boldSystemFont(ofSize: 15),
                    spacing: 8
                )

                for user in section.users {
                    let name = displayName(for: user)
                    let text = isDemo
                        ? name
                        : [
                            name,
                            accessTextForUi(user.accessType),
                            user.branchGroupLine(isEnglish: isEnglish),
                            userMetaLine(user)
                        ].joined(separator: "\n")

                    drawText(text, font: .systemFont(ofSize: 11), spacing: 10)
                }
            }

            if !isDemo, !unlikeQuestions.isEmpty {
                drawSectionTitle(
                    tr("שאלות שסומנו UNLIKE", "Questions marked UNLIKE")
                )

                for (index, item) in unlikeQuestions.prefix(20).enumerated() {
                    drawText(
                        "\(index + 1). \(item.question)",
                        font: .boldSystemFont(ofSize: 11),
                        spacing: 5
                    )

                    let answer = item.answer.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )

                    if !answer.isEmpty {
                        drawText(
                            answer,
                            font: .systemFont(ofSize: 11),
                            spacing: 10
                        )
                    }
                }
            }

            drawFooter()
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdminUsersReports", isDirectory: true)
        let filename = tr("דוח ניהול משתמשים.pdf", "User Management Report.pdf")
        let url = directory.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            usersPdfShare = AdminUsersPdfShare(url: url)
        } catch {
            showUsersPdfError = true
        }
    }

    // MARK: Firestore

    private func openUserAccess(_ user: AdminUser) {
        guard !isSavingUserAccess, user.accessTargetUid != nil else {
            return
        }

        switch userCategory(user) {
        case .coach:
            selectedAccessType = "coach"
        case .both:
            selectedAccessType = "both"
        case .all, .trainee:
            selectedAccessType = "trainee"
        }

        userAccessSaveError = nil
        accessUser = user
    }

    @MainActor
    private func saveUserAccess(_ user: AdminUser, accessType: String) async {
        guard !isSavingUserAccess, let uid = user.accessTargetUid else {
            return
        }

        isSavingUserAccess = true
        userAccessSaveError = nil
        showUserAccessSaved = false
        defer { isSavingUserAccess = false }

        let saveError = tr(
            "שמירת ההרשאה נכשלה. בדוק את החיבור והרשאות המנהל ונסה שוב.",
            "Unable to save access. Check your connection and administrator access, then try again."
        )

        do {
            let result = try await Functions.functions(region: "europe-west1")
                .httpsCallable("setKamiUserAccess")
                .call(["uid": uid, "accessType": accessType])

            guard let response = result.data as? [String: Any],
                  response["accepted"] as? Bool == true else {
                userAccessSaveError = saveError
                return
            }

            accessUser = nil
            showUserAccessSaved = true
            loadUsers()
        } catch {
            userAccessSaveError = saveError
        }
    }

    private func loadUsers() {

        loading = true
        errorMessage = nil
        loadUnlikeQuestions()

        Firestore.firestore()
            .collection("users")
            .getDocuments { snapshot, error in

                loading = false

                if let error {
                    let rawMessage = error.localizedDescription

                    if rawMessage.uppercased().contains("PERMISSION_DENIED") {
                        errorMessage = tr(
                            "אין לך הרשאה לצפות ברשימת המשתמשים. בדוק את הרשאות Firestore או פנה למנהל המערכת.",
                            "You do not have permission to view the users list. Check Firestore permissions or contact the system administrator."
                        )
                    } else {
                        errorMessage = rawMessage.isEmpty
                            ? tr("שגיאה בטעינת המשתמשים", "Error loading users")
                            : rawMessage
                    }

                    users = []
                    filteredUsers = []
                    return
                }

                guard let docs = snapshot?.documents else {
                    errorMessage = tr("לא התקבלו נתוני משתמשים מהשרת", "No user data was received from the server")
                    users = []
                    filteredUsers = []
                    return
                }

                let rawUsers = docs
                    .compactMap { doc in
                        AdminUser.from(
                            id: doc.documentID,
                            map: doc.data()
                        )
                    }
                    .filter { user in
                        user.hasRealAdminListContent
                    }

                let linkedUsers = AdminUser.linkingLegacyRecords(rawUsers)

                users = AdminUser.mergingMatchingContacts(linkedUsers).sorted {
                    $0.fullName.localizedCaseInsensitiveCompare(
                        $1.fullName
                    ) == .orderedAscending
                }


                errorMessage = nil
                applyFilter()
            }
    }

    private func loadUnlikeQuestions() {

        Firestore.firestore()
            .collection("assistantFeedback")
            .whereField("liked", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, _ in

                guard let docs = snapshot?.documents else {
                    unlikeQuestions = []
                    return
                }

                unlikeQuestions = docs.compactMap { doc in
                    AssistantFeedbackQuestion.from(
                        id: doc.documentID,
                        map: doc.data()
                    )
                }
            }
    }

    // MARK: Filter logic

    private func userCategory(_ user: AdminUser) -> UserRoleFilter {
        let accessType = (user.accessType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch accessType {
        case "both":
            return .both
        case "coach":
            return .coach
        case "trainee":
            return .trainee
        default:
            return user.isCoach ? .coach : .trainee
        }
    }

    private func applyFilter() {
        var result = users

        if selectedRole != .all {
            result = result.filter { userCategory($0) == selectedRole }
        }

        if selectedGender != .all {
            result = result.filter { user in
                let cleanGender = user.gender
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                switch selectedGender {
                case .all:
                    return true

                case .male:
                    return cleanGender == "m" ||
                        cleanGender == "male" ||
                        cleanGender == "זכר" ||
                        cleanGender.hasPrefix("m")

                case .female:
                    return cleanGender == "f" ||
                        cleanGender == "female" ||
                        cleanGender == "נקבה" ||
                        cleanGender.hasPrefix("f")
                }
            }
        }

        if let selectedRegion {
            result = result.filter { user in
                user.region.caseInsensitiveCompare(selectedRegion) == .orderedSame
            }
        }

        if let selectedBelt {
            result = result.filter { user in
                beltLabel(user.currentBeltId).caseInsensitiveCompare(selectedBelt) == .orderedSame
            }
        }

        if let selectedAgeBucket {
            result = result.filter { user in
                user.ageBucket == selectedAgeBucket
            }
        }

        let query = normalizedSearchText

        if !query.isEmpty {

            result = result.filter { user in
                user.fullName.localizedCaseInsensitiveContains(query) ||
                user.email.localizedCaseInsensitiveContains(query) ||
                user.phone.localizedCaseInsensitiveContains(query) ||
                user.region.localizedCaseInsensitiveContains(query) ||
                user.branch.localizedCaseInsensitiveContains(query) ||
                user.branches.joined(separator: " ").localizedCaseInsensitiveContains(query) ||
                user.group.localizedCaseInsensitiveContains(query) ||
                user.groups.joined(separator: " ").localizedCaseInsensitiveContains(query) ||
                user.currentBeltId.localizedCaseInsensitiveContains(query) ||
                beltLabel(user.currentBeltId).localizedCaseInsensitiveContains(query) ||
                user.role.localizedCaseInsensitiveContains(query) ||
                accessTextForUi(user.accessType).localizedCaseInsensitiveContains(query) ||
                user.branchGroupLine(isEnglish: isEnglish).localizedCaseInsensitiveContains(query)
            }
        }

        filteredUsers = result
    }

    private func clearAllFilters() {
        searchText = ""
        resetFilterSelections()
        applyFilter()
    }

    private func resetFilterSelections() {
        selectedRole = .all
        selectedGender = .all
        selectedRegion = nil
        selectedBelt = nil
        selectedAgeBucket = nil
    }
}

private struct AdminUsersPdfShare: Identifiable {
    let id = UUID()
    let url: URL
}

enum UserRoleFilter {
    case all
    case coach
    case trainee
    case both
}

struct AdminUser: Identifiable {

    let id: String

    let uidField: String
    let fullName: String
    let email: String
    let phone: String

    let gender: String
    let birthDay: Int?
    let birthMonth: Int?
    let birthYear: Int?

    let region: String
    let branch: String
    let branches: [String]

    let group: String
    let groups: [String]

    let currentBeltId: String
    let role: String
    let isCoachFlag: Bool
    var accessType: String? = nil
    var accessTargetUid: String? = nil
    var hasConflictingAccessAccounts = false
    let createdAtMillis: Int64?

    static func resolveAccessTargetUid(id: String, uidField: String) -> String? {
        let documentUid = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let declaredUid = uidField.trimmingCharacters(in: .whitespacesAndNewlines)

        guard documentUid.range(
            of: #"^[A-Za-z0-9_-]{10,128}$"#,
            options: .regularExpression
        ) != nil,
        declaredUid.isEmpty || declaredUid == documentUid else {
            return nil
        }

        return documentUid
    }
    let appOpenCount: Int
    let lastSeenAtMillis: Int64?

    var age: Int? {
        guard let birthYear else {
            return nil
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let roughAge = currentYear - birthYear

        return (0...120).contains(roughAge) ? roughAge : nil
    }

    var ageBucket: String {
        guard let age else {
            return "לא ידוע"
        }

        switch age {
        case 0...12:
            return "0–12"
        case 13...17:
            return "13–17"
        case 18...25:
            return "18–25"
        case 26...40:
            return "26–40"
        case 41...60:
            return "41–60"
        default:
            return "60+"
        }
    }

    var isCoach: Bool {
        if isCoachFlag {
            return true
        }

        if AdminUser.isCoachRole(role) {
            return true
        }

        let groupsText = groups.joined(separator: " ").lowercased()

        return groupsText.contains("מאמן") ||
            groupsText.contains("מאמנים") ||
            groupsText.contains("coach") ||
            groupsText.contains("coaches") ||
            groupsText.contains("trainer")
    }

    static func from(id: String, map: [String: Any]) -> AdminUser? {

        func stringValue(_ keys: String...) -> String {
            for key in keys {
                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        return clean
                    }
                }

                if let value = map[key], !(value is NSNull) {
                    let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty && clean.lowercased() != "null" {
                        return clean
                    }
                }
            }

            return ""
        }

        func intValue(_ keys: String...) -> Int? {
            for key in keys {
                if let value = map[key] as? Int {
                    return value
                }

                if let value = map[key] as? Int64 {
                    return Int(value)
                }

                if let value = map[key] as? Double {
                    return Int(value)
                }

                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let intValue = Int(clean) {
                        return intValue
                    }
                }
            }

            return nil
        }

        func boolValue(_ keys: String...) -> Bool {
            for key in keys {
                if let value = map[key] as? Bool {
                    return value
                }

                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if clean == "true" || clean == "1" || clean == "yes" {
                        return true
                    }

                    if clean == "false" || clean == "0" || clean == "no" {
                        return false
                    }
                }

                if let value = map[key] as? Int {
                    return value == 1
                }

                if let value = map[key] as? Double {
                    return value == 1
                }
            }

            return false
        }

        func millisValue(_ keys: String...) -> Int64? {
            for key in keys {
                let value = map[key]

                let rawMillis: Int64?

                if let timestamp = value as? Timestamp {
                    rawMillis = Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
                } else if let value = value as? Int64 {
                    rawMillis = value
                } else if let value = value as? Int {
                    rawMillis = Int64(value)
                } else if let value = value as? Double {
                    rawMillis = Int64(value)
                } else if let value = value as? String {
                    rawMillis = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    rawMillis = nil
                }

                guard let rawMillis else {
                    continue
                }

                let millis: Int64

                if rawMillis >= 1_000_000_000 && rawMillis <= 9_999_999_999 {
                    millis = rawMillis * 1000
                } else {
                    millis = rawMillis
                }

                let minReasonableMillis: Int64 = 1_577_836_800_000
                let maxReasonableMillis: Int64 = Int64(Date().addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970 * 1000)

                if millis >= minReasonableMillis && millis <= maxReasonableMillis {
                    return millis
                }
            }

            return nil
        }

        func stringListValue(_ keys: String...) -> [String] {
            for key in keys {
                if let list = map[key] as? [String] {
                    let cleanList = list
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }

                if let list = map[key] as? [Any] {
                    let cleanList = list
                        .map { "\($0)".trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && $0.lowercased() != "null" }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }

                if let value = map[key] as? String {
                    let cleanList = value
                        .split { char in
                            char == "," || char == "•" || char == "|" || char == ";"
                        }
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if !cleanList.isEmpty {
                        return cleanList
                    }
                }
            }

            return []
        }

        let fullName = stringValue(
            "fullName",
            "full_name",
            "name",
            "displayName",
            "userName",
            "username"
        )

        let email = stringValue("email")

        let phone = stringValue(
            "phone",
            "phoneNumber",
            "phone_number"
        )

        let uidField = stringValue(
            "uid",
            "userId",
            "user_id",
            "firebaseUid",
            "firebase_uid",
            "authUid",
            "auth_uid"
        )

        let branchesArray = stringListValue(
            "branches",
            "branchNames",
            "selectedBranches",
            "selectedBranchNames",
            "trainingBranches",
            "trainingBranchNames",
            "clubs",
            "dojos"
        )

        let groupsArray = stringListValue(
            "groups",
            "groupNames",
            "groupsCsv",
            "groupCsv",
            "selectedGroups",
            "selectedGroupNames"
        )

        let singleRegion = stringValue(
            "region",
            "area",
            "selectedRegion",
            "trainingRegion"
        )

        let singleBranch = stringValue(
            "activeBranch",
            "active_branch",
            "branch",
            "branchName",
            "selectedBranch",
            "selectedBranchName",
            "trainingBranch",
            "trainingBranchName",
            "club",
            "dojo",
            "branchesCsv"
        )

        let singleGroup = stringValue(
            "primaryGroup",
            "activeGroup",
            "active_group",
            "groupKey",
            "group_key",
            "group",
            "groupName",
            "age_group",
            "ageGroup"
        )

        let resolvedBranch = branchesArray.first ?? singleBranch
        let resolvedGroup = groupsArray.first ?? singleGroup

        let rawRole = stringValue(
            "role",
            "userRole",
            "user_role",
            "profile_role",
            "accountRole",
            "userType",
            "type"
        )

        let isCoachFlag = boolValue(
            "isCoach",
            "coach",
            "isTrainer",
            "trainer",
            "isInstructor",
            "instructor"
        )

        let resolvedRole: String

        if !rawRole.isEmpty {
            resolvedRole = rawRole
        } else if boolValue("isAdmin", "admin", "isManager", "manager") {
            resolvedRole = "admin"
        } else if isCoachFlag {
            resolvedRole = "coach"
        } else {
            let groupsText = groupsArray.joined(separator: " ").lowercased()

            if groupsText.contains("מאמן") ||
                groupsText.contains("מאמנים") ||
                groupsText.contains("coach") ||
                groupsText.contains("coaches") ||
                groupsText.contains("trainer") {
                resolvedRole = "coach"
            } else {
                resolvedRole = "trainee"
            }
        }

        var birthYear = intValue("birthYear")
        var birthMonth = intValue("birthMonth")
        var birthDay = intValue("birthDay")

        let birthDate = stringValue("birthDate")

        if !birthDate.isEmpty {
            let parts = birthDate.split(separator: "-").map { String($0) }

            if parts.count == 3 {
                if birthYear == nil {
                    birthYear = Int(parts[0])
                }

                if birthMonth == nil {
                    birthMonth = Int(parts[1])
                }

                if birthDay == nil {
                    birthDay = Int(parts[2])
                }
            }
        }

        let fallbackName: String

        if !fullName.isEmpty {
            fallbackName = fullName
        } else if !email.isEmpty {
            fallbackName = email
        } else if !phone.isEmpty {
            fallbackName = phone
        } else {
            fallbackName = ""
        }

        let currentBeltId = stringValue(
            "currentBeltId",
            "currentBelt",
            "belt_current",
            "beltId",
            "belt"
        )

        let cleanDisplayName = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneDigits = phone.filter { $0.isNumber }

        let hasHumanIdentifier =
            !cleanDisplayName.isEmpty ||
            !cleanEmail.isEmpty ||
            !cleanPhoneDigits.isEmpty

        guard hasHumanIdentifier else {
            return nil
        }

        return AdminUser(
            id: id,
            uidField: uidField,
            fullName: cleanDisplayName.isEmpty ? "-" : cleanDisplayName,
            email: email,
            phone: phone,
            gender: stringValue("gender", "sex"),
            birthDay: birthDay,
            birthMonth: birthMonth,
            birthYear: birthYear,
            region: singleRegion,
            branch: resolvedBranch,
            branches: branchesArray,
            group: resolvedGroup,
            groups: groupsArray,
            currentBeltId: currentBeltId,
            role: resolvedRole,
            isCoachFlag: isCoachFlag,
            accessType: map["accessType"] as? String,
            accessTargetUid: resolveAccessTargetUid(id: id, uidField: uidField),
            createdAtMillis: millisValue("createdAtMillis", "createdAt"),
            appOpenCount: intValue("appOpenCount") ?? 0,
            lastSeenAtMillis: millisValue("lastSeenAtMillis", "lastSeenAt")
        )
    }

    static func merged(
        existing: AdminUser,
        incoming: AdminUser,
        preservingAccountIdentity: Bool = false
    ) -> AdminUser {
        AdminUser(
            id: existing.id,
            uidField: preservingAccountIdentity
                ? existing.uidField
                : betterText(existing.uidField, incoming.uidField),
            fullName: betterText(existing.fullName, incoming.fullName),
            email: betterText(existing.email, incoming.email),
            phone: betterText(existing.phone, incoming.phone),
            gender: betterText(existing.gender, incoming.gender),
            birthDay: existing.birthDay ?? incoming.birthDay,
            birthMonth: existing.birthMonth ?? incoming.birthMonth,
            birthYear: existing.birthYear ?? incoming.birthYear,
            region: betterText(existing.region, incoming.region),
            branch: betterText(existing.branch, incoming.branch),
            branches: betterList(existing.branches, incoming.branches),
            group: betterText(existing.group, incoming.group),
            groups: betterList(existing.groups, incoming.groups),
            currentBeltId: betterText(existing.currentBeltId, incoming.currentBeltId),
            role: preservingAccountIdentity
                ? existing.role
                : betterRole(existing.role, incoming.role),
            isCoachFlag: preservingAccountIdentity
                ? existing.isCoachFlag
                : (existing.isCoachFlag || incoming.isCoachFlag),
            accessType: existing.accessType,
            accessTargetUid: preservingAccountIdentity ||
                    existing.accessTargetUid == incoming.accessTargetUid
                ? existing.accessTargetUid
                : nil,
            createdAtMillis: newerMillis(existing.createdAtMillis, incoming.createdAtMillis),
            appOpenCount: max(existing.appOpenCount, incoming.appOpenCount),
            lastSeenAtMillis: newerMillis(existing.lastSeenAtMillis, incoming.lastSeenAtMillis)
        )
    }

    static func linkingLegacyRecords(_ users: [AdminUser]) -> [AdminUser] {
        let verifiedUsers = users.filter { $0.accessTargetUid != nil }

        let legacyGroups = Dictionary(
            grouping: users.filter { $0.accessTargetUid == nil }
        ) { user -> String in
            guard let identity = user.legacyDisplayIdentity else {
                return "document:\(user.id)"
            }

            let declaredUid = user.uidField
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return "legacy:\(identity)|uid:\(declaredUid)"
        }

        let legacyUsers = legacyGroups.values.compactMap { records -> AdminUser? in
            guard let first = records.first else { return nil }

            return records.dropFirst().reduce(first) { result, record in
                merged(existing: result, incoming: record)
            }
        }

        let verifiedByIdentity = Dictionary(grouping: verifiedUsers) {
            $0.legacyDisplayIdentity
        }
        let legacyByIdentity = Dictionary(grouping: legacyUsers) {
            $0.legacyDisplayIdentity
        }

        var linkedLegacyIds = Set<String>()

        let combinedVerifiedUsers = verifiedUsers.map { verified in
            guard let uid = verified.accessTargetUid,
                  let identity = verified.legacyDisplayIdentity,
                  verifiedByIdentity[identity]?.count == 1,
                  let candidates = legacyByIdentity[identity] else {
                return verified
            }

            let matches = candidates.filter { legacy in
                let declaredUid = legacy.uidField
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return declaredUid.isEmpty || declaredUid == uid
            }

            guard !matches.isEmpty else {
                return verified
            }

            linkedLegacyIds.formUnion(matches.map(\.id))

            return matches.reduce(verified) { result, legacy in
                merged(
                    existing: result,
                    incoming: legacy,
                    preservingAccountIdentity: true
                )
            }
        }

        return combinedVerifiedUsers + legacyUsers.filter {
            !linkedLegacyIds.contains($0.id)
        }
    }

    private var legacyDisplayIdentity: String? {
        let name = fullName
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()

        let email = normalizedMergeEmail
        let phone = normalizedMergePhone

        guard !name.isEmpty,
              name != "-",
              !name.hasPrefix("unknown user"),
              !email.isEmpty || !phone.isEmpty else {
            return nil
        }

        return "\(name)|\(email)|\(phone)"
    }

    static func mergingMatchingContacts(_ users: [AdminUser]) -> [AdminUser] {
        let groups = Dictionary(grouping: users) { user in
            let email = user.normalizedMergeEmail
            let phone = user.normalizedMergePhone

            guard !email.isEmpty, !phone.isEmpty else {
                return "document:\(user.id)"
            }

            return "contact:\(email)|\(phone)"
        }

        return groups.values.flatMap { records -> [AdminUser] in
            guard records.count > 1, let first = records.first else {
                return records
            }

            let verifiedUids = Set(records.compactMap(\.accessTargetUid))
            let hasConflictingAccounts = verifiedUids.count > 1
            let safeUid = verifiedUids.count == 1 ? verifiedUids.first : nil

            let primary = records.first { record in
                record.accessTargetUid != nil && record.accessTargetUid == safeUid
            } ?? first

            var combined = records
                .filter { $0.id != primary.id }
                .reduce(primary) { result, record in
                    merged(existing: result, incoming: record)
                }

            let explicitAccessTypes = Set(records.compactMap { record -> String? in
                let value = record.accessType?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()

                switch value {
                case "trainee", "coach", "both":
                    return value
                default:
                    return nil
                }
            })

            combined.accessTargetUid = safeUid
            combined.hasConflictingAccessAccounts = hasConflictingAccounts
            combined.accessType = explicitAccessTypes.count == 1
                ? explicitAccessTypes.first
                : nil
            return [combined]
        }
    }

    func branchGroupLine(isEnglish: Bool) -> String {
        let branchText = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupText = group.trimmingCharacters(in: .whitespacesAndNewlines)

        if branchText.isEmpty && groupText.isEmpty {
            return isEnglish ? "No branch or group" : "ללא סניף או קבוצה"
        }

        if branchText.isEmpty {
            return isEnglish ? "Group: \(groupText)" : "קבוצה: \(groupText)"
        }

        if groupText.isEmpty {
            return isEnglish ? "Branch: \(branchText)" : "סניף: \(branchText)"
        }

        return isEnglish
            ? "Branch: \(branchText) • Group: \(groupText)"
            : "\(branchText) • \(groupText)"
    }

    private var normalizedMergeEmail: String {
        email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
            .replacingOccurrences(
                of: " ",
                with: ""
            )
    }

    private var normalizedMergePhone: String {
        let digits = phone.filter { $0.isNumber }

        if digits.hasPrefix("00972") {
            return "0" + String(digits.dropFirst(5))
        }

        if digits.hasPrefix("972") {
            return "0" + String(digits.dropFirst(3))
        }

        return digits
    }

    private var normalizedMergeUid: String {
        let storedUid = uidField
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if !storedUid.isEmpty {
            return storedUid
        }

        return id
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
    }

    func sharesIdentity(
        with other: AdminUser
    ) -> Bool {
        if let targetUid = accessTargetUid {
            return other.accessTargetUid == targetUid
        }

        if other.accessTargetUid != nil {
            return false
        }

        let firstEmail = normalizedMergeEmail
        let secondEmail = other.normalizedMergeEmail

        if !firstEmail.isEmpty &&
            firstEmail == secondEmail {
            return true
        }

        let firstPhone = normalizedMergePhone
        let secondPhone = other.normalizedMergePhone

        if !firstPhone.isEmpty &&
            firstPhone == secondPhone {
            return true
        }

        let firstUid = normalizedMergeUid
        let secondUid = other.normalizedMergeUid

        if !firstUid.isEmpty &&
            firstUid == secondUid {
            return true
        }

        return false
    }

    static func isAdminRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return clean == "admin" ||
            clean == "administrator" ||
            clean == "manager" ||
            clean.contains("admin") ||
            clean.contains("administrator") ||
            clean.contains("manager") ||
            clean.contains("מנהל") ||
            clean.contains("אדמין")
    }

    static func isCoachRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return clean == "coach" ||
            clean.contains("coach") ||
            clean.contains("trainer") ||
            clean.contains("instructor") ||
            clean.contains("מאמן") ||
            clean.contains("מדריך")
    }

    static func isTraineeRole(_ role: String) -> Bool {
        let clean = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if isAdminRole(clean) || isCoachRole(clean) {
            return false
        }

        return clean.isEmpty ||
            clean == "trainee" ||
            clean.contains("trainee") ||
            clean.contains("student") ||
            clean.contains("מתאמן") ||
            clean.contains("חניך")
    }

    var hasRealAdminListContent: Bool {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneDigits = phone.filter { $0.isNumber }

        if cleanName.isEmpty || cleanName == "-" {
            return !cleanEmail.isEmpty || !cleanPhoneDigits.isEmpty
        }

        if cleanName.lowercased().hasPrefix("unknown user") &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty {
            return false
        }

        if AdminUser.normalizedHumanNameKey(cleanName).isEmpty &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty {
            return false
        }

        return true
    }

    private static func betterText(_ first: String, _ second: String) -> String {
        let cleanFirst = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecond = second.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanFirst.isEmpty || cleanFirst == "-" {
            return cleanSecond
        }

        if cleanSecond.isEmpty || cleanSecond == "-" {
            return cleanFirst
        }

        let firstLooksLikeUid = normalizedHumanNameKey(cleanFirst).isEmpty
        let secondLooksLikeUid = normalizedHumanNameKey(cleanSecond).isEmpty

        if firstLooksLikeUid && !secondLooksLikeUid {
            return cleanSecond
        }

        if secondLooksLikeUid && !firstLooksLikeUid {
            return cleanFirst
        }

        return cleanSecond.count > cleanFirst.count ? cleanSecond : cleanFirst
    }

    private static func betterList(_ first: [String], _ second: [String]) -> [String] {
        var result: [String] = []

        for item in first + second {
            let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)

            if !clean.isEmpty &&
                !result.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                result.append(clean)
            }
        }

        return result
    }

    private static func newerMillis(_ first: Int64?, _ second: Int64?) -> Int64? {
        guard let first else {
            return second
        }

        guard let second else {
            return first
        }

        return max(first, second)
    }

    private static func betterRole(_ first: String, _ second: String) -> String {
        let cleanFirst = first.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanSecond = second.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if isAdminRole(cleanFirst) || isAdminRole(cleanSecond) {
            return "admin"
        }

        if isCoachRole(cleanFirst) || isCoachRole(cleanSecond) {
            return "coach"
        }

        if isTraineeRole(cleanFirst) || isTraineeRole(cleanSecond) {
            return "trainee"
        }

        return cleanSecond.isEmpty ? cleanFirst : cleanSecond
    }

    private static func normalizedHumanNameKey(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !clean.isEmpty && clean != "-" else {
            return ""
        }

        if clean.hasPrefix("unknown user") {
            return ""
        }

        if clean.contains("@") {
            return ""
        }

        let lettersOnly = clean.filter { $0.isLetter }

        guard lettersOnly.count >= 2 else {
            return ""
        }

        let uidLikePattern = #"^[a-z0-9_-]{20,}$"#

        if clean.range(of: uidLikePattern, options: .regularExpression) != nil {
            return ""
        }

        return clean
            .replacingOccurrences(of: #"[\s\-_.]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == Int {

    var averageValue: Double? {
        guard !isEmpty else {
            return nil
        }

        let total = reduce(0, +)
        return Double(total) / Double(count)
    }
}

enum AdminGenderFilter {
    case all
    case male
    case female
}

struct BeltDistributionItem: Identifiable {
    let id: String
    let label: String
    let count: Int
    let color: Color
}

struct AssistantFeedbackQuestion: Identifiable {

    let id: String
    let question: String
    let answer: String
    let createdAtMillis: Int64?
    let userName: String
    let userUid: String

    static func from(id: String, map: [String: Any]) -> AssistantFeedbackQuestion? {

        func stringValue(_ keys: String...) -> String {
            for key in keys {
                if let value = map[key] as? String {
                    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        return clean
                    }
                }

                if let value = map[key], !(value is NSNull) {
                    let clean = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty && clean.lowercased() != "null" {
                        return clean
                    }
                }
            }

            return ""
        }

        func millisValue(_ keys: String...) -> Int64? {
            for key in keys {
                let value = map[key]

                let rawMillis: Int64?

                if let timestamp = value as? Timestamp {
                    rawMillis = Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
                } else if let value = value as? Int64 {
                    rawMillis = value
                } else if let value = value as? Int {
                    rawMillis = Int64(value)
                } else if let value = value as? Double {
                    rawMillis = Int64(value)
                } else if let value = value as? String {
                    rawMillis = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    rawMillis = nil
                }

                guard let rawMillis else {
                    continue
                }

                if rawMillis >= 1_000_000_000 && rawMillis <= 9_999_999_999 {
                    return rawMillis * 1000
                }

                return rawMillis
            }

            return nil
        }

        let question = stringValue("question", "prompt", "text")

        guard !question.isEmpty else {
            return nil
        }

        return AssistantFeedbackQuestion(
            id: id,
            question: question,
            answer: stringValue("answer", "response"),
            createdAtMillis: millisValue("createdAt", "createdAtMillis", "ts"),
            userName: stringValue("userName", "displayName", "name"),
            userUid: stringValue("userUid", "uid", "userId")
        )
    }

    func metaLine(isEnglish: Bool) -> String {
        var parts: [String] = []

        let cleanUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserUid = userUid.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanUserName.isEmpty {
            parts.append(cleanUserName)
        }

        if !cleanUserUid.isEmpty {
            parts.append(isEnglish ? "UID: \(cleanUserUid)" : "UID: \(cleanUserUid)")
        }

        return parts.joined(separator: " • ")
    }
}

private extension Array where Element == String {

    func uniqueCaseInsensitiveSorted() -> [String] {
        var result: [String] = []

        for item in self {
            let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clean.isEmpty else {
                continue
            }

            if !result.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                result.append(clean)
            }
        }

        return result.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}

