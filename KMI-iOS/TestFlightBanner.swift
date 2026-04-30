import SwiftUI

struct TestFlightBanner: View {

    var show: Bool = true

    var body: some View {

        if TestFlightDetector.isTestFlight && show {

            Text("TESTFLIGHT BUILD")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.9))
                )
                .padding(.top, 6)
        }
    }
}
