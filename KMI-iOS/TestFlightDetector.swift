import Foundation

enum TestFlightDetector {

    static var isTestFlight: Bool {

        #if targetEnvironment(simulator)
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif

    }
}
