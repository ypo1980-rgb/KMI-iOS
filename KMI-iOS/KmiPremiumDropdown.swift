import SwiftUI

struct KmiPremiumMultiSelectDropdown: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPresented = false

    let title: String
    let options: [String]
    @Binding var selectedValues: Set<String>

    let placeholder: String
    let isEnglish: Bool
    let isEnabled: Bool

    var maxSelected: Int = .max
    var labelForOption: (String) -> String = { $0 }

    private var cleanOptions: [String] {
        var seen = Set<String>()
        return options.filter { seen.insert($0).inserted }
    }

    private var canOpen: Bool {
        isEnabled && !cleanOptions.isEmpty
    }

    private var alignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var displayedValue: String {
        let selected = cleanOptions.filter {
            selectedValues.contains($0)
        }

        return selected.isEmpty
            ? placeholder
            : selected.map(labelForOption).joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .kmiFont(size: 13, weight: .bold)
                .foregroundStyle(
                    KmiAppTheme.onSurfaceVariant(for: colorScheme)
                )
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: alignment)

            Button {
                isPresented = true
            } label: {
                HStack(spacing: 10) {
                    if !isEnglish {
                        dropdownIcon
                    }

                    Text(displayedValue)
                        .kmiFont(
                            size: 16,
                            weight: selectedValues.isEmpty ? .medium : .bold
                        )
                        .foregroundStyle(
                            selectedValues.isEmpty
                                ? KmiAppTheme.onSurfaceVariant(for: colorScheme)
                                : KmiAppTheme.onSurface(for: colorScheme)
                        )
                        .multilineTextAlignment(textAlignment)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: alignment)

                    if isEnglish {
                        dropdownIcon
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            KmiAppTheme.surfaceVariant(for: colorScheme)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            KmiAppTheme.outlineVariant(for: colorScheme),
                            lineWidth: 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!canOpen)
            .opacity(canOpen ? 1 : 0.58)
            .accessibilityLabel(title)
            .accessibilityValue(displayedValue)
            .popover(isPresented: $isPresented) {
                selectionList
                    .presentationCompactAdaptation(.popover)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private var dropdownIcon: some View {
        Image(systemName: "chevron.down")
            .kmiIconSize(13)
            .fontWeight(.heavy)
            .foregroundStyle(
                KmiAppTheme.secondary(for: colorScheme)
            )
            .accessibilityHidden(true)
    }

    private var selectionList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .kmiFont(size: 16, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !selectedValues.isEmpty {
                    Text("\(selectedValues.count)")
                        .kmiFont(size: 12, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.18))
                        )
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .padding(.horizontal, 14)
            .background(
                KmiAppTheme.primary(for: colorScheme)
            )

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(cleanOptions, id: \.self) { option in
                        optionRow(option)
                    }
                }
            }
            .frame(
                height: min(CGFloat(cleanOptions.count) * 56, 240)
            )

            Divider()
                .overlay(
                    KmiAppTheme.outlineVariant(for: colorScheme)
                )

            Button {
                isPresented = false
            } label: {
                Text(isEnglish ? "Finish selection" : "סיום בחירה")
                    .kmiFont(size: 15, weight: .bold)
                    .foregroundStyle(
                        KmiAppTheme.onSurface(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300)
        .background(
            KmiAppTheme.surface(for: colorScheme)
        )
        .environment(\.layoutDirection, .leftToRight)
    }

    private func optionRow(_ option: String) -> some View {
        let checked = selectedValues.contains(option)
        let canSelect = checked || selectedValues.count < maxSelected

        return Button {
            if checked {
                selectedValues.remove(option)
            } else if selectedValues.count < maxSelected {
                selectedValues.insert(option)
            }
        } label: {
            HStack(spacing: 10) {
                if isEnglish {
                    selectionIcon(checked)
                }

                Text(labelForOption(option))
                    .kmiFont(
                        size: 14,
                        weight: checked ? .bold : .regular
                    )
                    .foregroundStyle(
                        KmiAppTheme.onSurface(for: colorScheme)
                    )
                    .multilineTextAlignment(textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: alignment)

                if !isEnglish {
                    selectionIcon(checked)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                checked
                    ? KmiAppTheme.surfaceVariant(for: colorScheme)
                    : KmiAppTheme.surface(for: colorScheme)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
        .opacity(canSelect ? 1 : 0.5)
        .accessibilityValue(
            checked
                ? (isEnglish ? "Selected" : "נבחר")
                : (isEnglish ? "Not selected" : "לא נבחר")
        )
    }

    private func selectionIcon(_ checked: Bool) -> some View {
        Image(
            systemName: checked
                ? "checkmark.square.fill"
                : "square"
        )
        .kmiIconSize(20)
        .fontWeight(.semibold)
        .foregroundStyle(
            checked
                ? KmiAppTheme.secondary(for: colorScheme)
                : KmiAppTheme.onSurfaceVariant(for: colorScheme)
        )
        .accessibilityHidden(true)
    }
}

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
    var labelForOption: (String) -> String = { $0 }

    private var displayedValue: String {
        let cleanValue =
            selectedValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return cleanValue.isEmpty
            ? placeholder
            : labelForOption(cleanValue)
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
                                labelForOption(option),
                                systemImage: "checkmark"
                            )
                        } else {
                            Text(labelForOption(option))
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
            .kmiIconSize(13)
            .fontWeight(.heavy)
            .foregroundStyle(
                KmiAppTheme.secondary(
                    for: colorScheme
                )
            )
            .accessibilityHidden(true)
    }
}
