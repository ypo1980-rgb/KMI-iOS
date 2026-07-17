import SwiftUI
import Shared

struct KmiPracticeMenuSheet: View {

    let defaultBelt: Belt
    let canUseExtras: Bool
    let isEnglish: Bool

    let onRandomPractice:
        (_ belt: Belt) -> Void

    let onFinalExam:
        (_ belt: Belt) -> Void

    let onPracticeByTopic:
        (
            _ belt: Belt,
            _ topicTitle: String
        ) -> Void

    let onDismiss: () -> Void

    @State private var showsTopicPicker =
        false

    @State private var selectedBelt:
        Belt? = nil

    private let availableBelts: [Belt] = [
        .yellow,
        .orange,
        .green,
        .blue,
        .brown,
        .black
    ]

    private var layoutDirection:
        LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    private var accent: Color {
        KmiBeltPalette.color(
            for: defaultBelt
        )
    }

    private var selectedAccent: Color {
        guard let selectedBelt else {
            return accent
        }

        return KmiBeltPalette.color(
            for: selectedBelt
        )
    }

    private var beltName: String {
        localizedBeltName(
            defaultBelt
        )
    }

    private var selectedBeltTopics:
        [String] {
        guard let selectedBelt else {
            return []
        }

        return TopicsEngine.shared
            .topicTitlesFor(
                belt: selectedBelt
            )
            .map {
                $0.trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .reduce(
                into: [String]()
            ) { result, title in
                if !result.contains(title) {
                    result.append(title)
                }
            }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.97,
                        green: 0.95,
                        blue: 0.98
                    ),
                    Color(
                        red: 0.94,
                        green: 0.91,
                        blue: 0.97
                    ),
                    Color(
                        red: 0.98,
                        green: 0.96,
                        blue: 0.99
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showsTopicPicker {
                topicPickerContent
                    .transition(
                        .asymmetric(
                            insertion:
                                .move(edge: .trailing)
                                .combined(
                                    with: .opacity
                                ),
                            removal:
                                .move(edge: .leading)
                                .combined(
                                    with: .opacity
                                )
                        )
                    )
            } else {
                mainMenuContent
                    .transition(
                        .asymmetric(
                            insertion:
                                .move(edge: .leading)
                                .combined(
                                    with: .opacity
                                ),
                            removal:
                                .move(edge: .trailing)
                                .combined(
                                    with: .opacity
                                )
                        )
                    )
            }
        }
        .environment(
            \.layoutDirection,
            layoutDirection
        )
    }

    private var mainMenuContent:
        some View {
        VStack(spacing: 16) {
            premiumHeader(
                title:
                    tr(
                        "תרגול",
                        "Practice"
                    ),
                subtitle:
                    tr(
                        "בחר פעולה כדי להתחיל",
                        "Choose an action to begin"
                    ),
                systemImage:
                    "figure.martial.arts",
                headerAccent:
                    accent
            )

            VStack(spacing: 12) {
                actionRow(
                    title:
                        tr(
                            "תרגול אקראי – (\(beltName))",
                            "Random Practice – (\(beltName))"
                        ),
                    systemImage:
                        "dice.fill",
                    enabled:
                        canUseExtras
                ) {
                    onRandomPractice(
                        defaultBelt
                    )
                }

                actionRow(
                    title:
                        tr(
                            "מבחן מסכם – (\(beltName))",
                            "Final Exam – (\(beltName))"
                        ),
                    systemImage:
                        "checkmark.seal.fill",
                    enabled:
                        canUseExtras
                ) {
                    onFinalExam(
                        defaultBelt
                    )
                }

                actionRow(
                    title:
                        tr(
                            "תרגול לפי נושא",
                            "Practice by Topic"
                        ),
                    systemImage:
                        "list.bullet.rectangle.fill",
                    enabled:
                        canUseExtras
                ) {
                    selectedBelt = nil

                    withAnimation(
                        .easeInOut(
                            duration: 0.24
                        )
                    ) {
                        showsTopicPicker = true
                    }
                }

                if !canUseExtras {
                    subscriptionMessage
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(
                        0.64
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    Color.black.opacity(
                        0.08
                    ),
                    lineWidth: 1
                )
            )

            closeButton
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
    }

    private var topicPickerContent:
        some View {
        VStack(spacing: 16) {
            premiumHeader(
                title:
                    tr(
                        "תרגול לפי נושא",
                        "Practice by Topic"
                    ),
                subtitle:
                    tr(
                        "בחר חגורה ולאחר מכן נושא",
                        "Choose a belt and then a topic"
                    ),
                systemImage:
                    "list.bullet.rectangle.fill",
                headerAccent:
                    selectedAccent
            )

            ScrollView(
                showsIndicators: false
            ) {
                VStack(spacing: 14) {
                    beltPickerCard

                    if let selectedBelt {
                        topicPickerCard(
                            belt: selectedBelt
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(
                        .easeInOut(
                            duration: 0.24
                        )
                    ) {
                        showsTopicPicker =
                            false
                    }
                } label: {
                    Label(
                        tr(
                            "חזרה",
                            "Back"
                        ),
                        systemImage:
                            isEnglish
                                ? "chevron.left"
                                : "chevron.right"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    selectedAccent
                )
                .background(
                    Capsule()
                        .fill(
                            Color.white.opacity(
                                0.78
                            )
                        )
                )

                Button {
                    onDismiss()
                } label: {
                    Text(
                        tr(
                            "סגור",
                            "Close"
                        )
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    Color.black.opacity(
                        0.68
                    )
                )
                .background(
                    Capsule()
                        .fill(
                            Color.white.opacity(
                                0.64
                            )
                        )
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
    }

    private var beltPickerCard:
        some View {
        VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "בחר חגורה",
                    "Choose Belt"
                )
            )
            .font(
                .system(
                    size: 16,
                    weight: .bold
                )
            )
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish
                        ? .leading
                        : .trailing
            )

            Menu {
                ForEach(
                    availableBelts,
                    id: \.self
                ) { belt in
                    Button {
                        selectedBelt =
                            belt
                    } label: {
                        Text(
                            localizedBeltName(
                                belt
                            )
                        )
                    }
                }
            } label: {
                pickerField(
                    title:
                        selectedBelt.map {
                            localizedBeltName(
                                $0
                            )
                        } ??
                        tr(
                            "בחר חגורה",
                            "Choose Belt"
                        ),
                    systemImage:
                        "circle.fill",
                    accent:
                        selectedAccent,
                    enabled:
                        true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            cardBackground(
                accent:
                    selectedAccent
            )
        )
    }

    private func topicPickerCard(
        belt: Belt
    ) -> some View {
        VStack(
            alignment:
                isEnglish
                    ? .leading
                    : .trailing,
            spacing: 10
        ) {
            Text(
                tr(
                    "בחר נושא",
                    "Choose Topic"
                )
            )
            .font(
                .system(
                    size: 16,
                    weight: .bold
                )
            )
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish
                        ? .leading
                        : .trailing
            )

            if selectedBeltTopics.isEmpty {
                Text(
                    tr(
                        "אין נושאים זמינים לחגורה זו",
                        "No topics are available for this belt"
                    )
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.black.opacity(
                        0.54
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                            ? .leading
                            : .trailing
                )
                .padding(.vertical, 12)
            } else {
                Menu {
                    ForEach(
                        selectedBeltTopics,
                        id: \.self
                    ) { topicTitle in
                        Button {
                            onPracticeByTopic(
                                belt,
                                topicTitle
                            )
                        } label: {
                            Text(
                                localizedTopicTitle(
                                    topicTitle
                                )
                            )
                        }
                    }
                } label: {
                    pickerField(
                        title:
                            tr(
                                "בחר נושא",
                                "Choose Topic"
                            ),
                        systemImage:
                            "list.bullet",
                        accent:
                            KmiBeltPalette
                                .color(
                                    for: belt
                                ),
                        enabled:
                            true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            cardBackground(
                accent:
                    KmiBeltPalette.color(
                        for: belt
                    )
            )
        )
    }

    private func premiumHeader(
        title: String,
        subtitle: String,
        systemImage: String,
        headerAccent: Color
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(
                        0.16
                    )
                )

                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 23,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color.white
                )
            }
            .frame(
                width: 48,
                height: 48
            )

            VStack(
                alignment:
                    isEnglish
                        ? .leading
                        : .trailing,
                spacing: 3
            ) {
                Text(title)
                    .font(
                        .system(
                            size: 23,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        Color.white
                    )

                Text(subtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(
                            0.88
                        )
                    )
            }
            .frame(
                maxWidth: .infinity,
                alignment:
                    isEnglish
                        ? .leading
                        : .trailing
            )
        }
        .padding(
            .horizontal,
            16
        )
        .padding(
            .vertical,
            15
        )
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        headerAccent.opacity(
                            0.92
                        ),
                        headerAccent.opacity(
                            0.72
                        ),
                        Color.indigo.opacity(
                            0.82
                        )
                    ],
                    startPoint:
                        .topLeading,
                    endPoint:
                        .bottomTrailing
                )
            )
        )
    }

    private func actionRow(
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else {
                return
            }

            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            accent.opacity(
                                enabled
                                    ? 0.11
                                    : 0.06
                            )
                        )

                    Image(
                        systemName:
                            systemImage
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        enabled
                            ? accent
                            : Color.gray
                                .opacity(0.46)
                    )
                }
                .frame(
                    width: 44,
                    height: 44
                )

                Text(title)
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        enabled
                            ? Color.black
                                .opacity(0.82)
                            : Color.gray
                                .opacity(0.52)
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment:
                            isEnglish
                                ? .leading
                                : .trailing
                    )

                Image(
                    systemName:
                        isEnglish
                            ? "chevron.right"
                            : "chevron.left"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    enabled
                        ? accent.opacity(0.56)
                        : Color.gray.opacity(
                            0.24
                        )
                )
            }
            .padding(
                .horizontal,
                14
            )
            .padding(
                .vertical,
                10
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(
                        enabled
                            ? 0.86
                            : 0.60
                    )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    Color.black.opacity(
                        0.08
                    ),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var subscriptionMessage:
        some View {
        Text(
            tr(
                "אפשרויות התרגול זמינות רק בהרשאות Extras או במנוי.",
                "Practice options are available only with Extras or subscription access."
            )
        )
        .font(
            .system(
                size: 13,
                weight: .medium
            )
        )
        .foregroundStyle(
            Color.red.opacity(0.82)
        )
        .multilineTextAlignment(
            isEnglish
                ? .leading
                : .trailing
        )
        .frame(
            maxWidth: .infinity,
            alignment:
                isEnglish
                    ? .leading
                    : .trailing
        )
        .padding(12)
        .background(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                Color.red.opacity(
                    0.07
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.red.opacity(
                    0.17
                ),
                lineWidth: 1
            )
        )
    }

    private var closeButton:
        some View {
        Button {
            onDismiss()
        } label: {
            Text(
                tr(
                    "סגור",
                    "Close"
                )
            )
            .font(
                .system(
                    size: 15,
                    weight: .bold
                )
            )
            .foregroundStyle(
                accent
            )
            .padding(
                .horizontal,
                26
            )
            .padding(
                .vertical,
                12
            )
            .background(
                Capsule()
                    .fill(
                        Color.white.opacity(
                            0.72
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func pickerField(
        title: String,
        systemImage: String,
        accent: Color,
        enabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(
                systemName:
                    systemImage
            )
            .font(
                .system(
                    size: 16,
                    weight: .bold
                )
            )
            .foregroundStyle(
                enabled
                    ? accent
                    : Color.gray.opacity(
                        0.42
                    )
            )

            Text(title)
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    enabled
                        ? Color.black
                            .opacity(0.78)
                        : Color.gray
                            .opacity(0.48)
                )
                .frame(
                    maxWidth: .infinity,
                    alignment:
                        isEnglish
                            ? .leading
                            : .trailing
                )

            Image(
                systemName:
                    "chevron.down"
            )
            .font(
                .system(
                    size: 12,
                    weight: .bold
                )
            )
            .foregroundStyle(
                accent.opacity(0.64)
            )
        }
        .padding(
            .horizontal,
            14
        )
        .padding(
            .vertical,
            14
        )
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                accent.opacity(
                    0.08
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                accent.opacity(
                    0.22
                ),
                lineWidth: 1
            )
        )
    }

    private func cardBackground(
        accent: Color
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 26,
            style: .continuous
        )
        .fill(
            Color.white.opacity(
                0.70
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                accent.opacity(
                    0.18
                ),
                lineWidth: 1
            )
        )
    }

    private func localizedBeltName(
        _ belt: Belt
    ) -> String {
        guard isEnglish else {
            return belt.heb
        }

        switch belt {
        case .white:
            return "White"
        case .yellow:
            return "Yellow"
        case .orange:
            return "Orange"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .brown:
            return "Brown"
        case .black:
            return "Black"
        default:
            return belt.heb
        }
    }

    private func localizedTopicTitle(
        _ title: String
    ) -> String {
        let clean =
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return KmiEnglishTitleResolver.title(
            for: clean,
            isEnglish: isEnglish
        )
    }

    private func tr(
        _ hebrew: String,
        _ english: String
    ) -> String {
        isEnglish
            ? english
            : hebrew
    }
}
