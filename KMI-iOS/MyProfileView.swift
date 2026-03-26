import SwiftUI

struct MyProfileView: View {

    // MARK: - Stored user data

    @AppStorage("fullName") var fullName: String = ""
    @AppStorage("email") var email: String = ""
    @AppStorage("phone") var phone: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("region") var region: String = ""
    @AppStorage("branch") var branch: String = ""
    @AppStorage("group") var group: String = ""
    @AppStorage("current_belt") var currentBelt: String = ""

    @State private var passwordVisible = false
    @State private var password = "********"

    var body: some View {

        ScrollView {

            VStack(spacing: 20) {

                headerCard

                beltCard

                personalInfoCard

                accountCard

                nextTrainingCard
            }
            .padding()
        }
        .navigationTitle("הפרופיל שלי")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue)

            Text(fullName.isEmpty ? "משתמש" : fullName)
                .font(.system(size: 22, weight: .bold))

            Text("\(branch) • \(group)")
                .font(.system(size: 14))
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

    // MARK: - Belt

    private var beltCard: some View {
        VStack(alignment: .trailing, spacing: 10) {

            Text("החגורה שלי")
                .font(.system(size: 17, weight: .bold))

            HStack {

                Spacer()

                Text(beltDisplayName())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(beltColor())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Personal info

    private var personalInfoCard: some View {

        VStack(spacing: 12) {

            infoRow("אזור", region)
            infoRow("סניף", branch)
            infoRow("קבוצה", group)
            infoRow("טלפון", phone)
            infoRow("מייל", email)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Account

    private var accountCard: some View {

        VStack(spacing: 12) {

            infoRow("שם משתמש", username)

            HStack {

                Text("סיסמה")
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()

                HStack(spacing: 8) {

                    Text(passwordVisible ? password : "••••••••")

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Next training

    private var nextTrainingCard: some View {

        VStack(spacing: 10) {

            Text("האימון הבא")
                .font(.system(size: 17, weight: .bold))

            Text("יום שני • 19:00")
                .font(.system(size: 16))

            Text(branch)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
    }

    // MARK: - Helpers

    private func infoRow(_ title: String, _ value: String) -> some View {

        HStack {

            Spacer()

            Text(value.isEmpty ? "-" : value)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }

    private func beltDisplayName() -> String {

        switch currentBelt.lowercased() {

        case "yellow": return "צהובה"
        case "orange": return "כתומה"
        case "green": return "ירוקה"
        case "blue": return "כחולה"
        case "brown": return "חומה"
        case "black": return "שחורה"

        default: return "לבנה"
        }
    }

    private func beltColor() -> Color {

        switch currentBelt.lowercased() {

        case "yellow": return .yellow
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "brown": return .brown
        case "black": return .black

        default: return .gray
        }
    }
}
