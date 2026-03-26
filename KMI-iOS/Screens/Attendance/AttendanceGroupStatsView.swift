import SwiftUI

struct AttendanceGroupStatsView: View {
    let ownerUid: String
    let initialBranchName: String
    let initialGroupKey: String

    @State private var branchName: String
    @State private var groupKey: String

    @State private var reports: [AttendanceSavedReport] = []
    @State private var summary: AttendanceGroupStatsSummary =
        .init(averagePercent: 0, totalSessions: 0, averagePresent: 0, averageTotal: 0)

    private let repository: AttendanceRepository

    init(
        ownerUid: String,
        initialBranchName: String = "",
        initialGroupKey: String = "",
        repository: AttendanceRepository = .shared
    ) {
        self.ownerUid = ownerUid
        self.initialBranchName = initialBranchName
        self.initialGroupKey = initialGroupKey
        self.repository = repository

        _branchName = State(initialValue: initialBranchName)
        _groupKey = State(initialValue: initialGroupKey)
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
                    filtersCard
                    summaryCard
                    reportsCard
                }
                .padding(12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("סטטיסטיקת קבוצה")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reload()
        }
    }

    private var titleCard: some View {
        card {
            HStack {
                Circle()
                    .fill(.cyan.opacity(0.9))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(.white)
                    )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("סטטיסטיקת נוכחות לקבוצה")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)

                    Text("שנה אחרונה לפי סניף וקבוצה")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    private var filtersCard: some View {
        card {
            sectionHeader("סינון נתונים", subtitle: "בחר סניף וקבוצה כדי לטעון דו״חות")

            TextField("סניף", text: $branchName)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)

            TextField("קבוצה", text: $groupKey)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)

            Button {
                reload()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("רענן סטטיסטיקה")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var summaryCard: some View {
        card {
            sectionHeader("סיכום קבוצה", subtitle: "נתוני שנה אחרונה")

            HStack(spacing: 10) {
                statPill(title: "ממוצע %", value: "\(summary.averagePercent)")
                statPill(title: "שיעורים", value: "\(summary.totalSessions)")
            }

            HStack(spacing: 10) {
                statPill(title: "ממוצע הגיעו", value: "\(summary.averagePresent)")
                statPill(title: "ממוצע סה״כ", value: "\(summary.averageTotal)")
            }
        }
    }

    private var reportsCard: some View {
        card {
            sectionHeader(
                "דו״חות שמורים",
                subtitle: reports.isEmpty ? "אין עדיין דו״חות שמורים" : "מציג \(reports.count) דו״חות אחרונים"
            )

            if reports.isEmpty {
                Text("לא נמצאו דו״חות עבור הסניף והקבוצה שנבחרו.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                ForEach(reports) { report in
                    reportRow(report)

                    if report.id != reports.last?.id {
                        Divider().overlay(.white.opacity(0.14))
                    }
                }
            }
        }
    }

    private func reportRow(_ report: AttendanceSavedReport) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedDate(report.dateIso))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("אחוז נוכחות: \(report.percentPresent)%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            HStack(spacing: 8) {
                miniStat(title: "סה״כ", value: "\(report.totalMembers)")
                miniStat(title: "הגיעו", value: "\(report.presentCount)")
                miniStat(title: "מוצדק", value: "\(report.excusedCount)")
                miniStat(title: "לא הגיעו", value: "\(report.absentCount)")
                miniStat(title: "לא סומנו", value: "\(report.unknownCount)")
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reload() {
        let cleanBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        reports = repository.reportsLastYear(
            ownerUid: ownerUid,
            branchName: cleanBranch,
            groupKey: cleanGroup
        )

        summary = repository.groupStatsSummary(
            ownerUid: ownerUid,
            branchName: cleanBranch,
            groupKey: cleanGroup
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

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formattedDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"

        let output = DateFormatter()
        output.locale = Locale(identifier: "he_IL")
        output.dateFormat = "EEEE, d MMM yyyy"

        guard let date = input.date(from: iso) else { return iso }
        return output.string(from: date)
    }
}
