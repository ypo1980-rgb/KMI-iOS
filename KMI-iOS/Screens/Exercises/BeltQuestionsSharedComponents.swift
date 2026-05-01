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
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.92))
                }

                VStack(alignment: stackAlignment, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .multilineTextAlignment(textAlignment)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .multilineTextAlignment(textAlignment)
                    }
                }

                if !isEnglish {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
            }
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
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(isSelected ? 0.95 : 0.55))
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

// MARK: - Shared Exercise Mark Row

struct KmiExerciseMarkRow: View {
    let title: String
    let mark: KmiExerciseMark?
    let isEnglish: Bool

    let onMarkDone: () -> Void
    let onMarkNotDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {

            if isEnglish {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }
}
