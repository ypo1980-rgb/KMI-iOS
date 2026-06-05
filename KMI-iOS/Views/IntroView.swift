import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import FirebaseAuth

struct IntroView: View {

    let onContinue: () -> Void

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        .map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        return values.contains("en") ||
            values.contains("eng") ||
            values.contains("english")
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
        ZStack {
            IntroGradientBackground()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 8) {
                    Text(isEnglish ? "K.M.I" : "ק.מ.י")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(tr("קרב מגן ישראלי", "Israeli Krav Magen"))
                        .font(.system(size: isEnglish ? 23 : 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(greetingText)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                if let rank {
                    OrangeBeltRibbon(
                        text: isEnglish ? rank.en : rank.he,
                        color: rank.color
                    )
                    .padding(.top, 6)
                }

                FightersImage(
                    removeWhiteBg: true,
                    isEnglish: isEnglish
                )
                .padding(.top, 6)

                Spacer(minLength: 18)

                Button {
                    onContinue()
                } label: {
                    Text(tr("כניסה / רישום בדרך הרגילה", "Use existing login / sign up screen"))
                        .font(.system(size: isEnglish ? 15 : 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)

                Spacer(minLength: 26)
            }
        }
        .environment(\.layoutDirection, layoutDirection)
        .navigationBarBackButtonHidden()
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
                he: "חגורה לבנה",
                en: "White belt",
                color: Color(red: 0.94, green: 0.94, blue: 0.94)
            )

        case "yellow", "צהוב", "צהובה":
            return IntroRankDisplay(
                id: "yellow",
                he: "חגורה צהובה",
                en: "Yellow belt",
                color: Color(red: 1.00, green: 0.88, blue: 0.12)
            )

        case "orange", "כתום", "כתומה":
            return IntroRankDisplay(
                id: "orange",
                he: "חגורה כתומה",
                en: "Orange belt",
                color: Color(red: 1.00, green: 0.48, blue: 0.10)
            )

        case "green", "ירוק", "ירוקה":
            return IntroRankDisplay(
                id: "green",
                he: "חגורה ירוקה",
                en: "Green belt",
                color: Color(red: 0.20, green: 0.70, blue: 0.32)
            )

        case "blue", "כחול", "כחולה":
            return IntroRankDisplay(
                id: "blue",
                he: "חגורה כחולה",
                en: "Blue belt",
                color: Color(red: 0.15, green: 0.48, blue: 0.92)
            )

        case "brown", "חום", "חומה":
            return IntroRankDisplay(
                id: "brown",
                he: "חגורה חומה",
                en: "Brown belt",
                color: Color(red: 0.42, green: 0.26, blue: 0.16)
            )

        case "black", "שחור", "שחורה", "שחורה דאן 1":
            return IntroRankDisplay(
                id: "black",
                he: "חגורה שחורה דאן 1",
                en: "Black belt Dan 1",
                color: Color(red: 0.04, green: 0.04, blue: 0.04)
            )

        case "black_dan_2":
            return IntroRankDisplay(id: "black_dan_2", he: "חגורה שחורה דאן 2", en: "Black belt Dan 2", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_3":
            return IntroRankDisplay(id: "black_dan_3", he: "חגורה שחורה דאן 3", en: "Black belt Dan 3", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_4":
            return IntroRankDisplay(id: "black_dan_4", he: "חגורה שחורה דאן 4", en: "Black belt Dan 4", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_5":
            return IntroRankDisplay(id: "black_dan_5", he: "חגורה שחורה דאן 5", en: "Black belt Dan 5", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_6":
            return IntroRankDisplay(id: "black_dan_6", he: "חגורה שחורה דאן 6", en: "Black belt Dan 6", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_7":
            return IntroRankDisplay(id: "black_dan_7", he: "חגורה שחורה דאן 7", en: "Black belt Dan 7", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_8":
            return IntroRankDisplay(id: "black_dan_8", he: "חגורה שחורה דאן 8", en: "Black belt Dan 8", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_9":
            return IntroRankDisplay(id: "black_dan_9", he: "חגורה שחורה דאן 9", en: "Black belt Dan 9", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        case "black_dan_10":
            return IntroRankDisplay(id: "black_dan_10", he: "חגורה שחורה דאן 10", en: "Black belt Dan 10", color: Color(red: 0.04, green: 0.04, blue: 0.04))

        default:
            return nil
        }
    }
}

// MARK: - Background (כמו בתמונה: סגול->תכלת + עיגולים עדינים)

private struct IntroGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.17, blue: 0.64), // סגול
                    Color(red: 0.13, green: 0.66, blue: 0.95)  // תכלת
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            // עיגולי “בוקה” עדינים כמו במסך שלך
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 0.5)
                .offset(x: 140, y: -40)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 0.5)
                .offset(x: -140, y: 220)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 160, height: 160)
                .blur(radius: 0.5)
                .offset(x: 40, y: 260)
        }
    }
}

// MARK: - Orange Belt Ribbon

private struct OrangeBeltRibbon: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.martial.arts")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white.opacity(0.95))

            Text(text)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.95),
                            color.opacity(0.72)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(radius: 10, y: 5)
    }
}

// MARK: - Image wrapper (Assets first, Bundle fallback)

private struct FightersImage: View {

    let removeWhiteBg: Bool
    let isEnglish: Bool

    var body: some View {
        Group {
            if let ui = UIImage(named: "fighters") {
                imageView(ui)

            } else if let ui = bundleUIImage("fighters", ext: "png")
                        ?? bundleUIImage("fighters", ext: "jpeg")
                        ?? bundleUIImage("fighters", ext: "jpg") {
                imageView(ui)

            } else {
                Text(
                    isEnglish
                    ? "Missing image: fighters"
                    : "חסרה תמונה: fighters"
                )
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func imageView(_ ui: UIImage) -> some View {
        let final = removeWhiteBg ? ui.removingNearWhiteBackground(threshold: 0.92) : ui

        Image(uiImage: final ?? ui)
            .resizable()
            .scaledToFit()
            .frame(width: 320, height: 260)
            .shadow(radius: 12, y: 6)
            .accessibilityLabel(isEnglish ? "fighters" : "לוחמים")
    }

    private func bundleUIImage(_ name: String, ext: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: - CoreImage: Remove near-white background (chroma-key style)

private extension UIImage {

    /// הופך פיקסלים "כמעט לבנים" לשקופים.
    /// threshold: 0.0..1.0 (0.92 טוב לרקע לבן)
    func removingNearWhiteBackground(threshold: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        let cubeSize = 64
        let cubeData = Self.makeColorCubeData(size: cubeSize, threshold: threshold)

        guard let filter = CIFilter(name: "CIColorCube") else { return nil }
        filter.setValue(cubeSize, forKey: "inputCubeDimension")
        filter.setValue(cubeData, forKey: "inputCubeData")
        filter.setValue(ciImage, forKey: kCIInputImageKey)

        guard let output = filter.outputImage else { return nil }
        guard let outCG = context.createCGImage(output, from: output.extent) else { return nil }

        return UIImage(cgImage: outCG, scale: self.scale, orientation: self.imageOrientation)
    }

    static func makeColorCubeData(size: Int, threshold: CGFloat) -> Data {
        // RGBA float32 * size^3
        let count = size * size * size * 4
        var data = [Float](repeating: 0, count: count)

        var offset = 0
        for z in 0..<size {
            let b = Float(z) / Float(size - 1)
            for y in 0..<size {
                let g = Float(y) / Float(size - 1)
                for x in 0..<size {
                    let r = Float(x) / Float(size - 1)

                    // אם הפיקסל "כמעט לבן" -> alpha 0
                    let isNearWhite = (r >= Float(threshold) && g >= Float(threshold) && b >= Float(threshold))
                    let a: Float = isNearWhite ? 0.0 : 1.0

                    data[offset + 0] = r
                    data[offset + 1] = g
                    data[offset + 2] = b
                    data[offset + 3] = a
                    offset += 4
                }
            }
        }

        return Data(bytes: data, count: data.count * MemoryLayout<Float>.size)
    }
}
