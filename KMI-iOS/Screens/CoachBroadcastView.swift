import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct CoachBroadcastView: View {

    @EnvironmentObject private var auth: AuthViewModel

    @State private var region: String = ""
    @State private var branch: String = ""
    @State private var message: String = ""

    @State private var recipients: [CoachBroadcastRecipient] = []
    @State private var isLoadingRecipients = false
    @State private var isSending = false

    @State private var showRegionMenu = false
    @State private var showBranchMenu = false
    @State private var alertText: String?
    @State private var showAlert = false

    private var isCoach: Bool {
        let role = UserDefaults.standard.string(forKey: "user_role")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let role, !role.isEmpty {
            return role == "coach" || role == "trainer" || role == "מאמן"
        }

        let fallback = auth.userRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return fallback == "coach" || fallback == "trainer" || fallback == "מאמן"
    }

    private var branchesByRegion: [String: [String]] {
        let region = auth.userRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)

        if !region.isEmpty, !branch.isEmpty {
            return [region: [branch]]
        }

        if !region.isEmpty {
            return [region: []]
        }

        return [:]
    }

    private var regionOptions: [String] {
        Array(branchesByRegion.keys).sorted()
    }

    private var branchOptions: [String] {
        branchesByRegion[region] ?? []
    }

    private var selectedRecipients: [CoachBroadcastRecipient] {
        recipients.filter { $0.selected }
    }

    private var selectedPhones: [String] {
        selectedRecipients.map(\.phone).filter { !$0.isEmpty }
    }

    private var selectedUids: [String] {
        selectedRecipients.map(\.uid)
    }

    private var allSelected: Bool {
        !recipients.isEmpty && recipients.allSatisfy(\.selected)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.02, blue: 0.09),
                    Color(red: 0.06, green: 0.09, blue: 0.16),
                    Color(red: 0.12, green: 0.23, blue: 0.54),
                    Color(red: 0.22, green: 0.74, blue: 0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !isCoach {
                VStack(spacing: 12) {
                    Spacer()

                    Text("המסך זמין למאמנים בלבד")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(24)

            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        regionPickerCard

                        if !region.isEmpty {
                            branchPickerCard
                        }

                        messageCard

                        recipientsCard

                        selectedCountCard

                        sendButtons
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            preloadDefaults()
        }
        .onChange(of: region) { _ in
            branch = ""
            recipients = []
        }
        .onChange(of: branch) { _ in
            loadRecipients()
        }
        .alert("הודעה", isPresented: $showAlert) {
            Button("סגור", role: .cancel) { }
        } message: {
            Text(alertText ?? "")
        }
    }

    private var regionPickerCard: some View {
        Menu {
            ForEach(regionOptions, id: \.self) { item in
                Button(item) {
                    region = item
                }
            }
        } label: {
            pickerCard(
                title: "אזור",
                value: region.isEmpty ? "בחר אזור" : region
            )
        }
        .buttonStyle(.plain)
    }

    private var branchPickerCard: some View {
        Menu {
            ForEach(branchOptions, id: \.self) { item in
                Button(item) {
                    branch = item
                }
            }
        } label: {
            pickerCard(
                title: "סניף",
                value: branch.isEmpty ? "בחר סניף" : branch
            )
        }
        .buttonStyle(.plain)
    }

    private var messageCard: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text("טקסט ההודעה")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .trailing)

            TextEditor(text: $message)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(red: 0.02, green: 0.09, blue: 0.18))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.74, blue: 0.97), lineWidth: 1)
                )
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recipientsCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Button(allSelected ? "בטל סימון לכולם" : "סמן את כולם") {
                    let newValue = !allSelected
                    recipients = recipients.map {
                        var copy = $0
                        copy.selected = newValue
                        return copy
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.bordered)

                Spacer()

                Text("נמענים בקבוצה: \(recipients.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            if isLoadingRecipients {
                ProgressView("טוען נמענים...")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

            } else if !region.isEmpty && !branch.isEmpty && recipients.isEmpty {
                Text("לא נמצאו מתאמנים פעילים לסניף שנבחר.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 8)

            } else if recipients.isEmpty {
                Text("בחר אזור וסניף כדי לטעון נמענים.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 8)

            } else {
                VStack(spacing: 8) {
                    ForEach(recipients) { recipient in
                        HStack {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { recipient.selected },
                                    set: { newValue in
                                        recipients = recipients.map {
                                            guard $0.id == recipient.id else { return $0 }
                                            var copy = $0
                                            copy.selected = newValue
                                            return copy
                                        }
                                    }
                                )
                            )
                            .labelsHidden()

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(recipient.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black)

                                Text(recipient.phone)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var selectedCountCard: some View {
        HStack {
            Spacer()
            Text("נמענים נבחרים: \(selectedRecipients.count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var sendButtons: some View {
        VStack(spacing: 10) {
            Button {
                sendSmsToSelected()
            } label: {
                Text("שליחת הודעה לכל הנמענים המסומנים")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.05, green: 0.65, blue: 0.91))
                    )
            }
            .buttonStyle(.plain)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedRecipients.isEmpty)

            Button {
                shareMessageOnly()
            } label: {
                Text("שיתוף נוסח ההודעה")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.73, green: 0.90, blue: 0.99), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func pickerCard(title: String, value: String) -> some View {
        HStack {
            Image(systemName: "chevron.down")
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(Color(red: 0.02, green: 0.09, blue: 0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.22, green: 0.74, blue: 0.97), lineWidth: 1)
        )
    }

    private func preloadDefaults() {
        if region.isEmpty {
            region = auth.userRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if branch.isEmpty {
            branch = auth.userBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !branch.isEmpty {
            loadRecipients()
        }
    }

    private func loadRecipients() {
        let regionNorm = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let branchNorm = branch.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !regionNorm.isEmpty, !branchNorm.isEmpty else {
            recipients = []
            return
        }

        isLoadingRecipients = true

        Firestore.firestore()
            .collection("users")
            .whereField("region", isEqualTo: regionNorm)
            .whereField("role", isEqualTo: "trainee")
            .getDocuments { snapshot, error in
                isLoadingRecipients = false

                guard let docs = snapshot?.documents else {
                    recipients = []
                    return
                }

                let rows = docs.compactMap { doc -> CoachBroadcastRecipient? in
                    let data = doc.data()

                    let branches = (data["branches"] as? [String]) ?? []
                    let branchSingle = (data["branch"] as? String) ?? ""
                    let branchesCsv = (data["branchesCsv"] as? String) ?? ""
                    let isActive = data["isActive"] as? Bool ?? true

                    let branchMatches =
                        branches.contains(branchNorm) ||
                        branchSingle == branchNorm ||
                        branchesCsv.contains(branchNorm)

                    guard isActive, branchMatches else { return nil }

                    let name =
                        (data["fullName"] as? String) ??
                        (data["name"] as? String) ??
                        (data["displayName"] as? String) ??
                        "ללא שם"

                    let phone =
                        (data["phone"] as? String) ??
                        (data["phoneNumber"] as? String) ??
                        ""

                    let uid = (data["uid"] as? String) ?? doc.documentID

                    return CoachBroadcastRecipient(
                        id: uid,
                        uid: uid,
                        name: name,
                        phone: phone,
                        selected: true
                    )
                }
                .sorted { $0.name < $1.name }

                recipients = rows
            }
    }

    private func sendSmsToSelected() {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanMessage.isEmpty else {
            showError("נא לכתוב טקסט להודעה")
            return
        }

        guard !selectedPhones.isEmpty else {
            showError("לא נבחרו נמענים")
            return
        }

        persistBroadcast(
            region: region,
            branch: branch,
            message: cleanMessage,
            targetUids: selectedUids
        )

        let numbers = selectedPhones.joined(separator: ",")
        let encoded = cleanMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "sms:\(numbers)&body=\(encoded)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showError("לא ניתן לפתוח את אפליקציית ההודעות")
        }
    }

    private func shareMessageOnly() {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanMessage.isEmpty else {
            showError("נא לכתוב טקסט להודעה")
            return
        }

        persistBroadcast(
            region: region,
            branch: branch,
            message: cleanMessage,
            targetUids: selectedUids
        )

        let activity = UIActivityViewController(
            activityItems: [cleanMessage],
            applicationActivities: nil
        )

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activity, animated: true)
        }
    }

    private func persistBroadcast(
        region: String,
        branch: String,
        message: String,
        targetUids: [String]
    ) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let coachName = Auth.auth().currentUser?.displayName

        let data: [String: Any] = [
            "authorUid": currentUid,
            "region": region,
            "branch": branch,
            "text": message,
            "message": message,
            "coachName": coachName as Any,
            "targetUids": targetUids,
            "createdAt": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("coachBroadcasts")
            .addDocument(data: data)
    }

    private func showError(_ text: String) {
        alertText = text
        showAlert = true
    }
}

private struct CoachBroadcastRecipient: Identifiable {
    let id: String
    let uid: String
    let name: String
    let phone: String
    var selected: Bool
}
