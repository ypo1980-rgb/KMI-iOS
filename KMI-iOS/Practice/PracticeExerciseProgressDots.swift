import SwiftUI

struct PracticeExerciseProgressDots: View {
    @Environment(\.colorScheme) private var colorScheme

    let beltColor: Color
    let currentIndex: Int
    let totalCount: Int
    let isEnglish: Bool

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        let firstRowCount = totalCount <= 12 ? totalCount : (totalCount + 1) / 2

    return VStack(spacing: 6) {
        practiceProgressRow(0..<firstRowCount)

        if firstRowCount < totalCount {
            practiceProgressRow(firstRowCount..<totalCount)
        }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
        KmiAppTheme.surface(for: colorScheme).opacity(0.72),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
    )
    .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                KmiAppTheme.outlineVariant(for: colorScheme),
                lineWidth: 1
            )
    }
    .padding(.horizontal, 18)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(tr("התקדמות בתרגול", "Practice progress")))
    .accessibilityValue(Text(tr(
        "תרגיל \(currentIndex + 1) מתוך \(totalCount)",
        "Exercise \(currentIndex + 1) of \(totalCount)"
    )))
}

private func practiceProgressRow(_ indices: Range<Int>) -> some View {
    GeometryReader { geometry in
        let gapCount = CGFloat(max(0, indices.count - 1))
        let spacing = min(4, geometry.size.width / max(1, gapCount * 2))
        let totalWeight = indices.count + (indices.contains(currentIndex) ? 3 : 0)
        let unitWidth = (geometry.size.width - gapCount * spacing)
            / CGFloat(max(1, totalWeight))

        HStack(spacing: spacing) {
            ForEach(indices, id: \.self) { index in
                let isCurrent = index == currentIndex

                Capsule()
                    .fill(
                        isCurrent
                            ? beltColor
                            : KmiAppTheme.onSurface(for: colorScheme).opacity(0.42)
                    )
                    .frame(
                        width: unitWidth * (isCurrent ? 4 : 1),
                        height: isCurrent ? 12 : 8
                    )
            }
        }
        .frame(height: 12)
    }
    .frame(height: 12)
    }
}
