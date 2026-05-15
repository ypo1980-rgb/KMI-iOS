import SwiftUI

struct AboutNetworkCoachesView: View {

    private let coachesSections: [NetworkCoachSection] = [
        NetworkCoachSection(
            icon: "person.3.fill",
            title: "מאמני רשת K.M.I",
            subtitle: "מסך כללי להצגת מאמני הרשת, בעלי התפקידים והצוות המקצועי."
        ),
        NetworkCoachSection(
            icon: "star.circle.fill",
            title: "צוות מקצועי",
            subtitle: "כאן יוצגו בהמשך פרטי המאמנים, דרגות, ניסיון, הסמכות ותחומי אחריות."
        ),
        NetworkCoachSection(
            icon: "list.bullet.rectangle.fill",
            title: "רשימת מאמנים",
            subtitle: "בשלב הבא נחבר את המסך לרשימת מאמנים מלאה, לפי המבנה שקיים באנדרואיד."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 18) {

                headerCard

                VStack(spacing: 14) {
                    ForEach(coachesSections) { section in
                        coachInfoCard(section)
                    }
                }

                placeholderNote
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var headerCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 72, height: 72)

                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Text("אודות המאמנים ברשת")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("מסך זה נפתח כדי להשלים את הניווט הקיים באפליקציה. בהמשך נתאים אותו במדויק למסך המקביל באנדרואיד.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
                .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
        )
    }

    private func coachInfoCard(_ section: NetworkCoachSection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(section.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(section.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 46, height: 46)

                Image(systemName: section.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var placeholderNote: some View {
        Text("השלב הבא: לשלוח את המסך המקביל באנדרואיד או את הקובץ שבו רשימת המאמנים מוגדרת, ואז נבנה התאמה מלאה מעל 90%.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
    }
}

private struct NetworkCoachSection: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

#Preview {
    AboutNetworkCoachesView()
}
