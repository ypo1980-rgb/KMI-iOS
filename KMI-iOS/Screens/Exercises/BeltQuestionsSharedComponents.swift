import SwiftUI

// MARK: - Shared Subject Pill

struct SubjectPill: View {
    let title: String
    let subtitle: String?
    let fill: Color
    let isEnglish: Bool
    let onTap: () -> Void

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isEnglish {
                    Image(systemName: "info.circle.fill")
                        .kmiIconSize(17)
                        .fontWeight(.heavy)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .accessibilityHidden(true)
                }

                VStack(alignment: stackAlignment, spacing: 4) {
                    Text(title)
                        .kmiFont(size: 18, weight: .heavy)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .kmiFont(size: 14, weight: .heavy)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                }

                if !isEnglish {
                    Image(systemName: "info.circle.fill")
                        .kmiIconSize(17)
                        .fontWeight(.heavy)
                        .foregroundStyle(Color.white.opacity(0.92))
                        .accessibilityHidden(true)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Mark Circle Button

struct KmiMarkCircleButton: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let systemName: String
    let isSelected: Bool
    let selectedFill: Color
    let unselectedFill: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? selectedFill : unselectedFill)
                    .frame(width: 38, height: 38)

                Image(systemName: systemName)
                    .kmiIconSize(16)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : KmiAppTheme.onSurfaceVariant(
                                for: colorScheme
                            )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Exercise Mark

enum KmiExerciseMark: String {
    case done
    case notDone
}

enum KmiCoachExerciseStatus: String, CaseIterable, Hashable {
    case taught
    case practiced
    case needsReinforcement

    func title(isEnglish: Bool) -> String {
        switch self {
        case .taught:
            return isEnglish ? "Taught" : "נלמד"
        case .practiced:
            return isEnglish ? "Practiced" : "תורגל"
        case .needsReinforcement:
            return isEnglish ? "Reinforcement" : "חיזוק"
        }
    }
}

struct KmiCoachExerciseCard: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let accent: Color
    let isEnglish: Bool
    let selectedStatuses: Set<KmiCoachExerciseStatus>
    let onSelectStatus: (KmiCoachExerciseStatus) -> Void
    let onInfoClick: () -> Void

    var updatedAtByStatus: [KmiCoachExerciseStatus: Date] = [:]
    var isFavorite: Bool = false

    @State private var showStatusLimit = false

    private static let statusDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var physicalAlignment: Alignment {
        .leading
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                Button(action: onInfoClick) {
                    Text(title)
                        .kmiFont(size: 20, weight: .bold)
                        .foregroundStyle(
                            KmiAppTheme.onSurface(
                                for: colorScheme
                            )
                        )
                        .multilineTextAlignment(textAlignment)
                        .frame(
                            maxWidth: .infinity,
                            alignment: physicalAlignment
                        )
                        .lineLimit(3)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isFavorite {
                    Text(isEnglish ? "Favorite" : "מועדף")
                        .kmiTypography(.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            KmiAppTheme.warning(
                                for: colorScheme
                            )
                        )
                        .lineLimit(1)
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                            .fill(
                                KmiAppTheme.warning(
                                    for: colorScheme
                                ).opacity(
                                    colorScheme == .dark ? 0.20 : 0.12
                                )
                            )
                        )
                }
            }
            .environment(
                \.layoutDirection,
                isEnglish ? .leftToRight : .rightToLeft
            )
            .padding(.horizontal, 8)
            .padding(.top, 2)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    statusButtons
                    informationButton
                }

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        statusButtons
                    }

                    informationButton
                }
            }
            .frame(maxWidth: .infinity)
            .environment(
                \.layoutDirection,
                isEnglish ? .leftToRight : .rightToLeft
            )

            if showStatusLimit {
                Text(
                    isEnglish
                        ? "You can select up to 2 statuses."
                        : "ניתן לבחור עד 2 סטטוסים."
                )
                .kmiTypography(.caption)
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .task {
                    do {
                        try await Task.sleep(
                            nanoseconds: 2_000_000_000
                        )
                        showStatusLimit = false
                    } catch {
                        return
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surface(for: colorScheme)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                colorScheme == .dark
                    ? accent.opacity(0.55)
                    : KmiAppTheme.outlineVariant(
                        for: colorScheme
                    ).opacity(0.85),
                lineWidth: 1
            )
        )
    }

    private var statusButtons: some View {
        ForEach(KmiCoachExerciseStatus.allCases, id: \.self) { status in
            statusButton(status)
        }
    }

    private func statusButton(
        _ status: KmiCoachExerciseStatus
    ) -> some View {
        let isSelected = selectedStatuses.contains(status)
        let tint = statusTint(status)

        let dateText: String = {
            guard isSelected,
                  let date = updatedAtByStatus[status] else {
                return ""
            }

            return Self.statusDateFormatter.string(from: date)
        }()

        return Button {
            if isSelected || selectedStatuses.count < 2 {
                onSelectStatus(status)
            } else {
                showStatusLimit = true
            }
        } label: {
            VStack(spacing: 2) {
                Text(
                    status == .needsReinforcement && isEnglish
                        ? "Reinforce"
                        : status.title(isEnglish: isEnglish)
                )
                .kmiTypography(.caption)
                .fontWeight(isSelected ? .heavy : .bold)
                .foregroundStyle(
                    isSelected
                        ? tint
                        : KmiAppTheme.onSurfaceVariant(
                            for: colorScheme
                        )
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

                if !dateText.isEmpty {
                    Text(dateText)
                        .kmiFont(size: 10, weight: .bold)
                        .monospacedDigit()
                        .foregroundStyle(tint.opacity(0.88))
                        .lineLimit(1)
                        .fixedSize(
                            horizontal: true,
                            vertical: false
                        )
                        .environment(
                            \.layoutDirection,
                            .leftToRight
                        )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            .frame(
                minWidth: 72,
                maxWidth: .infinity,
                minHeight: 34
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .fill(
                    statusBaseTint(status).opacity(
                        isSelected
                            ? (colorScheme == .dark ? 0.18 : 0.10)
                            : (colorScheme == .dark ? 0.08 : 0.05)
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .stroke(
                    tint.opacity(isSelected ? 0.46 : 0.16),
                    lineWidth: isSelected ? 0.9 : 0.7
                )
            )
            .contentShape(
                RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            status.title(isEnglish: isEnglish)
        )
        .accessibilityAddTraits(
            isSelected ? [.isSelected] : []
        )
        .accessibilityValue(
            [
                isSelected
                    ? (isEnglish ? "Selected" : "נבחר")
                    : (isEnglish ? "Not selected" : "לא נבחר"),
                dateText
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        )
    }

    private var informationButton: some View {
        Button(action: onInfoClick) {
            VStack(spacing: 1) {
                Image(systemName: "info.circle.fill")
                    .kmiIconSize(12)

                Text(isEnglish ? "Info" : "מידע")
                    .kmiTypography(.caption)
                    .fontWeight(.heavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            .frame(
                minWidth: 72,
                maxWidth: .infinity,
                minHeight: 34
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
                .fill(
                    KmiAppTheme.primary(for: colorScheme)
                )
            )
            .contentShape(
                RoundedRectangle(cornerRadius: 7)
            )
        }
        .buttonStyle(.plain)
    }

    private func statusBaseTint(
        _ status: KmiCoachExerciseStatus
    ) -> Color {
        switch status {
        case .taught:
            return Color(
                red: 47.0 / 255.0,
                green: 155.0 / 255.0,
                blue: 78.0 / 255.0
            )

        case .practiced:
            return Color(
                red: 109.0 / 255.0,
                green: 75.0 / 255.0,
                blue: 216.0 / 255.0
            )

        case .needsReinforcement:
            return Color(
                red: 185.0 / 255.0,
                green: 107.0 / 255.0,
                blue: 18.0 / 255.0
            )
        }
    }

    private func statusTint(
        _ status: KmiCoachExerciseStatus
    ) -> Color {
        guard colorScheme == .dark else {
            return statusBaseTint(status)
        }

        switch status {
        case .taught:
            return Color(
                red: 109.4 / 255.0,
                green: 185.0 / 255.0,
                blue: 131.1 / 255.0
            )

        case .practiced:
            return Color(
                red: 152.8 / 255.0,
                green: 129.0 / 255.0,
                blue: 227.7 / 255.0
            )

        case .needsReinforcement:
            return Color(
                red: 206.0 / 255.0,
                green: 151.4 / 255.0,
                blue: 89.1 / 255.0
            )
        }
    }
}

// MARK: - Shared Exercise Mark Row

struct KmiExerciseMarkRow: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let mark: KmiExerciseMark?
    let isEnglish: Bool

    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void

    var accent: Color = .blue
    var isFavorite: Bool = false
    var onStatusClick: (() -> Void)? = nil
    var onInfoClick: (() -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if let onStatusClick {
            compactExerciseCard(
                onStatusClick: onStatusClick
            )
        } else {
            legacyExerciseRow
        }
    }

    private func compactExerciseCard(
        onStatusClick: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: onStatusClick) {
                ZStack {
                    Circle()
                        .fill(
                            mark == .done
                                ? Color(
                                    red: 46.0 / 255.0,
                                    green: 125.0 / 255.0,
                                    blue: 50.0 / 255.0
                                )
                                : (
                                    mark == .notDone
                                        ? Color(
                                            red: 198.0 / 255.0,
                                            green: 40.0 / 255.0,
                                            blue: 40.0 / 255.0
                                        )
                                        : KmiAppTheme.surface(
                                            for: colorScheme
                                        )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    mark == .done
                                        ? Color(
                                            red: 27.0 / 255.0,
                                            green: 94.0 / 255.0,
                                            blue: 32.0 / 255.0
                                        )
                                        : (
                                            mark == .notDone
                                                ? Color(
                                                    red: 142.0 / 255.0,
                                                    green: 27.0 / 255.0,
                                                    blue: 27.0 / 255.0
                                                )
                                                : KmiAppTheme.outlineVariant(
                                                    for: colorScheme
                                                )
                                        ),
                                    lineWidth: 1.5
                                )
                        )

                    if let mark {
                        Image(
                            systemName:
                                mark == .done
                                    ? "checkmark"
                                    : "xmark"
                        )
                        .kmiIconSize(21)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isEnglish
                    ? "Change exercise status"
                    : "שינוי מצב התרגיל"
            )

            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    if let onInfoClick {
                        Button(action: onInfoClick) {
                            Image(systemName: "info.circle.fill")
                                .kmiIconSize(19)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isEnglish
                                ? "Exercise information"
                                : "מידע על התרגיל"
                        )
                    }

                    if let onToggleFavorite {
                        Button(action: onToggleFavorite) {
                            Image(
                                systemName:
                                    isFavorite
                                        ? "star.fill"
                                        : "star"
                            )
                            .kmiIconSize(19)
                            .foregroundStyle(
                                isFavorite
                                    ? KmiAppTheme.warning(
                                        for: colorScheme
                                    )
                                    : KmiAppTheme.onSurfaceVariant(
                                        for: colorScheme
                                    )
                            )
                            .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isEnglish
                                ? (
                                    isFavorite
                                        ? "Remove from favorites"
                                        : "Add to favorites"
                                )
                                : (
                                    isFavorite
                                        ? "הסר ממועדפים"
                                        : "הוסף למועדפים"
                                )
                        )
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
                )
                .environment(
                    \.layoutDirection,
                    isEnglish
                        ? .leftToRight
                        : .rightToLeft
                )

                Button {
                    onInfoClick?()
                } label: {
                    Text(title)
                        .kmiTypography(.caption)
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            KmiAppTheme.onSurface(
                                for: colorScheme
                            )
                        )
                        .multilineTextAlignment(
                            isEnglish ? .leading : .trailing
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment:
                                isEnglish ? .leading : .trailing
                        )
                        .lineLimit(3)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onInfoClick == nil)
            }

            RoundedRectangle(cornerRadius: 8)
                .fill(accent)
                .frame(width: 3, height: 34)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.leading, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surface(
                    for: colorScheme
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                colorScheme == .dark
                    ? accent.opacity(0.55)
                    : KmiAppTheme.outlineVariant(
                        for: colorScheme
                    ),
                lineWidth: 1
            )
        )
    }

    private var legacyExerciseRow: some View {
        HStack(spacing: 12) {

            if isEnglish {
                Text(title)
                    .kmiTypography(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        KmiAppTheme.onSurface(
                            for: colorScheme
                        )
                    )
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                KmiMarkCircleButton(
                    systemName: "xmark",
                    isSelected: mark == .notDone,
                    selectedFill: Color.red.opacity(0.75),
                    unselectedFill: Color.red.opacity(0.18),
                    onTap: onMarkNotDone
                )

                KmiMarkCircleButton(
                    systemName: "checkmark",
                    isSelected: mark == .done,
                    selectedFill: Color.green.opacity(0.75),
                    unselectedFill: Color.green.opacity(0.18),
                    onTap: onMarkDone
                )
            }

            if !isEnglish {
                Spacer(minLength: 0)

                Text(title)
                    .kmiTypography(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        KmiAppTheme.onSurface(
                            for: colorScheme
                        )
                    )
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 10)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surface(
                    for: colorScheme
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                KmiAppTheme.outlineVariant(
                    for: colorScheme
                ),
                lineWidth: 1
            )
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}
