import SwiftUI

// MARK: - Picker Sheet

struct PracticeDurationPickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    let isEnglish: Bool

    @Binding var selectedMinutes: Int
    @Binding var alertHalfTime: Bool
    @Binding var beepLast10: Bool

    let onStart: () -> Void
    let onCancel: () -> Void

    private let options = [1, 3, 5]

    private var primary: Color { KmiAppTheme.primary(for: colorScheme) }
    private var surface: Color { KmiAppTheme.surface(for: colorScheme) }
    private var surfaceVariant: Color { KmiAppTheme.surfaceVariant(for: colorScheme) }
    private var onSurface: Color { KmiAppTheme.onSurface(for: colorScheme) }
    private var onSurfaceVariant: Color { KmiAppTheme.onSurfaceVariant(for: colorScheme) }
    private var onPrimary: Color { KmiAppTheme.onPrimary(for: colorScheme) }
    private var outline: Color { KmiAppTheme.outlineVariant(for: colorScheme) }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text(tr("בחר זמן תרגול", "Choose Practice Duration"))
                        .kmiFont(size: 22, weight: .heavy)
                        .foregroundStyle(onSurface)
                        .accessibilityAddTraits(.isHeader)

                    Text(String(format: "%02d:00", selectedMinutes))
                        .kmiFont(size: 28, weight: .heavy)
                        .monospacedDigit()
                        .foregroundStyle(primary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background {
                    panel(fill: KmiAppTheme.primaryContainer(for: colorScheme), radius: 22)
                }

                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { minutes in
                        let isSelected = minutes == selectedMinutes

                        Button {
                            selectedMinutes = minutes
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(minutes)")
                                    .kmiFont(size: 24, weight: .heavy)

                                Text(tr("דק׳", "min"))
                                    .kmiTypography(.secondary)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(isSelected ? onPrimary : onSurface)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background {
                                panel(fill: isSelected ? primary : surface, radius: 16)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(5)
                .background {
                    panel(fill: surfaceVariant, radius: 22)
                }

                VStack(spacing: 10) {
                    alertToggle(
                        title: tr("התראה באמצע הזמן", "Mid-time alert"),
                        subtitle: tr(
                            "צפצוף + הודעה קולית בחצי הזמן",
                            "Beep + voice announcement at halfway point"
                        ),
                        isOn: $alertHalfTime
                    )

                    Divider()
                        .overlay(outline)

                    alertToggle(
                        title: tr("צליל ב-10 השניות האחרונות", "Sound in the last 10 seconds"),
                        subtitle: tr(
                            "צפצוף קצר כל שנייה עד לסיום",
                            "Short beep every second until the end"
                        ),
                        isOn: $beepLast10
                    )
                }
                .tint(primary)
                .padding(14)
                .background {
                    panel(fill: surfaceVariant, radius: 22)
                }

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(tr("בטל", "Cancel"))
                            .kmiTypography(.action)
                            .fontWeight(.bold)
                            .foregroundStyle(primary)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 48)
                    }
                    .buttonStyle(.plain)

                    Button(action: onStart) {
                        Text(tr("התחל", "Start"))
                            .kmiTypography(.action)
                            .fontWeight(.heavy)
                            .foregroundStyle(onPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                primary,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
    }

    private func panel(fill: Color, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(outline, lineWidth: 1)
            }
    }

    private func alertToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .kmiTypography(.action)
                    .fontWeight(.heavy)
                    .foregroundStyle(onSurface)

                Text(subtitle)
                    .kmiTypography(.secondary)
                    .foregroundStyle(onSurfaceVariant)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
    }
}
