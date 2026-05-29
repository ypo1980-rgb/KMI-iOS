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

    @State private var sendScope: String = "group"

    @AppStorage("kmi_app_language") private var kmiAppLanguage: String = ""
    @AppStorage("app_language") private var appLanguage: String = ""
    @AppStorage("initial_language_code") private var initialLanguageCode: String = ""
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = ""

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var screenFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func normalizeRole(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isCoachRole(_ value: String) -> Bool {
        let role = normalizeRole(value)

        return role == "coach" ||
               role == "trainer" ||
               role == "instructor" ||
               role == "מאמן" ||
               role == "coach_user" ||
               role == "kmi_coach"
    }

    private var effectiveRole: String {
        let defaults = UserDefaults.standard

        let profileRole = normalizeRole(auth.userRole)

        let storedCandidates = [
            defaults.string(forKey: "user_role"),
            defaults.string(forKey: "role"),
            defaults.string(forKey: "userRole"),
            defaults.string(forKey: "profile_role")
        ]
        .compactMap { $0 }
        .map { normalizeRole($0) }
        .filter { !$0.isEmpty }

        // חשוב: אם אחד המקורות אומר מאמן — לא ניתקע על trainee ישן.
        if isCoachRole(profileRole) {
            return profileRole
        }

        if let coachStoredRole = storedCandidates.first(where: { isCoachRole($0) }) {
            return coachStoredRole
        }

        if let firstStoredRole = storedCandidates.first {
            return firstStoredRole
        }

        return profileRole
    }

    private var isCoach: Bool {
        isCoachRole(effectiveRole)
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
        selectedRecipients
            .map(\.phone)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var selectedUids: [String] {
        selectedRecipients
            .map(\.uid)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var allSelected: Bool {
        !recipients.isEmpty && recipients.allSatisfy(\.selected)
    }

    private var coachGroupKey: String {
        let defaults = UserDefaults.standard

        let candidates = [
            defaults.string(forKey: "active_group"),
            defaults.string(forKey: "activeGroup"),
            defaults.string(forKey: "primaryGroup"),
            defaults.string(forKey: "groupKey"),
            defaults.string(forKey: "group_key"),
            defaults.string(forKey: "age_group"),
            defaults.string(forKey: "group"),
            auth.userGroup
        ]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return candidates.first ?? ""
    }

    private var effectiveGroupKey: String {
        sendScope == "branch" ? "" : coachGroupKey
    }

    private var sendButtonText: String {
        if selectedUids.isEmpty {
            return tr("בחר מתאמנים לשליחה", "Select trainees to send")
        }

        if allSelected {
            return tr("שליחת הודעה לכל המתאמנים", "Send message to all trainees")
        }

        if selectedRecipients.count == 1 {
            return tr("שליחת הודעה למתאמן שנבחר", "Send message to selected trainee")
        }

        return tr(
            "שליחת הודעה ל-\(selectedRecipients.count) מתאמנים",
            "Send message to \(selectedRecipients.count) trainees"
        )
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

                    Text(tr("המסך זמין למאמנים בלבד", "This screen is available to coaches only"))
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(24)

            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        inputFormCard

                        audienceCard

                        recipientsCard

                        selectedCountCard

                        sendButtons
                    }
                    .padding(16)
                }
            }
        }
        .environment(\.layoutDirection, screenLayoutDirection)
        .onAppear {
            auth.reloadProfileIfSignedIn()
            preloadDefaults()
        }
        .onChange(of: region) { _, _ in
            branch = ""
            recipients = []
        }
        .onChange(of: branch) { _, _ in
            loadRecipients()
        }
        .onChange(of: sendScope) { _, _ in
            loadRecipients()
        }
        .alert(tr("הודעה", "Message"), isPresented: $showAlert) {
            Button(tr("סגור", "Close"), role: .cancel) { }
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

    private var audienceCard: some View {
        Group {
            if !coachGroupKey.isEmpty {
                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
                    Text(tr("בחירת קהל יעד", "Target audience"))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(screenTextAlignment)
                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

                    HStack(spacing: 10) {
                        audienceButton(
                            title: tr("הקבוצה שלי", "My group"),
                            subtitle: tr("רק המתאמנים של הקבוצה", "Only this group's trainees"),
                            isSelected: sendScope == "group",
                            action: {
                                sendScope = "group"
                            }
                        )

                        audienceButton(
                            title: tr("כל הסניף", "Entire branch"),
                            subtitle: tr("כולל כל הקבוצות בסניף", "Includes all groups in branch"),
                            isSelected: sendScope == "branch",
                            action: {
                                sendScope = "branch"
                            }
                        )
                    }

                    Text(sendScope == "group"
                         ? tr("ההודעה תישלח רק למתאמני הקבוצה: \(coachGroupKey)", "The message will be sent only to trainees in: \(coachGroupKey)")
                         : tr("ההודעה תישלח לכל המתאמנים הפעילים בכל הקבוצות של הסניף שנבחר.", "The message will be sent to all active trainees in all groups of the selected branch."))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.73, green: 0.90, blue: 0.99))
                        .multilineTextAlignment(screenTextAlignment)
                        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                }
                .padding(12)
                .background(Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
        }
    }

    private func audienceButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.73, green: 0.90, blue: 0.99))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 74)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(red: 0.05, green: 0.65, blue: 0.91).opacity(0.32) : Color(red: 0.04, green: 0.07, blue: 0.13).opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.40, green: 0.91, blue: 0.98) : Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                title: tr("אזור", "Region"),
                value: region.isEmpty ? tr("בחר אזור", "Choose region") : region
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
                title: tr("סניף", "Branch"),
                value: branch.isEmpty ? tr("בחר סניף", "Choose branch") : branch
            )
        }
        .buttonStyle(.plain)
    }

    private var messageCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 8) {
            Text(tr("טקסט ההודעה", "Message text"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(screenTextAlignment)
                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)

            TextEditor(text: $message)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(red: 0.02, green: 0.09, blue: 0.18))
                .foregroundStyle(.white)
                .multilineTextAlignment(screenTextAlignment)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.74, blue: 0.97), lineWidth: 1)
                )
        }
    }

    private var recipientsCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 10) {
            HStack {
                if isEnglish {
                    Text(recipientsTitleText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    selectAllButton
                } else {
                    selectAllButton

                    Spacer()

                    Text(recipientsTitleText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if isLoadingRecipients {
                ProgressView(tr("טוען נמענים...", "Loading recipients..."))
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

            } else if !region.isEmpty && !branch.isEmpty && recipients.isEmpty {
                Text(emptyRecipientsText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                    .multilineTextAlignment(screenTextAlignment)
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .padding(.vertical, 8)

            } else if recipients.isEmpty {
                Text(tr("בחר אזור וסניף כדי לטעון נמענים.", "Choose region and branch to load recipients."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(screenTextAlignment)
                    .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                    .padding(.vertical, 8)

            } else {
                VStack(spacing: 8) {
                    ForEach(recipients) { recipient in
                        recipientRow(recipient)
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

    private var recipientsTitleText: String {
        if effectiveGroupKey.isEmpty {
            return tr("נמענים בסניף: \(recipients.count)", "Recipients in branch: \(recipients.count)")
        }

        return tr("נמענים בקבוצה: \(recipients.count)", "Recipients in group: \(recipients.count)")
    }

    private var emptyRecipientsText: String {
        if effectiveGroupKey.isEmpty {
            return tr("לא נמצאו מתאמנים פעילים לסניף שנבחר.", "No active trainees were found for the selected branch.")
        }

        return tr("לא נמצאו מתאמנים פעילים לסניף ולקבוצה שנבחרו.", "No active trainees were found for the selected branch and group.")
    }

    private var selectAllButton: some View {
        Button(allSelected ? tr("בטל סימון לכולם", "Unselect all") : tr("סמן את כל חברי הקבוצה", "Select all group members")) {
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
    }

    private func recipientRow(_ recipient: CoachBroadcastRecipient) -> some View {
        let isSelected = recipient.selected

        return HStack {
            if isEnglish {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipient.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Color(red: 0.05, green: 0.29, blue: 0.43) : .black)
                        .multilineTextAlignment(.leading)

                    Text(recipient.phone.isEmpty ? tr("ללא מספר טלפון", "No phone number") : recipient.phone)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Color(red: 0.02, green: 0.41, blue: 0.63) : .gray)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

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

            } else {
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
                        .multilineTextAlignment(.trailing)

                    Text(recipient.phone.isEmpty ? tr("ללא מספר טלפון", "No phone number") : recipient.phone)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Color(red: 0.02, green: 0.41, blue: 0.63) : .gray)
                        .multilineTextAlignment(.trailing)
                }
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

    private var selectedCountCard: some View {
        VStack(alignment: isEnglish ? .leading : .trailing, spacing: 4) {
            Text(effectiveGroupKey.isEmpty
                 ? tr("מתאמנים בסניף: \(recipients.count)", "Trainees in branch: \(recipients.count)")
                 : tr("מתאמנים בקבוצה \(effectiveGroupKey): \(recipients.count)", "Trainees in \(effectiveGroupKey): \(recipients.count)"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(screenTextAlignment)

            Text(tr("מתאמנים נבחרים: \(selectedRecipients.count)", "Selected trainees: \(selectedRecipients.count)"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                .multilineTextAlignment(screenTextAlignment)
        }
        .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
        .padding(.top, 2)
    }

    private var sendButtons: some View {
        Button {
            sendSmsToSelected()
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                }

                Text(isSending ? tr("שולח הודעה...", "Sending message...") : sendButtonText)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color(red: 0.88, green: 0.95, blue: 0.99))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
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
        .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUids.isEmpty)
        .opacity(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedUids.isEmpty ? 0.45 : 1.0)
    }

    private func pickerCard(title: String, value: String) -> some View {
        HStack {
            if isEnglish {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)

                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.trailing)

                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
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
                .replacingOccurrences(of: "—", with: "-")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }

        func primaryBranch(_ value: String) -> String {
            value
                .split(whereSeparator: { char in
                    char == "," || char == "•" || char == "|"
                })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty } ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func splitTokens(_ value: String) -> [String] {
            value
                .replacingOccurrences(of: " • ", with: ",")
                .replacingOccurrences(of: "|", with: ",")
                .replacingOccurrences(of: "\n", with: ",")
                .split(whereSeparator: { char in
                    char == "," || char == ";" || char == "；"
                })
                .map { norm(String($0)) }
                .filter { !$0.isEmpty }
        }

        func groupAliases(_ value: String) -> Set<String> {
            let clean = norm(value)
            var aliases = Set<String>()

            if !clean.isEmpty {
                aliases.insert(clean)
            }

            for token in splitTokens(clean) {
                aliases.insert(token)
            }

            if clean.contains("נוער") && clean.contains("בוגרים") {
                aliases.insert("נוער")
                aliases.insert("בוגרים")
                aliases.insert("נוער ובוגרים")
                aliases.insert("נוער + בוגרים")
            }

            if clean.localizedCaseInsensitiveContains("children") ||
                clean.localizedCaseInsensitiveContains("kids") {
                aliases.insert("ילדים")
            }

            if clean.localizedCaseInsensitiveContains("youth") {
                aliases.insert("נוער")
            }

            if clean.localizedCaseInsensitiveContains("adult") ||
                clean.localizedCaseInsensitiveContains("adults") {
                aliases.insert("בוגרים")
            }

            return Set(aliases.map { norm($0) }.filter { !$0.isEmpty })
        }

        func stringValue(_ data: [String: Any], _ key: String) -> String {
            (data[key] as? String) ?? ""
        }

        func stringArrayValue(_ data: [String: Any], _ key: String) -> [String] {
            (data[key] as? [String]) ?? []
        }

        func groupValues(from data: [String: Any]) -> Set<String> {
            var values = Set<String>()

            for value in stringArrayValue(data, "groups") {
                values.formUnion(groupAliases(value))
            }

            let keys = [
                "primaryGroup",
                "activeGroup",
                "active_group",
                "groupKey",
                "group_key",
                "group",
                "groupName",
                "groupsCsv",
                "groupCsv",
                "age_group"
            ]

            for key in keys {
                let rawValue = stringValue(data, key)
                let tokens = splitTokens(rawValue)

                if tokens.isEmpty, !norm(rawValue).isEmpty {
                    values.formUnion(groupAliases(rawValue))
                } else {
                    for token in tokens {
                        values.formUnion(groupAliases(token))
                    }
                }
            }

            return Set(values.map { norm($0) }.filter { !$0.isEmpty })
        }

        func hasSoftMatch(
            storedValues: Set<String>,
            candidates: Set<String>
        ) -> Bool {
            if candidates.isEmpty {
                return true
            }

            if !storedValues.isDisjoint(with: candidates) {
                return true
            }

            for stored in storedValues {
                for candidate in candidates {
                    if stored.count >= 2,
                       candidate.count >= 2,
                       stored.contains(candidate) || candidate.contains(stored) {
                        return true
                    }
                }
            }

            return false
        }

        let regionNorm = norm(region)
        let branchPrimary = primaryBranch(norm(branch))
        let groupCandidates = groupAliases(effectiveGroupKey)

        guard !regionNorm.isEmpty, !branchPrimary.isEmpty else {
            recipients = []
            return
        }

        let previousSelectionByPhone = Dictionary(
            uniqueKeysWithValues: recipients.map { ($0.phone, $0.selected) }
        )

        isLoadingRecipients = true

        let branchCandidates = Set([
            branchPrimary,
            branchPrimary.replacingOccurrences(of: "-", with: "–"),
            branchPrimary.replacingOccurrences(of: "-", with: "—"),
            branchPrimary.replacingOccurrences(of: "-", with: "־"),
            branchPrimary.replacingOccurrences(of: "–", with: "-"),
            branchPrimary.replacingOccurrences(of: "—", with: "-"),
            branchPrimary.replacingOccurrences(of: "־", with: "-")
        ].map { norm($0) }.filter { !$0.isEmpty })

        let query = Firestore.firestore()
            .collection("users")
            .whereField("region", isEqualTo: regionNorm)
            .whereField("role", isEqualTo: "trainee")

        query.getDocuments { snapshot, error in
            isLoadingRecipients = false

            guard let docs = snapshot?.documents, error == nil else {
                recipients = []
                return
            }

            var uniqueByPhone: [String: CoachBroadcastRecipient] = [:]

            for doc in docs {
                let data = doc.data()

                let isActive = data["isActive"] as? Bool ?? true
                guard isActive else { continue }

                let branches = stringArrayValue(data, "branches").map { norm($0) }
                let branchSingle = norm(stringValue(data, "branch"))
                let activeBranch = norm(stringValue(data, "activeBranch"))
                let activeBranchSnake = norm(stringValue(data, "active_branch"))
                let branchesCsvRaw = stringValue(data, "branchesCsv")
                let branchesCsvItems = splitTokens(branchesCsvRaw)

                let branchMatches =
                    branches.contains { branchCandidates.contains($0) } ||
                    branchCandidates.contains(branchSingle) ||
                    branchCandidates.contains(activeBranch) ||
                    branchCandidates.contains(activeBranchSnake) ||
                    branchesCsvItems.contains { branchCandidates.contains($0) } ||
                    branchCandidates.contains(norm(branchesCsvRaw))

                guard branchMatches else { continue }

                let storedGroupValues = groupValues(from: data)
                let groupMatches = hasSoftMatch(
                    storedValues: storedGroupValues,
                    candidates: groupCandidates
                )

                guard groupMatches else { continue }

                let phone = (
                    stringValue(data, "phone").isEmpty
                    ? (
                        stringValue(data, "phoneNumber").isEmpty
                        ? stringValue(data, "phone_number")
                        : stringValue(data, "phoneNumber")
                    )
                    : stringValue(data, "phone")
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !phone.isEmpty else { continue }

                let fullName = stringValue(data, "fullName").trimmingCharacters(in: .whitespacesAndNewlines)
                let nameValue = stringValue(data, "name").trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = stringValue(data, "displayName").trimmingCharacters(in: .whitespacesAndNewlines)

                let name =
                    !fullName.isEmpty ? fullName :
                    !nameValue.isEmpty ? nameValue :
                    !displayName.isEmpty ? displayName :
                    phone

                let uidValue = stringValue(data, "uid").trimmingCharacters(in: .whitespacesAndNewlines)
                let uid = uidValue.isEmpty ? doc.documentID : uidValue

                uniqueByPhone[phone] = CoachBroadcastRecipient(
                    id: uid,
                    uid: uid,
                    name: name,
                    phone: phone,
                    selected: previousSelectionByPhone[phone] ?? true
                )
            }

            recipients = uniqueByPhone
                .map(\.value)
                .sorted { $0.name < $1.name }
        }
    }

    private func sendSmsToSelected() {
        guard !isSending else { return }

        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanMessage.isEmpty else {
            showError(tr("נא לכתוב טקסט להודעה", "Please write a message"))
            return
        }

        guard !selectedUids.isEmpty else {
            showError(tr("לא נבחרו נמענים – סמן לפחות מתאמן אחד", "No recipients selected — select at least one trainee"))
            return
        }

        isSending = true

        persistBroadcast(
            region: region,
            branch: branch,
            message: cleanMessage,
            targetUids: selectedUids,
            targetRecipients: selectedRecipients
        )

        let numbers = selectedPhones.joined(separator: ",")
        let encoded = cleanMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if !numbers.isEmpty,
           let url = URL(string: "sms:\(numbers)&body=\(encoded)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { _ in
                isSending = false
                message = ""
                showError(tr(
                    "נפתחה אפליקציית ההודעות עם \(selectedPhones.count) מתאמנים",
                    "The messaging app opened with \(selectedPhones.count) trainees"
                ))
            }
        } else {
            isSending = false
            message = ""
            showError(tr(
                "ההודעה נשמרה לעיבוד Push, אבל פתיחת אפליקציית ההודעות נכשלה.",
                "The message was saved for Push processing, but opening the messaging app failed."
            ))
        }
    }

    private func persistBroadcast(
        region: String,
        branch: String,
        message: String,
        targetUids: [String],
        targetRecipients: [CoachBroadcastRecipient]
    ) {
        guard let currentUser = Auth.auth().currentUser else {
            isSending = false
            showError(tr("לא נמצא משתמש מחובר", "No logged-in user was found"))
            return
        }

        let currentUid = currentUser.uid
        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanTargetUids = targetUids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let recipientSnapshots: [[String: String]] = targetRecipients.map {
            [
                "uid": $0.uid,
                "name": $0.name,
                "phone": $0.phone
            ]
        }

        let targetPhones = targetRecipients
            .map(\.phone)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let targetNames = targetRecipients
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let coachName =
            currentUser.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? currentUser.displayName
            : currentUser.email

        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let expiresAt = Date().addingTimeInterval(30 * 24 * 60 * 60)
        let expiresAtMillis = Int64(expiresAt.timeIntervalSince1970 * 1000)

        let docRef = Firestore.firestore()
            .collection("coachBroadcasts")
            .document()

        let broadcastId = docRef.documentID

        let data: [String: Any] = [
            "broadcastId": broadcastId,
            "type": "coach_broadcast",

            "authorUid": currentUid,
            "coachUid": currentUid,
            "coachName": coachName as Any,

            "region": cleanRegion,
            "branch": cleanBranch,

            "text": cleanMessage,
            "message": cleanMessage,
            "body": cleanMessage,

            "targetUids": cleanTargetUids,
            "targetUidCount": cleanTargetUids.count,
            "targetCount": cleanTargetUids.count,

            "targetRecipients": recipientSnapshots,
            "targetPhones": targetPhones,
            "targetNames": targetNames,
            "targetRecipientSnapshotCount": recipientSnapshots.count,

            "pushEnabled": true,
            "pushTarget": "targetUids",
            "pushStatus": "pending",
            "pushCreatedBy": "ios_coach_broadcast",

            "createdAt": FieldValue.serverTimestamp(),
            "createdAtMillis": nowMillis,
            "sentAtMillis": nowMillis,

            "expiresAt": Timestamp(date: expiresAt),
            "expiresAtMillis": expiresAtMillis,

            "source": "ios_coach_broadcast"
        ]

        docRef.setData(data, merge: true) { error in
            if let error {
                isSending = false
                showError(tr(
                    "שמירת ההודעה נכשלה: \(error.localizedDescription)",
                    "Saving the message failed: \(error.localizedDescription)"
                ))
            }
        }
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
