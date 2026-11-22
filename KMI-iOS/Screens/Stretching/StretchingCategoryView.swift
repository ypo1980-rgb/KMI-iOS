import SwiftUI
import Shared

struct StretchingCategoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var nav: AppNavModel

    let category: StretchingCategory
    let isEnglish: Bool

    var body: some View {
        let exercises = StretchingCatalog.shared.exercisesFor(category: category)
            .sorted { $0.sortOrder < $1.sortOrder }

        KmiRootLayout(
            title: StretchingCategoriesView.title(for: category, isEnglish: isEnglish),
            nav: nav,
            selectedIcon: .home,
            showShareAction: false,
            onBackOverride: { dismiss() }
        ) {
            VStack(spacing: 0) {
                Text(isEnglish
                     ? "\(exercises.count) exercises\nPerform gently and at your own pace"
                     : "\(exercises.count) תרגילים\nמבצעים בעדינות ובקצב אישי")
                    .kmiTypography(.action)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: KmiAppTheme.sectionTabsHeight)
                    .background(KmiAppTheme.sectionHeaderBrush)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                            NavigationLink {
                                StretchingExerciseView(exercise: exercise, isEnglish: isEnglish)
                            } label: {
                                exerciseCard(exercise, number: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
    }

    private func exerciseCard(_ exercise: StretchingExercise, number: Int) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: 19)
        let thumbnailShape = RoundedRectangle(cornerRadius: 16)
        let accent = KmiAppTheme.primary(for: colorScheme)
        let surface = KmiAppTheme.surface(for: colorScheme)
        let outline = KmiAppTheme.outline(for: colorScheme)

        return HStack(spacing: 11) {
            thumbnailShape
                .fill(accent.opacity(0.10))
                .frame(width: 72, height: 72)
                .overlay {
                    if let image = StretchingImageResolver.image(for: exercise.imageKey) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                            .frame(width: 72, height: 72)
                    }
                }
                .clipShape(thumbnailShape)
                .overlay {
                    thumbnailShape.strokeBorder(accent.opacity(0.30), lineWidth: 1)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(number.formatted())
                        .kmiTypography(.caption)
                        .fontWeight(.heavy)
                        .frame(width: 24, height: 24)
                        .background(surface, in: Circle())
                        .overlay {
                            Circle().strokeBorder(accent.opacity(0.35), lineWidth: 1)
                        }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(isEnglish ? exercise.titleEn : exercise.titleHe)
                    .kmiTypography(.body)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                exerciseBadges(exercise)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(surface, in: cardShape)
        .overlay {
            cardShape.strokeBorder(outline.opacity(0.45), lineWidth: 1)
        }
        .contentShape(cardShape)
        .accessibilityElement(children: .combine)
    }

    private func exerciseBadges(_ exercise: StretchingExercise) -> some View {
        let duration = exercise.durationSeconds
        var labels = [isEnglish ? "\(duration) sec" : "\(duration) שנ׳"]

        if let repetitions = exercise.repetitions {
            labels.append(isEnglish ? "\(repetitions) reps" : "\(repetitions) חזרות")
        }

        if exercise.performBothSides {
            labels.append(isEnglish ? "Both sides" : "שני הצדדים")
        }

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(labels, id: \.self) { label in
                    exerciseBadge(label)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(labels, id: \.self) { label in
                    exerciseBadge(label)
                }
            }
        }
    }

    private func exerciseBadge(_ title: String) -> some View {
        Text(title)
            .kmiTypography(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                KmiAppTheme.onSurface(for: colorScheme).opacity(0.08),
                in: Capsule()
            )
    }
}
