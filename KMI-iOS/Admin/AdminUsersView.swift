import SwiftUI
import FirebaseFirestore

struct AdminUsersView: View {

    @State private var users: [AdminUser] = []
    @State private var filteredUsers: [AdminUser] = []

    @State private var searchText: String = ""
    @State private var selectedRole: UserRoleFilter = .all

    @State private var loading = true

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

                headerStats

                roleFilter

                searchBar

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
            roleFilterButton(title: tr("מתאמנים", "Trainees"), value: .trainee)
            roleFilterButton(title: tr("מאמנים", "Coaches"), value: .coach)
            roleFilterButton(title: tr("כולם", "All"), value: .all)
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
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
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
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 5) {
            Text(user.fullName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.84))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

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

            Text(roleTextForUi(user.role))
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(roleColor(user.role))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)

            Text(user.branchGroupLine(isEnglish: isEnglish))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)
        }
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

        Firestore.firestore()
            .collection("users")
            .getDocuments { snapshot, _ in

                loading = false

                guard let docs = snapshot?.documents else {
                    users = []
                    filteredUsers = []
                    return
                }

                let rawUsers = docs.compactMap { doc in
                    AdminUser.from(
                        id: doc.documentID,
                        map: doc.data()
                    )
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

        let fullName =
            ((map["fullName"] as? String) ??
             (map["full_name"] as? String) ??
             (map["name"] as? String) ??
             (map["displayName"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let email =
            ((map["email"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let phone =
            ((map["phone"] as? String) ??
             (map["phoneNumber"] as? String) ??
             (map["phone_number"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fullName.isEmpty || !email.isEmpty || !phone.isEmpty else {
            return nil
        }

        let branchesArray =
            (map["branches"] as? [String])?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []

        let groupsArray =
            (map["groups"] as? [String])?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []

        let singleBranch =
            ((map["activeBranch"] as? String) ??
             (map["active_branch"] as? String) ??
             (map["branch"] as? String) ??
             (map["branchesCsv"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let singleGroup =
            ((map["primaryGroup"] as? String) ??
             (map["activeGroup"] as? String) ??
             (map["active_group"] as? String) ??
             (map["groupKey"] as? String) ??
             (map["group_key"] as? String) ??
             (map["group"] as? String) ??
             (map["age_group"] as? String) ??
             (map["ageGroup"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedBranch = branchesArray.first ?? singleBranch
        let resolvedGroup = groupsArray.first ?? singleGroup

        let resolvedRole =
            ((map["role"] as? String) ??
             (map["userRole"] as? String) ??
             (map["user_role"] as? String) ??
             (map["profile_role"] as? String) ??
             (map["accountRole"] as? String) ??
             "trainee")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return AdminUser(
            id: id,
            fullName: fullName.isEmpty ? (email.isEmpty ? phone : email) : fullName,
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
