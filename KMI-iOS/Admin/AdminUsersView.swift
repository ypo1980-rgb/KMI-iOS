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
        .navigationTitle("ניהול משתמשים")
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

        Picker("", selection: $selectedRole) {

            Text("כולם").tag(UserRoleFilter.all)
            Text("מאמנים").tag(UserRoleFilter.coach)
            Text("מתאמנים").tag(UserRoleFilter.trainee)

        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: selectedRole) { _ in
            applyFilter()
        }
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

                users = docs.compactMap { doc in
                    AdminUser.from(doc.data())
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

        return AdminUser(
            fullName: fullName,
            email: email,
            branch: map["branch"] as? String ?? "",
            group: map["group"] as? String ?? "",
            role: map["role"] as? String ?? "trainee"
        )
    }
}
