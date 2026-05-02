import SwiftUI
import MapKit

struct TrainingCardView: View {
    let training: TrainingData
    let isEnglish: Bool
    var onNavigateTap: () -> Void = {}

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 12) {
            Text(TrainingCatalogIOS.displayPlace(training.place, isEnglish: isEnglish))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(dayAndDateText(from: training.date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(timeLine)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .foregroundStyle(.purple)

                Text(TrainingCatalogIOS.displayAddress(training.address, isEnglish: isEnglish))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.70))
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)

                Button {
                    onNavigateTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text(tr("ניווט", "Navigate"))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("\(tr("מאמן", "Coach")): \(TrainingCatalogIOS.displayCoach(training.coach, isEnglish: isEnglish))")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var timeLine: String {
        let startTime = training.startText.components(separatedBy: " ").last ?? training.startText
        return "\(startTime) – \(training.endText)"
    }

    private func dayAndDateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        formatter.dateFormat = "EEEE dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
}
