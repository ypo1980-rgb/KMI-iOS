import SwiftUI
import FirebaseFirestore

struct AdminUsersView: View {

    @State private var users: [AdminUser] = []
    @State private var filteredUsers: [AdminUser] = []

    @State private var searchText: String = ""
    @State private var selectedRole: UserRoleFilter = .all

    @State private var loading = true

    var body: some View {

        VStack(spacing: 12) {

            headerStats

            roleFilter

            searchBar

            if loading {
                ProgressView()
                    .padding(.top, 40)
            } else {

                List(filteredUsers) { user in
                    NavigationLink {
                        AdminUserDetailsView(user: user)
                    } label: {
                        userRow(user)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            loadUsers()
        }
        .onChange(of: searchText) { _ in
            applyFilter()
        }
    }

    // MARK: Header stats

    private var headerStats: some View {

        HStack(spacing: 20) {

            statItem("סה״כ", users.count)

            statItem(
                "מאמנים",
                users.filter { $0.role == "coach" }.count
            )

            statItem(
                "מתאמנים",
                users.filter { $0.role == "trainee" }.count
            )
        }
        .padding(.top, 10)
    }

    private func statItem(_ title: String, _ value: Int) -> some View {

        VStack {

            Text("\(value)")
                .font(.system(size: 22, weight: .bold))

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Role filter

    private var roleFilter: some View {

        HStack(spacing: 10) {
            roleFilterButton(title: "כולם", value: .all)
            roleFilterButton(title: "מאמנים", value: .coach)
            roleFilterButton(title: "מתאמנים", value: .trainee)
        }
        .padding(.horizontal)
    }

    private func roleFilterButton(title: String, value: UserRoleFilter) -> some View {
        Button {
            selectedRole = value
            applyFilter()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(selectedRole == value ? Color.black.opacity(0.85) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            selectedRole == value
                            ? Color.white.opacity(0.95)
                            : Color.white.opacity(0.14)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search

    private var searchBar: some View {

        TextField("חיפוש משתמש...", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
    }

    // MARK: Row

    private func userRow(_ user: AdminUser) -> some View {

        VStack(alignment: .trailing, spacing: 4) {

            Text(user.fullName)
                .font(.system(size: 16, weight: .bold))

            Text(user.email)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text("\(user.branch) • \(user.group)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: Firestore

    private func loadUsers() {

        loading = true

        Firestore.firestore()
            .collection("users")
            .getDocuments { snapshot, error in

                loading = false

                guard let docs = snapshot?.documents else { return }

                let rawUsers = docs.compactMap { doc in
                    AdminUser.from(doc.data())
                }

                var uniqueByEmail: [String: AdminUser] = [:]

                for user in rawUsers {
                    let emailKey = user.email
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()

                    guard !emailKey.isEmpty else { continue }

                    if let existing = uniqueByEmail[emailKey] {
                        uniqueByEmail[emailKey] = AdminUser.merged(existing: existing, incoming: user)
                    } else {
                        uniqueByEmail[emailKey] = user
                    }
                }

                users = uniqueByEmail.values.sorted {
                    $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
                }

                applyFilter()
            }
    }

    // MARK: Filter logic

    private func applyFilter() {

        var result = users

        if selectedRole == .coach {
            result = result.filter { $0.role == "coach" }
        }

        if selectedRole == .trainee {
            result = result.filter { $0.role == "trainee" }
        }

        if !searchText.isEmpty {

            result = result.filter {

                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
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

    let id = UUID()

    let fullName: String
    let email: String
    let branch: String
    let group: String
    let role: String

    static func from(_ map: [String: Any]) -> AdminUser? {

        guard
            let fullName = map["fullName"] as? String ?? map["full_name"] as? String,
            let email = map["email"] as? String
        else {
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
            (map["branch"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let singleGroup =
            ((map["group"] as? String) ??
             (map["age_group"] as? String) ??
             (map["ageGroup"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedBranch = branchesArray.first ?? singleBranch
        let resolvedGroup = groupsArray.first ?? singleGroup

        return AdminUser(
            fullName: fullName,
            email: email,
            branch: resolvedBranch,
            group: resolvedGroup,
            role: map["role"] as? String ?? "trainee"
        )
    }

    static func merged(existing: AdminUser, incoming: AdminUser) -> AdminUser {
        AdminUser(
            fullName: betterText(existing.fullName, incoming.fullName),
            email: betterText(existing.email, incoming.email),
            branch: betterText(existing.branch, incoming.branch),
            group: betterText(existing.group, incoming.group),
            role: betterRole(existing.role, incoming.role)
        )
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

        if cleanFirst == "coach" || cleanSecond == "coach" {
            return "coach"
        }

        return cleanSecond.isEmpty ? cleanFirst : cleanSecond
    }
}
