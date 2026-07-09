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
    
    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }
    
    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }
    
    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                if vm.rows.isEmpty {
                    VStack(spacing: 14) {
                        PremiumProgressLoadingIOS()
                        
                        Text(tr("טוען נתוני התקדמות...", "Loading progress data..."))
                            .font(.system(size: 19, weight: .heavy))
                            .foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.29))
                            .multilineTextAlignment(.center)
                        
                        Text(tr("מסדר את נתוני החגורות שלך", "Organizing your belt progress"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.48, green: 0.45, blue: 0.53))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
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
                Text(tr("מעבר למסך התרגילים", "Go to exercises"))
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.16, blue: 0.22))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.white)
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

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Text("\(row.percent)%")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(row.color.opacity(0.90))
                    )

                Spacer(minLength: 10)

                Text(titleText)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(row.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)

                Circle()
                    .fill(row.color)
                    .frame(width: 14, height: 14)
            }

            GeometryReader { geo in
                ZStack(alignment: isEnglish ? .leading : .trailing) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.08))

                    Capsule(style: .continuous)
                        .fill(row.color)
                        .frame(
                            width: max(
                                0,
                                geo.size.width * CGFloat(row.total == 0 ? 0 : Double(row.done) / Double(row.total))
                            )
                        )
                }
            }
            .frame(height: 12)

            Text(countText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(row.color.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(row.color.opacity(0.75), lineWidth: 2)
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
