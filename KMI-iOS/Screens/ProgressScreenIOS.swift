import SwiftUI
import Shared

struct ProgressScreenIOS: View {

    let onOpenCarousel: () -> Void

    init(
        onOpenCarousel: @escaping () -> Void
    ) {
        self.onOpenCarousel = onOpenCarousel
    }

    @StateObject private var vm = ProgressViewModel()
    @Environment(\.colorScheme) private var colorScheme

    // אין State פנימי למסך הסטטיסטיקה.
    // ניווט ושיתוף נשארים בסרגל הגלובלי.
    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    
    private var effectiveLanguageCode: String {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        
        for raw in values {
            let clean = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            if clean == "en" || clean == "english" {
                return "en"
            }
            
            if clean == "he" || clean == "hebrew" || clean == "עברית" {
                return "he"
            }
        }
        
        return "he"
    }
    
    private var isEnglish: Bool {
        effectiveLanguageCode == "en"
    }
    
    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(tr("ההישגים שלי לפי חגורות", "My Achievements by Belt"))
                .kmiTypography(.sectionTitle)
                .fontWeight(.heavy)
                .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .background(KmiAppTheme.sectionHeaderBrush)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                KmiAppBackground()
                    .ignoresSafeArea()

                if vm.rows.isEmpty {
                    VStack(spacing: 14) {
                        KmiLoadingOverlay()

                        Text(tr("טוען נתוני התקדמות...", "Loading progress..."))
                            .kmiTypography(.sectionTitle)
                            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                            .multilineTextAlignment(.center)

                        Text(tr("מסדר את נתוני החגורות שלך", "Preparing your belt data"))
                            .kmiTypography(.secondary)
                            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(vm.rows.filter { $0.belt != .white }) { row in
                                BeltProgressCard(
                                    row: row,
                                    isEnglish: isEnglish
                                )
                            }
                            
                            Spacer(minLength: 24)
                        }
                        .padding(16)
                    }
                }
            }
            
            Button {
                onOpenCarousel()
            } label: {
                Text(tr("מעבר למסך התרגילים", "Go to Exercises"))
                    .kmiTypography(.action)
                    .fontWeight(.heavy)
                    .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        KmiAppTheme.graniteActionBrush,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            vm.loadProgress()
        }
    }
}

private struct BeltProgressCard: View {
    let row: ProgressViewModel.BeltProgress
    let isEnglish: Bool

    private var titleText: String {
        if isEnglish {
            return "Belt: \(row.title)"
        }

        let clean = row.title
            .replacingOccurrences(of: "חגורה:", with: "")
            .replacingOccurrences(of: "חגורה", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return "חגורה: \(clean)"
    }

    private var countText: String {
        isEnglish
        ? "(\(row.done) of \(row.total))"
        : "(\(row.done) מתוך \(row.total))"
    }

    @Environment(\.colorScheme) private var colorScheme

    private var beltAccent: Color {
        row.belt == .black
            ? KmiAppTheme.onSurface(for: colorScheme)
            : row.color
    }

    private var badgeTextColor: Color {
        row.belt == .black
            ? KmiAppTheme.surface(for: colorScheme)
            : .white
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? KmiAppTheme.surfaceVariant(for: colorScheme)
            : row.color.opacity(0.20)
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Text("\(row.percent)%")
                    .kmiTypography(.metric)
                    .foregroundStyle(badgeTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(beltAccent.opacity(0.90))
                    )

                Text(titleText)
                    .kmiTypography(.sectionTitle)
                    .fontWeight(.heavy)
                    .foregroundStyle(beltAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Circle()
                    .fill(beltAccent)
                    .frame(width: 13, height: 13)
            }

            GeometryReader { geo in
                let fraction = row.total > 0
                    ? min(1, max(0, CGFloat(row.done) / CGFloat(row.total)))
                    : 0

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(KmiAppTheme.onSurface(for: colorScheme).opacity(0.08))

                    Capsule(style: .continuous)
                        .fill(beltAccent)
                        .frame(width: geo.size.width * fraction)
                        .animation(.easeInOut(duration: 0.25), value: fraction)
                }
            }
            .frame(height: 12)

            Text(countText)
                .kmiTypography(.secondary)
                .fontWeight(.semibold)
                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(beltAccent.opacity(0.75), lineWidth: 2)
        )
    }
}

private struct PremiumProgressLoadingIOS: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            Color(red: 0.49, green: 0.23, blue: 0.93),
                            Color(red: 0.22, green: 0.74, blue: 0.97),
                            .clear
                        ],
                        center: .center
                    ),
                    lineWidth: 5
                )
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            Color(red: 0.96, green: 0.62, blue: 0.04),
                            Color(red: 0.13, green: 0.77, blue: 0.36),
                            .clear
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 62, height: 62)
                .rotationEffect(.degrees(isAnimating ? -360 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.95, green: 0.91, blue: 1.00),
                            Color(red: 0.88, green: 0.95, blue: 1.00)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 18
                    )
                )
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(Color(red: 0.91, green: 0.84, blue: 1.00), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
        }
        .frame(width: 96, height: 96)
        .onAppear {
            withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
