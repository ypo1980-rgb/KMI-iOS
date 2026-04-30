import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct IntroView: View {

    let onContinue: () -> Void

    var body: some View {
        ZStack {
            IntroGradientBackground()

            VStack(spacing: 18) {

                TestFlightBanner()

                Spacer()

                VStack(spacing: 8) {
                    Text("ק.מ.י")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("קרב מגן ישראלי")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("שלום יובל")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.92))
                }

                // ✅ “חגורה כתומה” (רצועה מעוצבת)
                OrangeBeltRibbon(text: "חגורה כתומה")
                    .padding(.top, 6)

                // ✅ תמונה (עם ניסיון להסרת רקע לבן)
                FightersImage(removeWhiteBg: true)
                    .padding(.top, 6)

                Spacer(minLength: 18)

                Button {
                    onContinue()
                } label: {
                    Text("מעבר למסך כניסה / רישום")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
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
        .navigationBarBackButtonHidden()
        .onAppear {
            // לוגים שמורים אצלך — אפשר להשאיר
            let ok = UIImage(named: "fighters") != nil
            print("✅ IntroView appeared. UIImage(named:\"fighters\") = \(ok ? "FOUND" : "nil")")

            let p1 = Bundle.main.path(forResource: "fighters", ofType: "jpeg")
            let p2 = Bundle.main.path(forResource: "fighters", ofType: "jpg")
            let p3 = Bundle.main.path(forResource: "fighters", ofType: "png")
            print("fighters.jpeg path = \(p1 ?? "nil")")
            print("fighters.jpg  path = \(p2 ?? "nil")")
            print("fighters.png  path = \(p3 ?? "nil")")
            print("Bundle path = \(Bundle.main.bundlePath)")
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.martial.arts")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white.opacity(0.95))

            Text(text)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.55, blue: 0.10),
                            Color(red: 1.00, green: 0.36, blue: 0.12)
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

    /// אם התמונה אצלך עם לבן (jpg) זה יוריד אותו כמעט לגמרי.
    /// אם יש לך PNG עם שקיפות אמיתית — אפשר לשים false.
    let removeWhiteBg: Bool

    var body: some View {
        Group {
            if let ui = UIImage(named: "fighters") {
                imageView(ui)

            } else if let ui = bundleUIImage("fighters", ext: "png")
                        ?? bundleUIImage("fighters", ext: "jpeg")
                        ?? bundleUIImage("fighters", ext: "jpg") {
                imageView(ui)

            } else {
                Text("❌ Missing image: fighters (Assets/Bundled)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.95))
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
            // ❌ הורדנו את הרקע/כרטיס שהוספנו קודם
            .shadow(radius: 12, y: 6)
            .accessibilityLabel("fighters")
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
