import SwiftUI
import MapKit

struct TrainingCardView: View {
    let training: TrainingData
    let isEnglish: Bool
    var onNavigateTap: () -> Void = {}

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(placeLine)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Color(red: 0.04, green: 0.07, blue: 0.12))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)

            Text(dateTimeLine)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.16))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)

            NavigationChipIOS(
                address: addressLine,
                isEnglish: isEnglish,
                onTap: onNavigateTap
            )
            .padding(.top, 3)

            Text(coachLine)
                .font(.system(size: 12.5, weight: .heavy))
                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.72))
                .multilineTextAlignment(isEnglish ? .leading : .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(
                    maxWidth: .infinity,
                    alignment: isEnglish ? .leading : .trailing
                )
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 116)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.26), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 3)
        .environment(\.layoutDirection, rowDirection)
    }

    private var placeLine: String {
        let displaySource = training.place
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !displaySource.isEmpty {
            return TrainingCatalogIOS.displayPlace(displaySource, isEnglish: isEnglish)
        }
        
        return TrainingCatalogIOS.displayAddress(training.address, isEnglish: isEnglish)
    }

    private var addressLine: String {
        TrainingCatalogIOS.displayAddress(training.address, isEnglish: isEnglish)
    }

    private var coachLine: String {
        let coach = TrainingCatalogIOS
            .displayCoach(training.coach, isEnglish: isEnglish)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if coach.isEmpty {
            return isEnglish ? "Coach: —" : "מאמן: —"
        }
        
        return isEnglish ? "Coach: \(coach)" : "מאמן: \(coach)"
    }

    private var dateTimeLine: String {
        let day = dayAndDateText(from: training.date)
        return "\(day) · \(timeLine)"
    }

    private var timeLine: String {
        let startTime = training.startText
            .components(separatedBy: " ")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? training.startText
        
        return "\(startTime) – \(training.endText)"
    }

    private func dayAndDateText(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

private struct NavigationChipIOS: View {
    let address: String
    let isEnglish: Bool
    let onTap: () -> Void

    private var rowDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .heavy))
                        
                        Text(isEnglish ? "Navigate" : "ניווט")
                            .font(.system(size: isEnglish ? 10 : 11, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }
                    .foregroundStyle(Color(red: 0.05, green: 0.07, blue: 0.12))
                    .padding(.horizontal, 6)
                }
                .frame(width: isEnglish ? 78 : 68, height: 30)

                Text(address.isEmpty ? (isEnglish ? "No address" : "אין כתובת") : address)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.33, blue: 0.41))
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .multilineTextAlignment(isEnglish ? .leading : .trailing)
                    .frame(
                        maxWidth: .infinity,
                        alignment: isEnglish ? .leading : .trailing
                    )

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.84, green: 0.15, blue: 0.92))
            }
            .environment(\.layoutDirection, rowDirection)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.99))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
