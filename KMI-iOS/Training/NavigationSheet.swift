import SwiftUI
import UIKit

struct NavigationSheet: View {

    let training: TrainingData

    @Environment(\.dismiss) private var dismiss

    @State private var rememberChoice: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 42, height: 5)
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("ניווט באמצעות")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.85))

                Text(training.address)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            HStack {
                Spacer()

                Toggle(isOn: $rememberChoice) {
                    Text("זכור בחירה")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.75))
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.purple.opacity(0.85)))

                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button {
                    saveIfNeeded(preferredApp: "google_maps")
                    openGoogleMaps()
                } label: {
                    NavigationAppButton(
                        title: "גוגל מפות",
                        systemImage: "map.circle.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    saveIfNeeded(preferredApp: "waze")
                    openWaze()
                } label: {
                    NavigationAppButton(
                        title: "Waze",
                        systemImage: "location.circle.fill"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)

            Text("אפשר לשמור בחירה כך שבפעם הבאה הניווט יתחיל מיד באפליקציה שנבחרה.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            Button {
                dismiss()
            } label: {
                Text("סגור")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.purple.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }

    private func saveIfNeeded(preferredApp: String) {
        let ud = UserDefaults.standard
        ud.set(rememberChoice, forKey: "kmi.navigation.remember_choice")

        if rememberChoice {
            ud.set(preferredApp, forKey: "kmi.navigation.preferred_app")
        } else {
            ud.removeObject(forKey: "kmi.navigation.preferred_app")
        }
    }

    private func openWaze() {
        let encoded = training.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? training.address

        if let wazeUrl = URL(string: "waze://?q=\(encoded)"),
           UIApplication.shared.canOpenURL(wazeUrl) {
            UIApplication.shared.open(wazeUrl)
        } else if let webUrl = URL(string: "https://waze.com/ul?q=\(encoded)") {
            UIApplication.shared.open(webUrl)
        }

        dismiss()
    }

    private func openGoogleMaps() {
        let encoded = training.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? training.address

        if let appUrl = URL(string: "comgooglemaps://?q=\(encoded)"),
           UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else if let webUrl = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)") {
            UIApplication.shared.open(webUrl)
        }

        dismiss()
    }
}

private struct NavigationAppButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))

            Text(title)
                .font(.system(size: 18, weight: .heavy))
        }
        .foregroundStyle(Color.black.opacity(0.80))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}
