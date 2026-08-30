import SwiftUI
import MessageUI
import UIKit

// MARK: - Theme helper
func colorSchemeFromThemeMode(_ mode: String) -> ColorScheme? {
    switch mode
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() {
    case "light":
        return .light
    case "dark":
        return .dark
    default:
        return nil
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
        KmiLoadingOverlay()
    }
}

// MARK: - PinSetupSheet
struct PinSetupSheet: View {

    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    @Binding var pin: String
    @Binding var pinConfirm: String
    @Binding var pinError: String?

    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var pinVisible: Bool = false
    @State private var pinConfirmVisible: Bool = false

    private var isEnglish: Bool {
        layoutDirection == .leftToRight
    }

    private var textAlignment: TextAlignment {
        .leading
    }

    private var frameAlignment: Alignment {
        .leading
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Group {
                    SecureFieldWithToggle(
                        title: tr("קוד נעילה", "PIN"),
                        text: $pin,
                        visible: $pinVisible
                    )

                    SecureFieldWithToggle(
                        title: tr("אימות קוד נעילה", "Confirm PIN"),
                        text: $pinConfirm,
                        visible: $pinConfirmVisible
                    )
                }

                    if let pinError, !pinError.isEmpty {
                        Text(pinError)
                            .kmiTypography(.caption)
                            .foregroundStyle(
                                KmiAppTheme.error(for: colorScheme)
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: frameAlignment
                            )
                            .multilineTextAlignment(textAlignment)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
            }
            .background(BeltTopicsGradientBackground())
            .environment(\.layoutDirection, layoutDirection)
            .navigationTitle(tr("הגדרת קוד נעילה", "Set PIN"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("ביטול", "Cancel")) {
                        onCancel()
                    }
                    .kmiTypography(.action)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("שמירה", "Save")) {
                        onSave()
                    }
                    .kmiTypography(.action)
                }
            }
        }
    }
}

struct SecureFieldWithToggle: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var text: String
    @Binding var visible: Bool

    private var isEnglish: Bool {
        layoutDirection == .leftToRight
    }

    private var textAlignment: TextAlignment {
        .leading
    }

    var body: some View {
        HStack(spacing: 8) {
            field
                .kmiTypography(.body)
                .foregroundStyle(
                    KmiAppTheme.onSurface(for: colorScheme)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            visibilityButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    KmiAppTheme.surface(for: colorScheme)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private var visibilityButton: some View {
        Button {
            visible.toggle()
        } label: {
            Image(
                systemName: visible ? "eye.slash.fill" : "eye.fill"
            )
            .kmiFont(size: KmiIconSize.small, weight: .semibold)
            .foregroundStyle(
                KmiAppTheme.onSurfaceVariant(for: colorScheme)
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isEnglish
                ? (visible ? "Hide PIN" : "Show PIN")
                : (visible ? "הסתר קוד נעילה" : "הצג קוד נעילה")
        )
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if visible {
                TextField(title, text: $text)
            } else {
                SecureField(title, text: $text)
            }
        }
        .keyboardType(.numberPad)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .multilineTextAlignment(textAlignment)
        .accessibilityLabel(title)
    }
}

// MARK: - Mail
struct MailData: Identifiable {
    let id = UUID()
    let to: String
    let subject: String
    let body: String
}

struct MailComposeView: View {
    let data: MailData

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("kmi_app_language") private var languageCode = "he"

    private var isEnglish: Bool {
        let clean = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return clean == "en" || clean == "english"
    }

    var body: some View {
        Group {
            if MFMailComposeViewController.canSendMail() {
                KmiMailComposer(
                    data: data,
                    onFinish: { dismiss() }
                )
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(
                                isEnglish
                                    ? "Email is unavailable"
                                    : "שליחת דואר אינה זמינה"
                            )
                            .kmiTypography(.sectionTitle)

                            Text(
                                isEnglish
                                    ? "Set up an account in Mail, or copy the address below into your preferred email app."
                                    : "הגדר חשבון ביישום הדואר, או העתק את הכתובת הבאה ליישום הדואר שלך."
                            )
                            .kmiTypography(.body)

                            Text(data.to)
                                .kmiTypography(.body)
                                .textSelection(.enabled)
                                .environment(
                                    \.layoutDirection,
                                    .leftToRight
                                )
                        }
                        .foregroundStyle(
                            KmiAppTheme.onSurface(for: colorScheme)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            KmiAppTheme.surface(for: colorScheme),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .padding(16)
                    }
                    .background(BeltTopicsGradientBackground())
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(isEnglish ? "Close" : "סגירה") {
                                dismiss()
                            }
                        }
                    }
                    .environment(
                        \.layoutDirection,
                        isEnglish ? .leftToRight : .rightToLeft
                    )
                }
            }
        }
    }
}

private struct KmiMailComposer: UIViewControllerRepresentable {
    let data: MailData
    let onFinish: () -> Void

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
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
            super.init()
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}

// MARK: - ShareSheet
enum ShareSheet {
    static func present(items: [Any]) {
        guard !items.isEmpty else { return }

        DispatchQueue.main.async {
            guard
                let scene = activeWindowScene(),
                let root = scene.windows
                    .first(where: { $0.isKeyWindow })?
                    .rootViewController
            else {
                return
            }

            var presenter = root

            while let presented = presenter.presentedViewController {
                presenter = presented
            }

            guard
                !(presenter is UIActivityViewController),
                !(presenter is UIAlertController),
                !presenter.isBeingDismissed,
                !presenter.isBeingPresented,
                presenter.viewIfLoaded?.window != nil
            else {
                return
            }

            let controller = UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )

            if let popover = controller.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
            }

            presenter.present(controller, animated: true)
        }
    }
}

// MARK: - Toast
final class ToastCenter {
    static let shared = ToastCenter()

    private var window: UIWindow?
    private var label: UILabel?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ text: String) {
        DispatchQueue.main.async {
            let cleanText = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !cleanText.isEmpty else { return }

            self.hideWorkItem?.cancel()
            self.hideWorkItem = nil

            self.ensureWindow()

            guard let label = self.label else { return }

            let fontSize = KmiAppFontSize.fromStorageValue(
                UserDefaults.standard.string(
                    forKey: KmiAppFontSize.preferenceKey
                )
            )

            label.font = UIFont.systemFont(
                ofSize: 14 * fontSize.scaleFactor,
                weight: .semibold
            )

            label.layer.removeAllAnimations()
            label.text = cleanText
            label.alpha = 1

            let hideWorkItem = DispatchWorkItem { [weak self] in
                guard let self else { return }

                UIView.animate(
                    withDuration: 0.2,
                    delay: 0,
                    options: [.beginFromCurrentState, .allowUserInteraction]
                ) {
                    self.label?.alpha = 0
                }
            }

            self.hideWorkItem = hideWorkItem

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 3,
                execute: hideWorkItem
            )
        }
    }

    private func ensureWindow() {
        guard let scene = activeWindowScene() else { return }

        if let window, window.windowScene === scene {
            return
        }

        window?.isHidden = true
        window = nil
        label = nil

        let w = UIWindow(windowScene: scene)
        w.backgroundColor = .clear
        w.windowLevel = .alert + 1
        w.isUserInteractionEnabled = false

        let lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.lineBreakMode = .byWordWrapping
        lbl.textAlignment = .center
        lbl.textColor = .white
        lbl.isUserInteractionEnabled = false
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        lbl.layer.cornerRadius = 12
        lbl.layer.masksToBounds = true

        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
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
