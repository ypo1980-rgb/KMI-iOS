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

    private let authorizedUidKey = "kmi.device.authorized.uid"
    private let authorizedAtMillisKey = "kmi.device.authorized.at_millis"
    private let lastStatusKey = "kmi.device.lock.status"
    private let lastReasonKey = "kmi.device.lock.reason"

    func verifyCurrentUserDevice() async -> DeviceLockResult {
        guard let user = Auth.auth().currentUser else {
            clearDeviceAuthorization(reason: "no_current_user")
            return .denied(reason: "no_current_user")
        }

        do {
            let idToken = try await user.getIDTokenResult(forcingRefresh: true).token

            guard let url = URL(string: endpoint) else {
                clearDeviceAuthorization(reason: "invalid_endpoint_url")
                return .failed(message: "invalid_endpoint_url")
            }

            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"

            let body: [String: Any] = [
                "deviceId": deviceId,
                "email": user.email ?? "",
                "phone": user.phoneNumber ?? "",
                "platform": "ios",
                "bundleId": Bundle.main.bundleIdentifier ?? ""
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 18
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                clearDeviceAuthorization(reason: "invalid_http_response")
                return .failed(message: "invalid_http_response")
            }

            let decoded: DeviceLockVerifyResponse

            do {
                decoded = try JSONDecoder().decode(DeviceLockVerifyResponse.self, from: data)
            } catch {
                clearDeviceAuthorization(reason: "invalid_server_response")
                return .failed(message: "invalid_server_response")
            }

            if (200...299).contains(http.statusCode), decoded.allowed == true {
                persistDeviceAuthorization(
                    uid: decoded.uid ?? user.uid,
                    status: decoded.lockStatus
                )

                return .allowed(status: decoded.lockStatus)
            }

            if http.statusCode == 401 || http.statusCode == 403 || decoded.allowed == false {
                let reason = decoded.reason ?? decoded.error ?? "device_not_allowed"
                clearDeviceAuthorization(reason: reason)
                return .denied(reason: reason)
            }

            let message = decoded.message ?? decoded.error ?? "unknown_server_error"
            clearDeviceAuthorization(reason: message)
            return .failed(message: message)

        } catch {
            clearDeviceAuthorization(reason: "network_or_server_error")
            return .failed(message: error.localizedDescription)
        }
    }

    func isCurrentUserDeviceLocallyAuthorized() -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            return false
        }

        let savedUid = UserDefaults.standard
            .string(forKey: authorizedUidKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return !savedUid.isEmpty && savedUid == uid
    }

    func clearLocalAuthorization() {
        clearDeviceAuthorization(reason: nil)
    }

    private func persistDeviceAuthorization(
        uid: String,
        status: String?
    ) {
        let cleanUid = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUid.isEmpty else { return }

        let defaults = UserDefaults.standard

        defaults.set(cleanUid, forKey: authorizedUidKey)
        defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: authorizedAtMillisKey)
        defaults.set(status ?? "allowed", forKey: lastStatusKey)
        defaults.removeObject(forKey: lastReasonKey)
    }

    private func clearDeviceAuthorization(reason: String?) {
        let defaults = UserDefaults.standard

        defaults.removeObject(forKey: authorizedUidKey)
        defaults.removeObject(forKey: authorizedAtMillisKey)
        defaults.removeObject(forKey: lastStatusKey)

        if let reason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(reason, forKey: lastReasonKey)
        } else {
            defaults.removeObject(forKey: lastReasonKey)
        }
    }
}
