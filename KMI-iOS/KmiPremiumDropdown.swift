import SwiftUI

struct KmiPremiumDropdown: View {
    @Environment(\.colorScheme)
    private var colorScheme

    let title: String
    let options: [String]

    @Binding
    var selectedValue: String

    let placeholder: String
    let isEnglish: Bool
    let isEnabled: Bool

    var onSelected: ((String) -> Void)? = nil

    private var displayedValue: String {
        let cleanValue =
            selectedValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleanValue.isEmpty
            ? placeholder
            : cleanValue
    }

    private var hasSelection: Bool {
        !selectedValue
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 6
        ) {
            Text(title)
                .kmiFont(
                    size: 13,
                    weight: .bold
                )
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
                )
                .multilineTextAlignment(textAlignment)
                .frame(
                    maxWidth: .infinity,
                    alignment: frameAlignment
                )

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedValue = option
                        onSelected?(option)
                    } label: {
                        if option == selectedValue {
                            Label(
                                option,
                                systemImage: "checkmark"
                            )
                        } else {
                            Text(option)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if isEnglish {
                        valueLabel

                        Spacer(minLength: 8)

                        dropdownIcon
                    } else {
                        dropdownIcon

                        Spacer(minLength: 8)

                        valueLabel
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(.horizontal, 14)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 48
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(
                        KmiAppTheme.surfaceVariant(
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
                        KmiAppTheme.outlineVariant(
                            for: colorScheme
                        ),
                        lineWidth: 1
                    )
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !isEnabled || options.isEmpty
            )
            .opacity(
                isEnabled && !options.isEmpty
                    ? 1
                    : 0.58
            )
            .accessibilityLabel(title)
            .accessibilityValue(displayedValue)
        }
        .environment(
            \.layoutDirection,
            isEnglish
                ? .leftToRight
                : .rightToLeft
        )
    }

    private var valueLabel: some View {
        Text(displayedValue)
            .kmiFont(
                size: 16,
                weight: hasSelection
                    ? .bold
                    : .medium
            )
            .foregroundStyle(
                hasSelection
                    ? KmiAppTheme.onSurface(
                        for: colorScheme
                    )
                    : KmiAppTheme.onSurfaceVariant(
                        for: colorScheme
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(textAlignment)
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )
    }

    private var dropdownIcon: some View {
        Image(systemName: "chevron.down")
            .kmiFont(
                size: 13,
                weight: .heavy
            )
            .foregroundStyle(
                KmiAppTheme.secondary(
                    for: colorScheme
                )
            )
            .accessibilityHidden(true)
    }
}
