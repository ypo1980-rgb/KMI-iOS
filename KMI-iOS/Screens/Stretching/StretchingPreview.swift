import SwiftUI
import UIKit
import Shared

struct StretchingPreview: View {
    var body: some View {
        ZStack {
            KmiAppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    if let exercise = StretchingCatalog.shared.exerciseById(
                        exerciseId: "neck_chin_tuck"
                    ) {
                        Text(exercise.titleHe)
                            .kmiTypography(.cardTitle)

                        if let url = Bundle.main.url(
                            forResource: "stretching_neck_chin_tuck_start",
                            withExtension: "webp",
                            subdirectory: "Stretching"
                        ),
                        let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .accessibilityHidden(true)
                        } else {
                            Text("תמונת המתיחה לא נטענה")
                                .kmiTypography(.secondary)
                        }

                        Text(exercise.instructionsHe)
                            .kmiTypography(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("התרגיל לא נמצא בקטלוג המתיחות")
                            .kmiTypography(.secondary)
                    }
                }
                .padding(16)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    StretchingPreview()
}
