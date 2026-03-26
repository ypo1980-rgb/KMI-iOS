import SwiftUI
import MessageUI
import UIKit

// MARK: - Theme helper
func colorSchemeFromThemeMode(_ mode: String) -> ColorScheme? {
    switch mode {
    case "light":
        return .light
    case "dark":
        return .dark
    default:
        return .light
    }
}

// MARK: - activeWindowScene
func activeWindowScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { scene in
            scene.activationState == .foregroundActive
        }
}

// MARK: - LoadingOverlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            ProgressView()
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - PinSetupSheet
struct PinSetupSheet: View {
    @Binding var pin: String
    @Binding var pinConfirm: String
    @Binding var pinError: String?

    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var pinVisible: Bool = false
    @State private var pinConfirmVisible: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Group {
                    SecureFieldWithToggle(title: "סיסמה", text: $pin, visible: $pinVisible)
                    SecureFieldWithToggle(title: "אימות סיסמה", text: $pinConfirm, visible: $pinConfirmVisible)
                }

                if let pinError, !pinError.isEmpty {
                    Text(pinError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("הגדרת סיסמה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ביטול") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("שמירה") { onSave() }
                }
            }
        }
    }
}

struct SecureFieldWithToggle: View {
    let title: String
    @Binding var text: String
    @Binding var visible: Bool

    var body: some View {
        HStack {
            Button {
                visible.toggle()
            } label: {
                Image(systemName: visible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
            }

            if visible {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                SecureField(title, text: $text)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Mail
struct MailData: Identifiable {
    let id = UUID()
    let to: String
    let subject: String
    let body: String
}

struct MailComposeView: UIViewControllerRepresentable {
    let data: MailData

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([data.to])
        vc.setSubject(data.subject)
        vc.setMessageBody(data.body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - ShareSheet
enum ShareSheet {
    static func present(items: [Any]) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

// MARK: - Toast
final class ToastCenter {
    static let shared = ToastCenter()

    private var window: UIWindow?
    private var label: UILabel?

    func show(_ text: String) {
        DispatchQueue.main.async {
            self.ensureWindow()
            self.label?.text = text
            self.label?.alpha = 0

            UIView.animate(withDuration: 0.2) {
                self.label?.alpha = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                UIView.animate(withDuration: 0.2) {
                    self.label?.alpha = 0
                }
            }
        }
    }

    private func ensureWindow() {
        if window != nil { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        let w = UIWindow(windowScene: scene)
        w.backgroundColor = .clear
        w.windowLevel = .alert + 1

        let lbl = UILabel()
        lbl.numberOfLines = 2
        lbl.textAlignment = .center
        lbl.textColor = .white
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        lbl.layer.cornerRadius = 12
        lbl.layer.masksToBounds = true
        lbl.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.addSubview(lbl)

        lbl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            lbl.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            lbl.widthAnchor.constraint(lessThanOrEqualTo: vc.view.widthAnchor, multiplier: 0.85),
            lbl.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        w.rootViewController = vc
        w.isHidden = false

        self.window = w
        self.label = lbl
    }
}

// MARK: - Utilities
extension Color {
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255.0
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a == 0 ? 1 : a)
    }
}

extension String {
    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
