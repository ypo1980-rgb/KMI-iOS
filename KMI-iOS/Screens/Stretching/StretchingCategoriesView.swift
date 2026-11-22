import SwiftUI
import Shared

struct StretchingCategoriesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("kmi_app_language") private var languageCode = "he"

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    private var isEnglish: Bool {
        ["en", "english"].contains(languageCode.lowercased())
    }

    var body: some View {
        let categories = StretchingCatalog.shared.categoriesWithContent()

        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(isEnglish ? "Choose a body area" : "בחרו אזור גוף")
                    .kmiTypography(.action)

                Text(
                    isEnglish
                        ? "Stretch gently at your own pace"
                        : "מבצעים בעדינות ובקצב אישי"
                )
                .kmiTypography(.action)
            }
            .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 44)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: KmiAppTheme.sectionTabsHeight)
            .background(KmiAppTheme.sectionHeaderBrush)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                        NavigationLink {
                            StretchingCategoryView(category: category, isEnglish: isEnglish)
                        } label: {
                            categoryCard(for: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func categoryCard(for category: StretchingCategory) -> some View {
        let count = StretchingCatalog.shared.exerciseCountFor(category: category)
        let countLabel = isEnglish
            ? (count == 1 ? "1 exercise" : "\(count) exercises")
            : (count == 1 ? "תרגיל אחד" : "\(count) תרגילים")
        let resourceName = Self.categoryImageNames[category.name]
        let image = resourceName.flatMap { StretchingImageResolver.image(named: $0) }
        let contentColor = KmiAppTheme.onSurface(for: colorScheme)
        let outline = KmiAppTheme.outline(for: colorScheme)
        let imageShape = RoundedRectangle(cornerRadius: 14)
        let cardShape = RoundedRectangle(cornerRadius: 20)

        return VStack(spacing: 8) {
            imageShape
                .fill(contentColor.opacity(0.07))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(systemName: "figure.flexibility")
                            .foregroundStyle(contentColor.opacity(0.55))
                    }
                }
                .clipShape(imageShape)
                .overlay {
                    imageShape.strokeBorder(outline.opacity(0.5), lineWidth: 1)
                }
                .accessibilityHidden(true)

            Text(Self.title(for: category, isEnglish: isEnglish))
                .kmiTypography(.cardTitle)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity)

            Text(countLabel)
                .kmiTypography(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(contentColor.opacity(0.08), in: Capsule())
        }
        .foregroundStyle(contentColor)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(KmiAppTheme.surface(for: colorScheme), in: cardShape)
        .overlay {
            cardShape.strokeBorder(outline, lineWidth: 1)
        }
        .contentShape(cardShape)
        .accessibilityElement(children: .combine)
    }

    private static let categoryImageNames: [String: String] = [
        "NECK_AND_HEAD": "stretching_category_neck_head",
        "SHOULDERS_AND_ARMS": "stretching_category_shoulders_arms",
        "UPPER_BACK": "stretching_category_upper_back",
        "LOWER_BACK": "stretching_category_lower_back",
        "HIPS_AND_GROIN": "stretching_category_hips_groin",
        "LEGS": "stretching_category_legs",
        "KNEES_AND_ANKLES": "stretching_category_knees_ankles",
        "FULL_BODY": "stretching_category_full_body"
    ]

    static func title(for category: StretchingCategory, isEnglish: Bool) -> String {
        let labels: (String, String)

        switch category.name {
        case "NECK_AND_HEAD": labels = ("צוואר וראש", "Neck and head")
        case "SHOULDERS_AND_ARMS": labels = ("כתפיים וידיים", "Shoulders and arms")
        case "UPPER_BACK": labels = ("גב עליון", "Upper back")
        case "LOWER_BACK": labels = ("גב תחתון", "Lower back")
        case "HIPS_AND_GROIN": labels = ("אגן ומפשעה", "Hips and groin")
        case "LEGS": labels = ("רגליים", "Legs")
        case "KNEES_AND_ANKLES": labels = ("ברכיים וקרסוליים", "Knees and ankles")
        case "FULL_BODY": labels = ("כל הגוף", "Full body")
        default: labels = ("מתיחות", "Stretching")
        }

        return isEnglish ? labels.1 : labels.0
    }
}
