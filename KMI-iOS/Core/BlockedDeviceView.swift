import SwiftUI

struct BlockedDeviceView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)

                Text("גישה חסומה")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            .padding(24)
        }
    }
}
