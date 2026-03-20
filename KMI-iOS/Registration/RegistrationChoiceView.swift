import SwiftUI

struct RegistrationChoiceView: View {

    let onNewUser: () -> Void
    let onExistingUser: () -> Void

    private let bannerHeight: CGFloat = 220

    var body: some View {
        ZStack {

            KmiGradientBackground()

            VStack(spacing: 0) {

                // ❌ הוסר: Top title (כבר מגיע מה-KmiRootLayout)
                // ❌ הוסר: Icons row (כבר מגיע מה-KmiRootLayout)

                // 🔥 Banner
                if let ui = bundleUIImage("nok_out_banner", ext: "jpeg") {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                } else {
                    // fallback ריק אם אין תמונה
                    Spacer().frame(height: bannerHeight)
                }

                Spacer().frame(height: 30)

                // 🔹 Buttons
                VStack(spacing: 18) {
                    BigChoiceButton(title: "משתמש חדש", action: onNewUser)
                    BigChoiceButton(title: "משתמש קיים", action: onExistingUser)
                }
                .padding(.horizontal, 32)

                Spacer()

                // 🔹 Logo
                if let ui = bundleUIImage("kami_logo", ext: "jpeg") {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .padding(.bottom, 8)
                }

                Text("❤️  פותחת באהבה ע\"י יובל פולק  ❤️")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - UI blocks

private struct BigChoiceButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private func bundleUIImage(_ name: String, ext: String = "jpeg") -> UIImage? {
    guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
    return UIImage(contentsOfFile: url.path)
}
