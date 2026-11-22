import SwiftUI
import UIKit
import Shared

struct StretchingExerciseView: View {
    let exercise: StretchingExercise
    let isEnglish: Bool

    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let image = StretchingImageResolver.image(for: exercise.imageKey) {
                        illustration(image)
                    }

                    Text(isEnglish ? exercise.instructionsEn : exercise.instructionsHe)
                        .kmiTypography(.body)

                    let safetyNote = isEnglish ? exercise.safetyNoteEn : exercise.safetyNoteHe
                    if let safetyNote = safetyNote as String?, !safetyNote.isEmpty {
                        Text(safetyNote)
                            .kmiTypography(.secondary)
                    }

                    ForEach(Array(exercise.visualSteps.enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isEnglish ? "Step \(index + 1)" : "שלב \(index + 1)")
                                .kmiTypography(.cardTitle)
                                .accessibilityAddTraits(.isHeader)

                            if let image = StretchingImageResolver.image(for: step.imageKey) {
                                illustration(image)
                            }

                            Text(isEnglish ? step.instructionEn : step.instructionHe)
                                .kmiTypography(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .navigationTitle(isEnglish ? exercise.titleEn : exercise.titleHe)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func illustration(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 240)
            .accessibilityHidden(true)
    }
}
