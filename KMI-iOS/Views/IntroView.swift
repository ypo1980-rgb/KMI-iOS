import SwiftUI
import UIKit
import FirebaseAuth

struct IntroView: View {

    let onContinue: () -> Void

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("initial_language_selected_code") private var initialLanguageSelectedCode: String = "he"
    @AppStorage("kmi.language.code") private var kmiLanguageCode: String = "he"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode,
            initialLanguageSelectedCode,
            kmiLanguageCode
        ]
        .map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        if values.contains("en") ||
            values.contains("eng") ||
            values.contains("english") {
            return true
        }

        if values.contains("he") ||
            values.contains("hebrew") ||
            values.contains("עברית") {
            return false
        }

        return Locale.preferredLanguages.first?
            .lowercased()
            .hasPrefix("en") == true
    }

    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private var firstName: String? {
        IntroUserSnapshot.loadFirstName()
    }

    private var greetingText: String {
        if let firstName, !firstName.isEmpty {
            return isEnglish ? "Hello, \(firstName)" : "שלום \(firstName)"
        }

        return isEnglish ? "Hello" : "שלום"
    }

    private var rank: IntroRankDisplay? {
        IntroRankDisplay.fromSavedBelt()
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let isCompactHeight = height < 760
            let horizontalPadding: CGFloat = isCompactHeight ? 24 : 30

            ZStack {
                Image("intro_welcome_screen_v2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: height * 0.185)

                    greetingCard(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer()
                        .frame(height: height * 0.455)

                    beltRow(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer(minLength: 0)

                    regularLoginButton(isCompactHeight: isCompactHeight)
                        .padding(.horizontal, horizontalPadding)

                    Spacer()
                        .frame(height: isCompactHeight ? 8 : 14)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .navigationBarBackButtonHidden()
    }

    private func greetingCard(isCompactHeight: Bool) -> some View {
        Text(greetingText)
            .font(
                .system(
                    size: isCompactHeight ? 22 : 26,
                    weight: .heavy,
                    design: .rounded
                )
            )
            .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
            .frame(height: isCompactHeight ? 38 : 42)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
    }

    @ViewBuilder
    private func beltRow(isCompactHeight: Bool) -> some View {
        if let rank {
            HStack(spacing: isCompactHeight ? 8 : 12) {
                Text(isEnglish ? rank.en : rank.he)
                    .font(
                        .system(
                            size: isCompactHeight ? 19 : 22,
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(rank.textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Image(rank.introBeltImageName)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(
                        width: isCompactHeight ? 112 : 128,
                        height: isCompactHeight ? 34 : 42
                    )
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompactHeight ? 40 : 46)
            .padding(.horizontal, 10)
        } else {
            Text(tr("עדיין לא עודכנה חגורה", "Belt has not been updated yet"))
                .font(
                    .system(
                        size: isCompactHeight ? 13 : 15,
                        weight: .heavy,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: isCompactHeight ? 40 : 46)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 22)
        }
    }

    private func regularLoginButton(isCompactHeight: Bool) -> some View {
        Button {
            onContinue()
        } label: {
            Text(tr("כניסה / רישום בדרך הרגילה", "Existing login / regular registration"))
                .font(
                    .system(
                        size: isCompactHeight ? 12 : 14,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.20))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: isCompactHeight ? 32 : 36)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Real user snapshot

private enum IntroUserSnapshot {

    static func loadFirstName() -> String? {
        let defaults = UserDefaults.standard
        let trimSet = CharacterSet.whitespacesAndNewlines

        let rawName = [
            defaults.string(forKey: "fullName"),
            defaults.string(forKey: "full_name"),
            defaults.string(forKey: "kmi.user.fullName"),
            defaults.string(forKey: "user_name"),
            defaults.string(forKey: "name"),
            defaults.string(forKey: "displayName"),
            defaults.string(forKey: "display_name"),
            defaults.string(forKey: "firstName"),
            defaults.string(forKey: "first_name"),
            Auth.auth().currentUser?.displayName
        ]
        .compactMap { $0 }
        .map { $0.trimmingCharacters(in: trimSet) }
        .first { !$0.isEmpty }

        if let rawName {
            let first = rawName
                .split(separator: " ", maxSplits: 1)
                .first
                .map(String.init)?
                .trimmingCharacters(in: trimSet)

            if let first, !first.isEmpty {
                return first
            }
        }

        let email = [
            defaults.string(forKey: "email"),
            defaults.string(forKey: "kmi.user.email"),
            Auth.auth().currentUser?.email
        ]
        .compactMap { $0 }
        .map { $0.trimmingCharacters(in: trimSet) }
        .first { !$0.isEmpty }

        let emailPrefix = email?
            .split(separator: "@")
            .first
            .map(String.init)?
            .trimmingCharacters(in: trimSet)

        if let emailPrefix, !emailPrefix.isEmpty {
            return emailPrefix
        }

        return nil
    }

    static func loadBeltId() -> String? {
        let defaults = UserDefaults.standard
        let trimSet = CharacterSet.whitespacesAndNewlines

        return [
            defaults.string(forKey: "current_belt"),
            defaults.string(forKey: "belt_current"),
            defaults.string(forKey: "currentBelt"),
            defaults.string(forKey: "beltId"),
            defaults.string(forKey: "belt_id"),
            defaults.string(forKey: "belt"),
            defaults.string(forKey: "belt_id_str")
        ]
        .compactMap { $0 }
        .map {
            $0
                .trimmingCharacters(in: trimSet)
                .lowercased()
        }
        .first { !$0.isEmpty }
    }
}

// MARK: - Rank display

private struct IntroRankDisplay {
    let id: String
    let he: String
    let en: String
    let color: Color

    var textColor: Color {
        id == "white"
        ? Color(red: 0.60, green: 0.64, blue: 0.70)
        : color
    }

    var introBeltImageName: String {
        switch id {
        case "white":
            return "belt_white"
        case "yellow":
            return "belt_yellow"
        case "orange":
            return "belt_orange"
        case "green":
            return "belt_green"
        case "blue":
            return "belt_blue"
        case "brown":
            return "belt_brown"
        default:
            return "belt_black"
        }
    }

    static func fromSavedBelt() -> IntroRankDisplay? {
        from(raw: IntroUserSnapshot.loadBeltId())
    }

    static func from(raw: String?) -> IntroRankDisplay? {
        let value = raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        switch value {
        case "white", "לבן", "לבנה":
            return IntroRankDisplay(
                id: "white",
                he: "לבנה",
                en: "White belt",
                color: Color(red: 0.94, green: 0.94, blue: 0.94)
            )

        case "yellow", "צהוב", "צהובה":
            return IntroRankDisplay(
                id: "yellow",
                he: "צהובה",
                en: "Yellow belt",
                color: Color(red: 1.00, green: 0.88, blue: 0.12)
            )

        case "orange", "כתום", "כתומה":
            return IntroRankDisplay(
                id: "orange",
                he: "כתומה",
                en: "Orange belt",
                color: Color(red: 1.00, green: 0.48, blue: 0.10)
            )

        case "green", "ירוק", "ירוקה":
            return IntroRankDisplay(
                id: "green",
                he: "ירוקה",
                en: "Green belt",
                color: Color(red: 0.20, green: 0.70, blue: 0.32)
            )

        case "blue", "כחול", "כחולה":
            return IntroRankDisplay(
                id: "blue",
                he: "כחולה",
                en: "Blue belt",
                color: Color(red: 0.15, green: 0.48, blue: 0.92)
            )

        case "brown", "חום", "חומה":
            return IntroRankDisplay(
                id: "brown",
                he: "חומה",
                en: "Brown belt",
                color: Color(red: 0.42, green: 0.26, blue: 0.16)
            )

        case "black", "שחור", "שחורה", "שחורה דאן 1":
            return IntroRankDisplay(
                id: "black",
                he: "שחורה דאן 1",
                en: "Black belt Dan 1",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_2", "שחורה דאן 2":
            return IntroRankDisplay(
                id: "black_dan_2",
                he: "שחורה דאן 2",
                en: "Black belt Dan 2",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_3", "שחורה דאן 3":
            return IntroRankDisplay(
                id: "black_dan_3",
                he: "שחורה דאן 3",
                en: "Black belt Dan 3",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_4", "שחורה דאן 4":
            return IntroRankDisplay(
                id: "black_dan_4",
                he: "שחורה דאן 4",
                en: "Black belt Dan 4",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_5", "שחורה דאן 5":
            return IntroRankDisplay(
                id: "black_dan_5",
                he: "שחורה דאן 5",
                en: "Black belt Dan 5",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_6", "שחורה דאן 6":
            return IntroRankDisplay(
                id: "black_dan_6",
                he: "שחורה דאן 6",
                en: "Black belt Dan 6",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_7", "שחורה דאן 7":
            return IntroRankDisplay(
                id: "black_dan_7",
                he: "שחורה דאן 7",
                en: "Black belt Dan 7",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_8", "שחורה דאן 8":
            return IntroRankDisplay(
                id: "black_dan_8",
                he: "שחורה דאן 8",
                en: "Black belt Dan 8",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_9", "שחורה דאן 9":
            return IntroRankDisplay(
                id: "black_dan_9",
                he: "שחורה דאן 9",
                en: "Black belt Dan 9",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_10", "שחורה דאן 10":
            return IntroRankDisplay(
                id: "black_dan_10",
                he: "שחורה דאן 10",
                en: "Black belt Dan 10",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        default:
            return nil
        }
    }
}
