import SwiftUI

struct MonthlyBoardSelectedDayCard: View {
    let details: MonthlyBoardSelectedDayDetails?
    let onAddSummaryTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let details {
                Text(details.titleHeb)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if details.holidays.isEmpty && details.trainings.isEmpty {
                    Text("אין אימונים או חגים בתאריך זה.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if !details.holidays.isEmpty {
                    sectionTitle("חגים")
                    ForEach(details.holidays) { holiday in
                        infoRow(
                            title: holiday.title,
                            subtitle: holiday.isMajor ? "חג מרכזי" : "מועד"
                        )
                    }
                }

                if !details.trainings.isEmpty {
                    sectionTitle("אימונים")
                    ForEach(details.trainings) { training in
                        VStack(alignment: .trailing, spacing: 6) {
                            infoRow(
                                title: training.title,
                                subtitle: "\(training.timeText) • \(training.location)"
                            )

                            if let notes = training.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }

                    if let onAddSummaryTap {
                        Button(action: onAddSummaryTap) {
                            Text("הוסף סיכום אימון")
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .padding(.top, 4)
                    }
                }
            } else {
                Text("בחר תאריך בלוח כדי לראות פרטים.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.cyan.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func infoRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}
