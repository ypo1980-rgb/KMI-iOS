import SwiftUI

struct RegistrationChoiceView: View {

    let onNewUserTrainee: () -> Void
    let onExistingUserTrainee: () -> Void
    let onNewUserCoach: () -> Void
    let onExistingUserCoach: () -> Void

    private let bannerHeight: CGFloat = 220

    var body: some View {
        ZStack {
            KmiGradientBackground()

            VStack(spacing: 0) {
                if let ui = bundleUIImage("nok_out_banner", ext: "jpeg") {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                } else {
                    Spacer().frame(height: bannerHeight)
                }

                Spacer().frame(height: 24)

                VStack(spacing: 14) {
                    BigChoiceButton(title: "משתמש חדש – מתאמן", action: onNewUserTrainee)
                    BigChoiceButton(title: "משתמש קיים – מתאמן", action: onExistingUserTrainee)
                    BigChoiceButton(title: "משתמש חדש – מאמן", action: onNewUserCoach)
                    BigChoiceButton(title: "משתמש קיים – מאמן", action: onExistingUserCoach)
                }
                .padding(.horizontal, 28)

                Spacer()

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
