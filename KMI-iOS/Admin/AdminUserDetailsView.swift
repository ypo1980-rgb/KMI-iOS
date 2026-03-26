import SwiftUI

struct AdminUserDetailsView: View {

    let user: AdminUser

    var body: some View {

        ScrollView {

            VStack(spacing: 20) {

                headerCard

                infoCard

                roleCard
            }
            .padding()
        }
        .navigationTitle("פרטי משתמש")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Header

    private var headerCard: some View {

        VStack(spacing: 10) {

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue)

            Text(user.fullName)
                .font(.system(size: 22, weight: .bold))

            Text(user.email)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6)
        )
    }

    // MARK: Info

    private var infoCard: some View {

        VStack(spacing: 12) {

            infoRow("סניף", user.branch)
            infoRow("קבוצה", user.group)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: Role

    private var roleCard: some View {

        VStack(spacing: 12) {

            Text("סוג משתמש")
                .font(.system(size: 17, weight: .bold))

            Text(user.role == "coach" ? "מאמן" : "מתאמן")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(user.role == "coach" ? .blue : .green)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: Row

    private func infoRow(_ title: String, _ value: String) -> some View {

        HStack {

            Spacer()

            Text(value.isEmpty ? "-" : value)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }
}
