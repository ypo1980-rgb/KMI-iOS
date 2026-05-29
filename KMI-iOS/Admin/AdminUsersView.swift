import SwiftUI
import FirebaseFirestore

struct AdminUsersView: View {

    @State private var users: [AdminUser] = []
    @State private var filteredUsers: [AdminUser] = []

    @State private var searchText: String = ""
    @State private var selectedRole: UserRoleFilter = .all

    @State private var loading = true
    @State private var errorMessage: String? = nil

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

    private func roleTextForUi(_ role: String) -> String {
        if AdminUser.isAdminRole(role) {
            return tr("מנהל", "Admin")
        }

        if AdminUser.isCoachRole(role) {
            return tr("מאמן", "Coach")
        }

        return tr("מתאמן", "Trainee")
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {

        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.11),
                    Color(red: 0.07, green: 0.12, blue: 0.22),
                    Color(red: 0.08, green: 0.30, blue: 0.55),
                    Color(red: 0.03, green: 0.64, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {

                screenHeader

                headerStats

                roleFilter

                searchBar

                if let errorMessage, !errorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errorMessageCard(errorMessage)
                }

                if loading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)

                        Text(tr("טוען משתמשים מהשרת...", "Loading users from the server..."))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                } else if filteredUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text(tr("לא נמצאו משתמשים תואמים", "No matching users found"))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(tr("נסה לשנות חיפוש או סינון תפקיד", "Try changing the search or role filter"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)

                        Button {
                            searchText = ""
                            selectedRole = .all
                            applyFilter()
                        } label: {
                            Text(tr("נקה סינון", "Clear filters"))
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Color.black.opacity(0.88))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.94))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 46)

                } else {
                    List(filteredUsers) { user in
                        NavigationLink {
                            AdminUserDetailsView(user: user)
                        } label: {
                            userRow(user)
                                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .padding(.top, 8)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            loadUsers()
        }
        .onChange(of: searchText) { _, _ in
            applyFilter()
        }
    }

    // MARK: Screen header

    private var screenHeader: some View {

        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
            Text(tr("ניהול משתמשים", "User management"))
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr("משתמשים אמיתיים מ־Firestore", "Real users from Firestore"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func errorMessageCard(_ message: String) -> some View {

        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.70))

                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

            } else {
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.82))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.70))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.35, green: 0.04, blue: 0.08).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.26), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: Header stats

    private var headerStats: some View {

        VStack(spacing: 10) {
            HStack(spacing: 12) {

                statItem(
                    tr("סה״כ", "Total"),
                    users.count,
                    icon: "person.3.fill"
                )

                statItem(
                    tr("מנהלים", "Admins"),
                    users.filter { AdminUser.isAdminRole($0.role) }.count,
                    icon: "person.badge.key.fill"
                )
            }

            HStack(spacing: 12) {
                statItem(
                    tr("מאמנים", "Coaches"),
                    users.filter { AdminUser.isCoachRole($0.role) }.count,
                    icon: "figure.martial.arts"
                )

                statItem(
                    tr("מתאמנים", "Trainees"),
                    users.filter { AdminUser.isTraineeRole($0.role) }.count,
                    icon: "person.fill"
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    private func statItem(
        _ title: String,
        _ value: Int,
        icon: String
    ) -> some View {

        VStack(spacing: 6) {

            Image(systemName: icon)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color(red: 0.72, green: 0.91, blue: 1.0))

            Text("\(value)")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    // MARK: Role filter

    private var roleFilter: some View {

        HStack(spacing: 10) {
            roleFilterButton(title: tr("כולם", "All"), value: .all)
            roleFilterButton(title: tr("מאמנים", "Coaches"), value: .coach)
            roleFilterButton(title: tr("מתאמנים", "Trainees"), value: .trainee)
        }
        .padding(.horizontal, 14)
    }

    private func roleFilterButton(title: String, value: UserRoleFilter) -> some View {
        Button {
            selectedRole = value
            applyFilter()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(selectedRole == value ? Color.black.opacity(0.88) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            selectedRole == value
                            ? Color.white.opacity(0.96)
                            : Color.white.opacity(0.14)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(selectedRole == value ? 0.35 : 0.20), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search

    private var searchBar: some View {

        HStack(spacing: 10) {
            if isEnglish {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black.opacity(0.35))

                TextField(tr("חיפוש משתמש...", "Search user..."), text: $searchText)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

            } else {
                TextField(tr("חיפוש משתמש...", "Search user..."), text: $searchText)
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .padding(.horizontal, 14)
    }

    // MARK: Row

    private func userRow(_ user: AdminUser) -> some View {

        HStack(spacing: 12) {

            if isEnglish {
                VStack(alignment: .leading, spacing: 6) {
                    userTexts(user)
                }

                Spacer(minLength: 0)

                Image(systemName: rowChevronName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))

            } else {
                Image(systemName: rowChevronName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.28))

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    userTexts(user)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 7, x: 0, y: 3)
    }

    private func userTexts(_ user: AdminUser) -> some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 6) {

            if isEnglish {
                HStack(spacing: 8) {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .lineLimit(1)

                    roleBadge(user.role)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    roleBadge(user.role)

                    Text(user.fullName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(user.email)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(1)
            }

            if !user.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(isEnglish ? "Phone: \(user.phone)" : "טלפון: \(user.phone)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .multilineTextAlignment(screenTextAlignment)
                    .lineLimit(1)
            }

            Text(user.branchGroupLine(isEnglish: isEnglish))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)
        }
    }

    private func roleBadge(_ role: String) -> some View {

        HStack(spacing: 5) {
            Image(systemName: roleIcon(role))
                .font(.system(size: 10, weight: .black))

            Text(roleTextForUi(role))
                .font(.system(size: 11, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(roleColor(role))
        )
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

    // MARK: Firestore

    private func loadUsers() {

        loading = true
        errorMessage = nil

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

                var uniqueByKey: [String: AdminUser] = [:]

                for user in rawUsers {
                    let key = user.uniqueMergeKey
                    guard !key.isEmpty else { continue }

                    if let existing = uniqueByKey[key] {
                        uniqueByKey[key] = AdminUser.merged(existing: existing, incoming: user)
                    } else {
                        uniqueByKey[key] = user
                    }
                }

                users = uniqueByKey.values.sorted {
                    $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
                }

                errorMessage = nil
                applyFilter()
            }
    }

    // MARK: Filter logic

    private func applyFilter() {

        var result = users

        if selectedRole == .coach {
            result = result.filter { AdminUser.isCoachRole($0.role) }
        }

        if selectedRole == .trainee {
            result = result.filter { AdminUser.isTraineeRole($0.role) }
        }

        let query = normalizedSearchText

        if !query.isEmpty {

            result = result.filter { user in
                user.fullName.localizedCaseInsensitiveContains(query) ||
                user.email.localizedCaseInsensitiveContains(query) ||
                user.phone.localizedCaseInsensitiveContains(query) ||
                user.branch.localizedCaseInsensitiveContains(query) ||
                user.group.localizedCaseInsensitiveContains(query) ||
                user.role.localizedCaseInsensitiveContains(query) ||
                roleTextForUi(user.role).localizedCaseInsensitiveContains(query) ||
                user.branchGroupLine(isEnglish: isEnglish).localizedCaseInsensitiveContains(query)
            }
        }

        filteredUsers = result
    }
}

enum UserRoleFilter {
    case all
    case coach
    case trainee
}

struct AdminUser: Identifiable {

    let id: String

    let fullName: String
    let email: String
    let phone: String
    let branch: String
    let group: String
    let role: String

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

        let uid = stringValue(
            "uid",
            "userId"
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

        let resolvedRole: String

        if !rawRole.isEmpty {
            resolvedRole = rawRole
        } else if boolValue("isAdmin", "admin", "isManager", "manager") {
            resolvedRole = "admin"
        } else if boolValue("isCoach", "coach", "isTrainer", "trainer", "isInstructor", "instructor") {
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

        let hasRealDisplayContent =
            !fallbackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !phone.filter { $0.isNumber }.isEmpty ||
            !resolvedBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !resolvedGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !branchesArray.isEmpty ||
            !groupsArray.isEmpty

        guard hasRealDisplayContent else {
            return nil
        }

        return AdminUser(
            id: id,
            fullName: fallbackName.isEmpty ? "-" : fallbackName,
            email: email,
            phone: phone,
            branch: resolvedBranch,
            group: resolvedGroup,
            role: resolvedRole
        )
    }

    static func merged(existing: AdminUser, incoming: AdminUser) -> AdminUser {
        AdminUser(
            id: existing.id,
            fullName: betterText(existing.fullName, incoming.fullName),
            email: betterText(existing.email, incoming.email),
            phone: betterText(existing.phone, incoming.phone),
            branch: betterText(existing.branch, incoming.branch),
            group: betterText(existing.group, incoming.group),
            role: betterRole(existing.role, incoming.role)
        )
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

    var uniqueMergeKey: String {
        let emailKey = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !emailKey.isEmpty {
            return "email:\(emailKey)"
        }

        let phoneKey = phone
            .filter { $0.isNumber }

        if !phoneKey.isEmpty {
            return "phone:\(phoneKey)"
        }

        let nameKey = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return nameKey.isEmpty ? "" : "name:\(nameKey)"
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

    private static func betterText(_ first: String, _ second: String) -> String {
        let cleanFirst = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecond = second.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanFirst.isEmpty { return cleanSecond }
        if cleanSecond.isEmpty { return cleanFirst }

        return cleanSecond.count > cleanFirst.count ? cleanSecond : cleanFirst
    }

    var hasRealAdminListContent: Bool {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhoneDigits = phone.filter { $0.isNumber }
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanName == "-" &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty &&
            cleanBranch.isEmpty &&
            cleanGroup.isEmpty {
            return false
        }

        if cleanName.lowercased().hasPrefix("unknown user") &&
            cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty {
            return false
        }

        if cleanEmail.isEmpty &&
            cleanPhoneDigits.isEmpty &&
            cleanBranch.isEmpty &&
            cleanGroup.isEmpty &&
            cleanName.count >= 24 &&
            cleanName.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return false
        }

        return !cleanName.isEmpty ||
            !cleanEmail.isEmpty ||
            !cleanPhoneDigits.isEmpty ||
            !cleanBranch.isEmpty ||
            !cleanGroup.isEmpty
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
}
