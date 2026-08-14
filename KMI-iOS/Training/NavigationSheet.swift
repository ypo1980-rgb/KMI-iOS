import SwiftUI
import UIKit

struct NavigationSheet: View {

    let training: TrainingData
    let isEnglish: Bool

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.colorScheme)
    private var colorScheme

    @State private var rememberChoice: Bool = false

    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var graniteCardColor: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF2B2930)
            : Color(hex: 0xFFE8E5E1)
    }

    private var innerCardColor: Color {
        colorScheme == .dark
            ? Color(hex: 0xFF343238)
            : Color(hex: 0xFFF0EEEB)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.94)
            : Color(hex: 0xFF111827)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.70)
            : Color(hex: 0xFF475569)
    }

    private var subtleBorderColor: Color {
        Color(hex: 0xFF1D4ED8)
            .opacity(
                colorScheme == .dark
                    ? 0.28
                    : 0.20
            )
    }

    private func tr(
        _ hebrew: String,
        _ english: String
    ) -> String {
        isEnglish ? english : hebrew
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.22)
                        : Color.black.opacity(0.14)
                )
                .frame(
                    width: 42,
                    height: 5
                )
                .padding(.top, 8)

            VStack(
                alignment: isEnglish
                    ? .leading
                    : .trailing,
                spacing: 6
            ) {
                Text(
                    tr(
                        "ניווט באמצעות",
                        "Navigate with"
                    )
                )
                .kmiFont(
                    size: 22,
                    weight: .heavy
                )
                .foregroundStyle(primaryTextColor)
                .frame(
                    maxWidth: .infinity,
                    alignment: frameAlignment
                )
                .multilineTextAlignment(
                    textAlignment
                )

                Text(training.address)
                    .kmiFont(
                        size: 15,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        secondaryTextColor
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
            }

            Toggle(
                isOn: $rememberChoice
            ) {
                Text(
                    tr(
                        "זכור בחירה",
                        "Remember selection"
                    )
                )
                .kmiFont(
                    size: 16,
                    weight: .semibold
                )
                .foregroundStyle(
                    primaryTextColor
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: frameAlignment
                )
                .multilineTextAlignment(
                    textAlignment
                )
            }
            .tint(Color(hex: 0xFF2563EB))
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                8
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(innerCardColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.08),
                    lineWidth: 0.5
                )
            )

            HStack(spacing: 10) {
                NavigationAppButton(
                    title: "Waze",
                    systemImage:
                        "location.circle.fill",
                    containerColor:
                        innerCardColor,
                    primaryTextColor:
                        primaryTextColor,
                    borderColor:
                        subtleBorderColor
                ) {
                    saveIfNeeded(
                        preferredApp: "waze"
                    )
                    openWaze()
                }

                NavigationAppButton(
                    title: "Google Maps",
                    systemImage:
                        "map.circle.fill",
                    containerColor:
                        innerCardColor,
                    primaryTextColor:
                        primaryTextColor,
                    borderColor:
                        subtleBorderColor
                ) {
                    saveIfNeeded(
                        preferredApp: "google_maps"
                    )
                    openGoogleMaps()
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )

            Text(
                tr(
                    "ניתן לשמור את הבחירה כברירת מחדל.",
                    "You can save this selection as the default."
                )
            )
            .kmiFont(
                size: 13,
                weight: .medium
            )
            .foregroundStyle(
                secondaryTextColor
            )
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
            )
            .multilineTextAlignment(
                textAlignment
            )

            Button {
                dismiss()
            } label: {
                Text(
                    tr(
                        "סגור",
                        "Close"
                    )
                )
                .kmiFont(
                    size: 16,
                    weight: .bold
                )
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color(hex: 0xFF93C5FD)
                        : Color(hex: 0xFF1D4ED8)
                )
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                        ? .trailing
                        : .leading
                )
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .bottom,
            18
        )
        .background(graniteCardColor)
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                subtleBorderColor,
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
        )
        .environment(
            \.layoutDirection,
            layoutDirection
        )
        .onAppear {
            rememberChoice =
                UserDefaults.standard.bool(
                    forKey:
                        "kmi.navigation.remember_choice"
                )
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(
            graniteCardColor
        )
    }

    private func saveIfNeeded(
        preferredApp: String
    ) {
        let defaults =
            UserDefaults.standard

        defaults.set(
            rememberChoice,
            forKey:
                "kmi.navigation.remember_choice"
        )

        if rememberChoice {
            defaults.set(
                preferredApp,
                forKey:
                    "kmi.navigation.preferred_app"
            )
        } else {
            defaults.removeObject(
                forKey:
                    "kmi.navigation.preferred_app"
            )
        }
    }

    private func openWaze() {
        let encoded =
            training.address
                .addingPercentEncoding(
                    withAllowedCharacters:
                        .urlQueryAllowed
                ) ?? training.address

        if
            let applicationURL =
                URL(
                    string:
                        "waze://?q=\(encoded)"
                ),
            UIApplication.shared.canOpenURL(
                applicationURL
            ) {
            UIApplication.shared.open(
                applicationURL
            )
        } else if
            let webURL =
                URL(
                    string:
                        "https://waze.com/ul?q=\(encoded)"
                ) {
            UIApplication.shared.open(
                webURL
            )
        }

        dismiss()
    }

    private func openGoogleMaps() {
        let encoded =
            training.address
                .addingPercentEncoding(
                    withAllowedCharacters:
                        .urlQueryAllowed
                ) ?? training.address

        if
            let applicationURL =
                URL(
                    string:
                        "comgooglemaps://?q=\(encoded)"
                ),
            UIApplication.shared.canOpenURL(
                applicationURL
            ) {
            UIApplication.shared.open(
                applicationURL
            )
        } else if
            let webURL =
                URL(
                    string:
                        "https://www.google.com/maps/search/?api=1&query=\(encoded)"
                ) {
            UIApplication.shared.open(
                webURL
            )
        }

        dismiss()
    }
}

private struct NavigationAppButton: View {

    let title: String
    let systemImage: String
    let containerColor: Color
    let primaryTextColor: Color
    let borderColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color(hex: 0xFF2563EB)
                )

                Text(title)
                    .kmiFont(
                        size: 15,
                        weight: .bold
                    )
                    .foregroundStyle(
                        primaryTextColor
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(containerColor)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    borderColor.opacity(0.80),
                    lineWidth: 0.6
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
    }
}
