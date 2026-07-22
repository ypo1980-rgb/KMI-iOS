import SwiftUI
import UIKit

// MARK: - OnboardingView

/// מסך תוכן בלבד.
///
/// ContentView יעטוף אותו ב-KmiRootLayout כדי שלא
/// ייווצרו TopBar וסרגל אייקונים כפולים.
struct OnboardingView: View {

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = "he"

    let steps: [OnboardingStep]
    let allowSkip: Bool
    let onFinish: () -> Void
    let onSkip: () -> Void

    @State private var currentStepIndex = 0

    init(
        steps: [OnboardingStep] =
            OnboardingContent.steps,
        allowSkip: Bool = true,
        onFinish: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.steps = steps
        self.allowSkip = allowSkip
        self.onFinish = onFinish
        self.onSkip = onSkip
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }

    private var currentStep: OnboardingStep? {
        guard steps.indices.contains(
            currentStepIndex
        ) else {
            return nil
        }

        return steps[currentStepIndex]
    }

    private var isFirstStep: Bool {
        currentStepIndex == 0
    }

    private var isLastStep: Bool {
        currentStepIndex == steps.count - 1
    }

    var body: some View {
        Group {
            if let currentStep {
                content(for: currentStep)
            } else {
                Color.clear
                    .onAppear {
                        onFinish()
                    }
            }
        }
        .environment(
            \.layoutDirection,
            isEnglish ? .leftToRight : .rightToLeft
        )
    }

    private func content(
        for step: OnboardingStep
    ) -> some View {
        VStack(spacing: 0) {
            navigationHeader(
                step: step
            )

            stepCard(step)
                .id(step.id)
                .transition(
                    .asymmetric(
                        insertion:
                            .move(
                                edge:
                                    isEnglish
                                    ? .trailing
                                    : .leading
                            )
                            .combined(
                                with: .opacity
                            ),
                        removal:
                            .move(
                                edge:
                                    isEnglish
                                    ? .leading
                                    : .trailing
                            )
                            .combined(
                                with: .opacity
                            )
                    )
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            bottomBar(step: step)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0xFFF8FAFF),
                    step.accentColor.opacity(0.12),
                    Color(hex: 0xFFF4F0FF)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func navigationHeader(
        step: OnboardingStep
    ) -> some View {
        ZStack {
            progressIndicator(
                accentColor: step.accentColor
            )

            if allowSkip {
                HStack {
                    Button {
                        onSkip()
                    } label: {
                        Text(
                            isEnglish
                            ? "Skip"
                            : "דלג"
                        )
                        .font(
                            .system(
                                size: 13,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            Color(hex: 0xFF6D4ED8)
                        )
                        .padding(.horizontal, 8)
                        .frame(height: 34)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }

    private func progressIndicator(
        accentColor: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                ForEach(
                    steps.indices,
                    id: \.self
                ) { index in
                    let isSelected =
                        index == currentStepIndex

                    let isCompleted =
                        index < currentStepIndex

                    Capsule(
                        style: .continuous
                    )
                    .fill(
                        isSelected
                        ? accentColor
                        : (
                            isCompleted
                            ? accentColor.opacity(0.55)
                            : Color(hex: 0xFFD8DEE9)
                        )
                    )
                    .frame(
                        width: isSelected ? 28 : 7,
                        height: 7
                    )
                    .animation(
                        .spring(
                            response: 0.28,
                            dampingFraction: 0.85
                        ),
                        value: currentStepIndex
                    )
                }
            }

            Text(
                isEnglish
                ? "Step \(currentStepIndex + 1) of \(steps.count)"
                : "שלב \(currentStepIndex + 1) מתוך \(steps.count)"
            )
            .font(
                .system(
                    size: 11,
                    weight: .bold
                )
            )
            .foregroundStyle(
                Color(hex: 0xFF64748B)
            )
        }
    }

    private func stepCard(
        _ step: OnboardingStep
    ) -> some View {
        ScrollView(
            .vertical,
            showsIndicators: false
        ) {
            VStack(spacing: 8) {
                Text(
                    step.title(
                        isEnglish: isEnglish
                    )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    Color(hex: 0xFF111827)
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                onboardingImage(
                    for: step
                )

                Text(
                    step.description(
                        isEnglish: isEnglish
                    )
                )
                .font(
                    .system(
                        size: 14.5,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color(hex: 0xFF475569)
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
                .padding(.top, 2)
            }
            .padding(
                EdgeInsets(
                    top: 10,
                    leading: 16,
                    bottom: 14,
                    trailing: 16
                )
            )
        }
        .background(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.97)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .stroke(
                step.accentColor.opacity(0.18),
                lineWidth: 1
            )
        )
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 7
        )
    }

    @ViewBuilder
    private func onboardingImage(
        for step: OnboardingStep
    ) -> some View {
        if let imageName = step.imageName,
           let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: 316
                )
                .shadow(
                    color: step.accentColor.opacity(0.18),
                    radius: 12,
                    x: 0,
                    y: 7
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 322
                )
        } else {
            Image(
                systemName: systemImageName(
                    for: step.id
                )
            )
            .font(
                .system(
                    size: 48,
                    weight: .bold
                )
            )
            .foregroundStyle(
                step.accentColor
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 110
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    step.accentColor.opacity(0.10)
                )
            )
        }
    }

    private func bottomBar(
        step: OnboardingStep
    ) -> some View {
        HStack(spacing: 10) {
            if isFirstStep {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            } else {
                Button {
                    moveToPreviousStep()
                } label: {
                    Text(
                        isEnglish
                        ? "Previous"
                        : "הקודם"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color(hex: 0xFF475569)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            Color(hex: 0xFFD7DDEA),
                            lineWidth: 1
                        )
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                moveToNextStep()
            } label: {
                Text(nextButtonTitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .black
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    step.accentColor,
                                    Color(hex: 0xFF6D4ED8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(
            color: Color.black.opacity(0.09),
            radius: 10,
            x: 0,
            y: -4
        )
    }

    private var nextButtonTitle: String {
        if isLastStep {
            return isEnglish
            ? "Finish"
            : "סיום"
        }

        return isEnglish
        ? "Next"
        : "הבא"
    }

    private func moveToPreviousStep() {
        guard currentStepIndex > 0 else {
            return
        }

        withAnimation(
            .easeInOut(duration: 0.24)
        ) {
            currentStepIndex -= 1
        }
    }

    private func moveToNextStep() {
        if isLastStep {
            onFinish()
            return
        }

        withAnimation(
            .easeInOut(duration: 0.24)
        ) {
            currentStepIndex += 1
        }
    }

    private func systemImageName(
        for stepId: String
    ) -> String {
        switch stepId {
        case "welcome":
            return "house.fill"

        case "belts":
            return "line.3.horizontal"

        case "subjects":
            return "figure.martial.arts"

        case "knowledge_status":
            return "checkmark.circle.fill"

        case "exercise_cards":
            return "list.bullet.rectangle"

        case "internal_exam":
            return "checkmark.seal.fill"

        case "pdf":
            return "doc.richtext.fill"

        case "tools":
            return "square.grid.2x2.fill"

        default:
            return "questionmark.circle.fill"
        }
    }
}
