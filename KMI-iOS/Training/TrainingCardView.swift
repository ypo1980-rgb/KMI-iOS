import SwiftUI
import MapKit

struct TrainingCardView: View {
    let training: TrainingData
    var onNavigateTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(training.place)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(dayAndDateText(from: training.date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(timeLine)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.80))
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 10) {
                Spacer()

                Button {
                    onNavigateTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("ניווט")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(training.address)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.70))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)

                Image(systemName: "location.fill")
                    .foregroundStyle(.purple)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("מאמן: \(training.coach)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "EEEE dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
