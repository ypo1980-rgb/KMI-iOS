import AVFoundation
import FirebaseAuth
import FirebaseFunctions
import SwiftUI
import UIKit
import Vision
import VisionKit

struct AttendanceQrScannerView: View {
    let isEnglish: Bool
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var cameraAuthorized = false
    @State private var phase: Phase = .scanning

    private enum Phase {
        case scanning
        case verifying(Payload)
        case success(
            alreadyRecorded: Bool,
            usedAdminQR: Bool,
            branch: String,
            group: String
        )
        case failed(String)
        case cameraUnavailable
    }

    private struct Payload: Decodable, Equatable {
        let type: String
        let occurrenceId: String
        let token: String
    }

    private var pendingPayload: Payload? {
        if case let .verifying(payload) = phase {
            return payload
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KmiAppTheme.surface(for: colorScheme)
                    .ignoresSafeArea()

                content
                    .padding(16)
            }
            .navigationTitle(tr("סריקת QR לנוכחות", "Scan QR for attendance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("סגור", "Close")) {
                        dismiss()
                    }
                    .disabled(pendingPayload != nil)
                }
            }
        }
        .environment(\.layoutDirection, isEnglish ? .leftToRight : .rightToLeft)
        .interactiveDismissDisabled(pendingPayload != nil)
        .task {
            await requestCameraAccess()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video)
                    == .authorized
            }
        }
        .task(id: pendingPayload) {
            guard let payload = pendingPayload else {
                return
            }
            await registerAttendance(payload)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .scanning:
            if !DataScannerViewController.isSupported {
                message(
                    tr(
                        "סריקת QR באמצעות המצלמה אינה זמינה במכשיר זה.",
                        "Camera QR scanning is unavailable on this device."
                    )
                )
            } else if cameraAuthorized {
                VStack(spacing: 12) {
                    message(
                        tr(
                            "כוון את המצלמה לקוד הנוכחות שהציג המאמן.",
                            "Point the camera at the attendance QR code shown by your coach."
                        )
                    )

                    AttendanceQrCameraPreview(
                        onScan: handleScan,
                        onUnavailable: {
                            if case .scanning = phase {
                                phase = .cameraUnavailable
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                VStack(spacing: 12) {
                    message(
                        tr(
                            "יש לאפשר גישה למצלמה כדי לסרוק את קוד הנוכחות.",
                            "Allow camera access to scan the attendance QR code."
                        )
                    )

                    Button(tr("פתח הגדרות", "Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

        case .verifying:
            ZStack {
                message(
                    tr(
                        "מאמת נוכחות מול השרת…",
                        "Verifying attendance…"
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                KmiLoadingOverlay()
            }

        case let .success(alreadyRecorded, usedAdminQR, branch, group):
            successContent(
                alreadyRecorded: alreadyRecorded,
                usedAdminQR: usedAdminQR,
                branch: branch,
                group: group
            )

        case let .failed(text):
            retryContent(text)

        case .cameraUnavailable:
            retryContent(
                tr(
                    "המצלמה אינה זמינה כרגע. נסה שוב.",
                    "The camera is currently unavailable. Try again."
                )
            )
        }
    }

    private func successContent(
        alreadyRecorded: Bool,
        usedAdminQR: Bool,
        branch: String,
        group: String
    ) -> some View {
        let successColor = colorScheme == .dark
            ? Color(red: 0.29, green: 0.87, blue: 0.50)
            : Color(red: 0.08, green: 0.45, blue: 0.23)

        return GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .kmiIconSize(.extraLarge)
                            .foregroundStyle(successColor)
                            .padding(16)
                            .background(successColor.opacity(0.13), in: Circle())
                            .accessibilityHidden(true)

                        Text(
                            alreadyRecorded
                                ? tr("הנוכחות שלך כבר אושרה!", "Your attendance is already confirmed!")
                                : tr("הנוכחות שלך אושרה בהצלחה!", "Your attendance is confirmed!")
                        )
                        .kmiTypography(.cardTitle)
                        .foregroundStyle(successColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                        message(
                            usedAdminQR
                                ? tr(
                                    "הנוכחות שלך אומתה ונרשמה באמצעות QR בהרשאת מנהל.",
                                    "Your attendance was verified and recorded using an authorized admin QR."
                                )
                                : tr(
                                    "הנוכחות שלך באימון אומתה ונרשמה במערכת K.M.I",
                                    "Your training attendance has been verified and recorded in K.M.I"
                                )
                        )

                        if !branch.isEmpty || !group.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                if !branch.isEmpty {
                                    successDetailRow(
                                        title: tr("סניף", "Branch"),
                                        value: branch,
                                        systemImage: "mappin.circle.fill",
                                        accent: successColor
                                    )
                                }

                                if !group.isEmpty {
                                    successDetailRow(
                                        title: tr("קבוצת אימון", "Training group"),
                                        value: group,
                                        systemImage: "person.2.fill",
                                        accent: successColor
                                    )
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                successColor.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                        }

                        if usedAdminQR {
                            Text(tr("נוכחות נרשמה · QR מנהל", "Attendance recorded · Admin QR"))
                                .kmiTypography(.caption)
                                .foregroundStyle(successColor)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(successColor.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        KmiAppTheme.surface(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 24)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(successColor.opacity(0.25), lineWidth: 1)
                            .allowsHitTesting(false)
                    }

                    Button(action: onDone) {
                        Text(tr("סיום", "Done"))
                            .kmiTypography(.body)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: 440)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
        }
    }

    private func successDetailRow(
        title: String,
        value: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .kmiIconSize(.small)
                .foregroundStyle(accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .kmiTypography(.caption)

                Text(value)
                    .kmiTypography(.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
            .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .kmiTypography(.body)
            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func retryContent(_ text: String) -> some View {
        VStack(spacing: 16) {
            message(text)

            Button(tr("נסה שוב", "Try Again")) {
                phase = .scanning
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func requestCameraAccess() async {
        guard DataScannerViewController.isSupported else {
            return
        }

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video)
                == .authorized
        }
    }

    private func handleScan(_ rawValue: String) {
        guard case .scanning = phase else {
            return
        }

        guard let decoded = try? JSONDecoder().decode(
            Payload.self,
            from: Data(rawValue.utf8)
        ) else {
            phase = .failed(invalidCodeMessage)
            return
        }

        let payload = Payload(
            type: decoded.type.trimmingCharacters(in: .whitespacesAndNewlines),
            occurrenceId: decoded.occurrenceId.trimmingCharacters(in: .whitespacesAndNewlines),
            token: decoded.token.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard payload.type == "kami_attendance_qr",
              !payload.occurrenceId.isEmpty,
              !payload.token.isEmpty else {
            phase = .failed(invalidCodeMessage)
            return
        }

        phase = .verifying(payload)
    }

    @MainActor
    private func registerAttendance(_ payload: Payload) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            phase = .failed(signInMessage)
            return
        }

        do {
            let result = try await Functions.functions(region: "europe-west1")
                .httpsCallable("scanKamiAttendanceQr")
                .call([
                    "occurrenceId": payload.occurrenceId,
                    "token": payload.token
                ])

            guard !Task.isCancelled else {
                return
            }

            guard Auth.auth().currentUser?.uid == uid else {
                phase = .failed(signInMessage)
                return
            }

            guard let response = result.data as? [String: Any],
                  response["accepted"] as? Bool == true,
                  response["occurrenceId"] as? String == payload.occurrenceId else {
                phase = .failed(registrationErrorMessage)
                return
            }

            let branch = (response["branch"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let group = (response["group"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            phase = .success(
                alreadyRecorded: response["alreadyRecorded"] as? Bool == true,
                usedAdminQR: response["testMode"] as? Bool == true,
                branch: branch,
                group: group
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }

            phase = .failed(
                Auth.auth().currentUser?.uid == uid
                    ? errorMessage(for: error)
                    : signInMessage
            )
        }
    }

    private func errorMessage(for error: Error) -> String {
        let details = error as NSError

        guard details.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: details.code) else {
            return registrationErrorMessage
        }

        switch code {
        case .unauthenticated:
            return signInMessage
        case .permissionDenied:
            return tr(
                "לא ניתן לאמת נוכחות. בדוק את השיוך לקבוצת האימון.",
                "Attendance could not be verified. Check your training group."
            )
        case .notFound:
            return tr(
                "קוד הנוכחות אינו זמין עוד.",
                "This attendance QR code is no longer available."
            )
        case .invalidArgument:
            return invalidCodeMessage
        case .failedPrecondition:
            #if DEBUG
            print("KMI_QR_SCAN_REJECTED: \(details.localizedDescription)")
            #endif

            return tr(
                "לא ניתן לרשום נוכחות לאימון זה כרגע.",
                "Attendance cannot be registered for this training right now."
            )
        default:
            return registrationErrorMessage
        }
    }

    private var signInMessage: String {
        tr(
            "יש להתחבר מחדש ל־K.M.I ולנסות שוב.",
            "Sign in to K.M.I again and try again."
        )
    }

    private var invalidCodeMessage: String {
        tr(
            "קוד ה־QR שנסרק אינו קוד נוכחות תקין של K.M.I.",
            "The scanned QR code is not a valid K.M.I attendance code."
        )
    }

    private var registrationErrorMessage: String {
        tr(
            "רישום הנוכחות נכשל. בדוק את החיבור ונסה שוב.",
            "Attendance registration failed. Check your connection and try again."
        )
    }

    private func tr(_ hebrew: String, _ english: String) -> String {
        isEnglish ? english : hebrew
    }
}

private struct AttendanceQrCameraPreview: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onUnavailable: onUnavailable)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        let coordinator = context.coordinator

        Task { @MainActor [weak scanner, weak coordinator] in
            guard let scanner, let coordinator, coordinator.isActive else {
                return
            }

            guard DataScannerViewController.isAvailable else {
                coordinator.onUnavailable()
                return
            }

            do {
                try scanner.startScanning()
            } catch {
                coordinator.onUnavailable()
            }
        }

        return scanner
    }

    func updateUIViewController(
        _ scanner: DataScannerViewController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ scanner: DataScannerViewController,
        coordinator: Coordinator
    ) {
        coordinator.isActive = false
        scanner.stopScanning()
        scanner.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        let onUnavailable: () -> Void
        var isActive = true

        init(
            onScan: @escaping (String) -> Void,
            onUnavailable: @escaping () -> Void
        ) {
            self.onScan = onScan
            self.onUnavailable = onUnavailable
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard isActive else {
                return
            }

            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let value = barcode.payloadStringValue else {
                    continue
                }

                isActive = false
                scanner.stopScanning()
                onScan(value)
                return
            }
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            guard isActive else {
                return
            }

            isActive = false
            scanner.stopScanning()
            onUnavailable()
        }
    }
}
