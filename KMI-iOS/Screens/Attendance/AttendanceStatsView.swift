import SwiftUI

struct AttendanceStatsView: View {

    let ownerUid: String
    let branchName: String
    let groupKey: String
    let memberId: String
    let memberName: String

    @State private var stats = AttendanceMemberStats(
        monthlyPercent: 0,
        yearlyPercent: 0,
        streakDays: 0,
        bestDays: [],
        lastSessions: []
    )

    private let repository: AttendanceRepository

    init(
        ownerUid: String,
        branchName: String,
        groupKey: String,
        memberId: String,
        memberName: String,
        repository: AttendanceRepository = .shared
    ) {
        self.ownerUid = ownerUid
        self.branchName = branchName
        self.groupKey = groupKey
        self.memberId = memberId
        self.memberName = memberName
        self.repository = repository
    }

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.13),
                    Color(red: 0.08, green: 0.12, blue: 0.24),
                    Color(red: 0.09, green: 0.28, blue: 0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 14) {

                    titleCard
                    percentCard
                    streakCard
                    bestDaysCard
                    lastSessionsCard
                }
                .padding(12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("סטטיסטיקה למתאמן")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStats()
        }
    }

    private var titleCard: some View {
        card {
            HStack {

                Circle()
                    .fill(.cyan.opacity(0.9))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {

                    Text(memberName)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("סטטיסטיקת נוכחות אישית")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var percentCard: some View {
        card {

            sectionHeader("אחוזי נוכחות", subtitle: "חודש ושנה")

            HStack(spacing: 12) {

                statPill(
                    title: "חודש",
                    value: "\(stats.monthlyPercent)%"
                )

                statPill(
                    title: "שנה",
                    value: "\(stats.yearlyPercent)%"
                )
            }
        }
    }

    private var streakCard: some View {
        card {

            sectionHeader("רצף הגעה", subtitle: "מספר אימונים ברצף")

            statPill(
                title: "ימים ברצף",
                value: "\(stats.streakDays)"
            )
        }
    }

    private var bestDaysCard: some View {
        card {

            sectionHeader("ימים מצטיינים", subtitle: "אימונים עם נוכחות")

            if stats.bestDays.isEmpty {

                Text("אין נתונים")
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)

            } else {

                ForEach(stats.bestDays, id: \.self) { day in

                    Text(day)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Divider().overlay(.white.opacity(0.14))
                }
            }
        }
    }

    private var lastSessionsCard: some View {
        card {

            sectionHeader("אימונים אחרונים", subtitle: "8 האחרונים")

            if stats.lastSessions.isEmpty {

                Text("אין נתונים")
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)

            } else {

                ForEach(stats.lastSessions, id: \.self) { line in

                    Text(line)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Divider().overlay(.white.opacity(0.14))
                }
            }
        }
    }

    private func loadStats() {

        stats = repository.memberStats(
            ownerUid: ownerUid,
            branchName: branchName,
            groupKey: groupKey,
            memberId: memberId
        )
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {

        VStack(spacing: 12, content: content)
            .padding(14)
            .background(Color.white.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {

        VStack(alignment: .trailing, spacing: 4) {

            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func statPill(title: String, value: String) -> some View {

        VStack(spacing: 4) {

            Text(value)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
