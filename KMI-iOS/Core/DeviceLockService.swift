import Foundation
import FirebaseAuth
import UIKit

struct DeviceLockVerifyResponse: Decodable {
    let ok: Bool
    let allowed: Bool?
    let reason: String?
    let lockStatus: String?
    let uid: String?
    let error: String?
    let message: String?
}

enum DeviceLockResult {
    case allowed(status: String?)
    case denied(reason: String?)
    case failed(message: String)
}

final class DeviceLockService {

    static let shared = DeviceLockService()
    private init() {}

    private let endpoint = "https://us-central1-app-1c22cc8d.cloudfunctions.net/verifyDeviceLock"

    func verifyCurrentUserDevice() async -> DeviceLockResult {
        guard let user = Auth.auth().currentUser else {
            print("KMI_DEVICE no current user")
            return .denied(reason: "no_current_user")
        }

        do {
            let idToken = try await user.getIDTokenResult(forcingRefresh: true).token

            guard let url = URL(string: endpoint) else {
                print("KMI_DEVICE invalid endpoint =", endpoint)
                return .failed(message: "invalid_endpoint_url")
            }

            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"

            print("KMI_DEVICE endpoint =", endpoint)
            print("KMI_DEVICE email =", user.email ?? "nil")
            print("KMI_DEVICE uid =", user.uid)
            print("KMI_DEVICE deviceId =", deviceId)

            let body: [String: Any] = [
                "deviceId": deviceId,
                "email": user.email ?? "",
                "phone": user.phoneNumber ?? "",
                "platform": "ios",
                "bundleId": Bundle.main.bundleIdentifier ?? ""
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                print("KMI_DEVICE invalid http response")
                return .failed(message: "invalid_http_response")
            }

            let rawText = String(data: data, encoding: .utf8) ?? "nil"
            print("KMI_DEVICE status =", http.statusCode)
            print("KMI_DEVICE raw response =", rawText)

            let decoded = try JSONDecoder().decode(DeviceLockVerifyResponse.self, from: data)

            if (200...299).contains(http.statusCode), decoded.allowed == true {
                print("KMI_DEVICE allowed lockStatus =", decoded.lockStatus ?? "nil")
                return .allowed(status: decoded.lockStatus)
            }

            if http.statusCode == 401 || http.statusCode == 403 || decoded.allowed == false {
                print("KMI_DEVICE denied reason =", decoded.reason ?? decoded.error ?? "nil")
                return .denied(reason: decoded.reason ?? decoded.error)
            }

            print("KMI_DEVICE failed message =", decoded.message ?? decoded.error ?? "unknown_server_error")
            return .failed(message: decoded.message ?? decoded.error ?? "unknown_server_error")
        } catch {
            print("KMI_DEVICE error =", error.localizedDescription)
            return .failed(message: error.localizedDescription)
        }
    }
}
