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

    private var sendButtonText: String {
        if selectedPhones.isEmpty {
            return "בחר מתאמנים לשליחה"
        }

        if allSelected {
            return "שליחת הודעה לכל המתאמנים"
        }

        if selectedPhones.count == 1 {
            return "שליחת הודעה למתאמן שנבחר"
        }

        return "שליחת הודעה ל-\(selectedPhones.count) מתאמנים"
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

                        inputFormCard

                        recipientsCard

                        selectedCountCard

                        sendButtons
                    }
                    .padding(16)
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

    private var inputFormCard: some View {
        VStack(spacing: 10) {
            regionPickerCard

            if !region.isEmpty {
                branchPickerCard
            }

            messageCard
        }
        .padding(12)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
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
                .frame(minHeight: 96)
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
    }

    private var recipientsCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                Button(allSelected ? "בטל סימון לכולם" : "סמן את כל חברי הקבוצה") {
                    let newValue = !allSelected
                    recipients = recipients.map {
                        var copy = $0
                        copy.selected = newValue
                        return copy
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(red: 0.04, green: 0.07, blue: 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.40, green: 0.91, blue: 0.98), lineWidth: 1)
                )

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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 8)

            } else if recipients.isEmpty {
                Text("בחר אזור וסניף כדי לטעון נמענים.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 8)

            } else {
                VStack(spacing: 8) {
                    ForEach(recipients) { recipient in
                        let isSelected = recipient.selected

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
                                    .foregroundStyle(isSelected ? Color(red: 0.05, green: 0.29, blue: 0.43) : .black)

                                Text(recipient.phone)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(isSelected ? Color(red: 0.02, green: 0.41, blue: 0.63) : .gray)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color(red: 0.88, green: 0.97, blue: 1.0) : Color.white.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? Color(red: 0.49, green: 0.83, blue: 0.99) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var selectedCountCard: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("מתאמנים בקבוצה: \(recipients.count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text("מתאמנים נבחרים: \(selectedRecipients.count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 2)
    }

    private var sendButtons: some View {
        Button {
            sendSmsToSelected()
        } label: {
            Text(sendButtonText)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.05, green: 0.65, blue: 0.91))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.40, green: 0.91, blue: 0.98), lineWidth: 1)
                )
                .shadow(radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedRecipients.isEmpty)
        .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedRecipients.isEmpty ? 0.45 : 1.0)
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
        func norm(_ value: String) -> String {
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "־", with: "-")
                .replacingOccurrences(of: "–", with: "-")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }

        func primaryBranch(_ value: String) -> String {
            value
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let regionNorm = norm(region)
        let branchPrimary = primaryBranch(norm(branch))

        guard !regionNorm.isEmpty, !branchPrimary.isEmpty else {
            recipients = []
            return
        }

        let previousSelectionByPhone = Dictionary(
            uniqueKeysWithValues: recipients.map { ($0.phone, $0.selected) }
        )

        isLoadingRecipients = true

        Firestore.firestore()
            .collection("users")
            .whereField("region", isEqualTo: regionNorm)
            .whereField("role", isEqualTo: "trainee")
            .getDocuments { snapshot, error in
                isLoadingRecipients = false

                guard let docs = snapshot?.documents, error == nil else {
                    recipients = []
                    return
                }

                let branchCandidates = Set([
                    branchPrimary,
                    branchPrimary.replacingOccurrences(of: "-", with: "–"),
                    branchPrimary.replacingOccurrences(of: "–", with: "-"),
                    branchPrimary.replacingOccurrences(of: "־", with: "-")
                ].map { norm($0) })

                let rows = docs.compactMap { doc -> CoachBroadcastRecipient? in
                    let data = doc.data()

                    let isActive = data["isActive"] as? Bool ?? true
                    guard isActive else { return nil }

                    let branches = ((data["branches"] as? [String]) ?? []).map { norm($0) }
                    let branchSingle = norm((data["branch"] as? String) ?? "")
                    let branchesCsvRaw = (data["branchesCsv"] as? String) ?? ""
                    let branchesCsvItems = branchesCsvRaw
                        .split(separator: ",")
                        .map { norm(String($0)) }

                    let branchMatches =
                        branches.contains { branchCandidates.contains($0) } ||
                        branchCandidates.contains(branchSingle) ||
                        branchesCsvItems.contains { branchCandidates.contains($0) } ||
                        branchCandidates.contains(norm(branchesCsvRaw))

                    guard branchMatches else { return nil }

                    let phone =
                        ((data["phone"] as? String) ??
                         (data["phoneNumber"] as? String) ??
                         "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !phone.isEmpty else { return nil }

                    let name =
                        ((data["fullName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ??
                        ((data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ??
                        ((data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ??
                        phone

                    let uid = (data["uid"] as? String) ?? doc.documentID

                    return CoachBroadcastRecipient(
                        id: uid,
                        uid: uid,
                        name: name,
                        phone: phone,
                        selected: previousSelectionByPhone[phone] ?? true
                    )
                }
                .reduce(into: [String: CoachBroadcastRecipient]()) { result, item in
                    result[item.phone] = item
                }
                .map(\.value)
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

    private func persistBroadcast(
        region: String,
        branch: String,
        message: String,
        targetUids: [String]
    ) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let coachName = Auth.auth().currentUser?.displayName
        let expiresAt = Date().addingTimeInterval(30 * 24 * 60 * 60)

        let data: [String: Any] = [
            "authorUid": currentUid,
            "region": region.trimmingCharacters(in: .whitespacesAndNewlines),
            "branch": branch.trimmingCharacters(in: .whitespacesAndNewlines),

            // תאימות למסך הבית וללוגיקה קיימת
            "text": message,
            "message": message,

            "coachName": coachName as Any,
            "targetUids": targetUids,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: expiresAt)
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
