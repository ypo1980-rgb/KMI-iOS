import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class FreeSessionsViewModel: ObservableObject {

    @Published private(set) var upcoming: [FreeSession] = []
    @Published private(set) var participants: [FreeSessionPart] = []
    @Published var selectedSession: FreeSession?
    @Published var isCreating: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let repo: FreeSessionsRepository

    private var branch: String = ""
    private var groupKey: String = ""
    private var myUid: String = ""
    private var myName: String = ""

    private var upcomingListener: ListenerRegistration?
    private var upcomingBindingID = UUID()
    private var participantsListener: ListenerRegistration?

    private var participantResponses: [FreeSessionPart] = []
    private var groupRecipients: [FreeSessionPart] = []
    private var participantBindingID = UUID()
    private var groupRecipientsTask: Task<Void, Never>?

    init(repo: FreeSessionsRepository? = nil) {
        self.repo = repo ?? FreeSessionsRepository.shared
    }

    deinit {
        upcomingListener?.remove()
        participantsListener?.remove()
        groupRecipientsTask?.cancel()
    }

    func setContext(
        branch: String,
        groupKey: String,
        myUid: String,
        myName: String
    ) {
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUid = myUid.trimmingCharacters(in: .whitespacesAndNewlines)

        if self.branch != cleanBranch ||
            self.groupKey != cleanGroup ||
            self.myUid != cleanUid {
            upcoming = []
            closeDetails()
        }

        self.branch = cleanBranch
        self.groupKey = cleanGroup
        self.myUid = cleanUid
        self.myName = myName.trimmingCharacters(in: .whitespacesAndNewlines)

        bindUpcoming()
    }

    func bindUpcoming() {
        let bindingID = UUID()
        upcomingBindingID = bindingID

        upcomingListener?.remove()
        upcomingListener = nil

        guard !branch.isEmpty, !groupKey.isEmpty else {
            upcoming = []
            return
        }

        upcomingListener = repo.observeUpcoming(
            branch: branch,
            groupKey: groupKey,
            nowMillis: systemNowMillisCompat()
        ) { [weak self] items in
            DispatchQueue.main.async {
                guard let self,
                      self.upcomingBindingID == bindingID else { return }

                self.upcoming = items
            }
        }
    }

    func bindParticipants(for sessionId: String) {
        resetParticipantBinding()

        let bindingID = participantBindingID
        let sessionBranch = branch
        let sessionGroup = groupKey
        guard !sessionBranch.isEmpty, !sessionGroup.isEmpty else { return }

        participantsListener = repo.observeParticipants(
            branch: sessionBranch,
            groupKey: sessionGroup,
            sessionId: sessionId
        ) { [weak self] parts in
            DispatchQueue.main.async {
                guard let self,
                      self.participantBindingID == bindingID else { return }

                self.participantResponses = parts
                self.updateDisplayedParticipants()
            }
        }

        groupRecipientsTask = Task { [weak self] in
            do {
                let recipients = try await Self.loadGroupRecipients(
                    branch: sessionBranch,
                    groupKey: sessionGroup
                )

                guard !Task.isCancelled,
                      let self,
                      self.participantBindingID == bindingID else { return }

                self.groupRecipients = recipients
                self.updateDisplayedParticipants()
            } catch {
                guard !Task.isCancelled else { return }

                #if DEBUG
                let failure = error as NSError
                print("KMI_FREE_SESSION_RECIPIENTS_READ_FAILED \(failure.domain) code=\(failure.code)")
                #endif
            }
        }
    }

    private enum GroupRecipientsError: Error {
        case invalidResponse
    }

    private static func loadGroupRecipients(
        branch: String,
        groupKey: String
    ) async throws -> [FreeSessionPart] {
        let result = try await Functions.functions()
            .httpsCallable("loadSecureCoachBroadcastRecipients")
            .call([
                "branch": branch,
                "groups": [groupKey]
            ])

        guard let payload = result.data as? [String: Any],
              let recipients = payload["recipients"] as? [[String: Any]] else {
            throw GroupRecipientsError.invalidResponse
        }

        return recipients.compactMap { recipient in
            let uid = (recipient["uid"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (recipient["name"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !uid.isEmpty, !name.isEmpty else { return nil }

            return FreeSessionPart(
                uid: uid,
                name: name,
                state: .invited,
                updatedAt: 0
            )
        }
    }

    private func updateDisplayedParticipants() {
        var byUID: [String: FreeSessionPart] = [:]

        for recipient in groupRecipients {
            byUID[recipient.uid] = recipient
        }

        for response in participantResponses {
            byUID[response.uid] = response
        }

        participants = byUID.values.sorted { first, second in
            if first.updatedAt != second.updatedAt {
                return first.updatedAt > second.updatedAt
            }

            let order = first.name.localizedCaseInsensitiveCompare(second.name)
            return order == .orderedSame
                ? first.uid < second.uid
                : order == .orderedAscending
        }
    }

    func openDetails(_ session: FreeSession) {
        selectedSession = session
        bindParticipants(for: session.id)
    }

    func closeDetails() {
        selectedSession = nil
        resetParticipantBinding()
    }

    private func resetParticipantBinding() {
        participantBindingID = UUID()

        participantsListener?.remove()
        participantsListener = nil

        groupRecipientsTask?.cancel()
        groupRecipientsTask = nil

        participantResponses = []
        groupRecipients = []
        participants = []
    }

    @discardableResult
    func createSession(
        title: String,
        locationName: String?,
        lat: Double? = nil,
        lng: Double? = nil,
        startsAt: Int64
    ) async -> Bool {
        guard !isLoading,
              !branch.isEmpty,
              !groupKey.isEmpty,
              !myUid.isEmpty,
              !myName.isEmpty else {
            return false
        }

        let sessionBranch = branch
        let sessionGroup = groupKey
        let creatorUid = myUid

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await repo.createFreeSession(
                branch: sessionBranch,
                groupKey: sessionGroup,
                title: title,
                locationName: locationName,
                lat: lat,
                lng: lng,
                startsAt: startsAt,
                createdByUid: creatorUid,
                createdByName: myName
            )

            isCreating = false

            do {
                try await requestGroupInvitations(
                    branch: sessionBranch,
                    groupKey: sessionGroup,
                    creatorUid: creatorUid,
                    title: title,
                    locationName: locationName,
                    startsAt: startsAt
                )
            } catch {
                errorMessage = invitationLanguageIsEnglish
                    ? "The session was created, but sending invitations could not be confirmed."
                    : "האימון נוצר, אך לא ניתן לאשר שההזמנות נשלחו."

                #if DEBUG
                let failure = error as NSError
                print("KMI_FREE_SESSION_INVITATIONS_FAILED \(failure.domain) code=\(failure.code)")
                #endif
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var invitationLanguageIsEnglish: Bool {
        let defaults = UserDefaults.standard
        let keys = [
            "kmi_app_language",
            "app_language",
            "selected_language_code",
            "initial_language_code"
        ]

        let language = keys
            .compactMap { defaults.string(forKey: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { !$0.isEmpty }

        return language?.hasPrefix("en") == true
    }

    private func requestGroupInvitations(
        branch: String,
        groupKey: String,
        creatorUid: String,
        title: String,
        locationName: String?,
        startsAt: Int64
    ) async throws {
        let recipients = try await Self.loadGroupRecipients(
            branch: branch,
            groupKey: groupKey
        )

        let targetUids = Set(recipients.map(\.uid))
            .subtracting([creatorUid])
            .sorted()

        guard !targetUids.isEmpty else { return }

        let isEnglish = invitationLanguageIsEnglish
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isEnglish ? "en_US" : "he_IL")
        formatter.dateFormat = "dd/MM HH:mm"

        let date = Date(timeIntervalSince1970: TimeInterval(startsAt) / 1_000)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = locationName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heading = isEnglish ? "New free session" : "נפתח אימון חופשי"

        let message = [
            cleanTitle.isEmpty ? heading : "\(heading): \(cleanTitle)",
            cleanLocation,
            formatter.string(from: date)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")

        _ = try await Functions.functions()
            .httpsCallable("createSecureCoachBroadcast")
            .call([
                "region": "",
                "branch": branch,
                "groups": [groupKey],
                "message": message,
                "targetUids": targetUids
            ] as [String: Any])
    }

    func setMyState(sessionId: String, state: ParticipantState) async {
        guard !branch.isEmpty, !groupKey.isEmpty, !myUid.isEmpty, !myName.isEmpty else { return }

        do {
            try await repo.setParticipantState(
                branch: branch,
                groupKey: groupKey,
                sessionId: sessionId,
                uid: myUid,
                name: myName,
                state: state
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeSession(sessionId: String) async {
        guard !branch.isEmpty, !groupKey.isEmpty, !sessionId.isEmpty else { return }

        do {
            try await repo.closeSession(
                branch: branch,
                groupKey: groupKey,
                sessionId: sessionId
            )
            closeDetails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(sessionId: String) async {
        guard !branch.isEmpty, !groupKey.isEmpty, !sessionId.isEmpty else { return }

        do {
            try await repo.deleteFreeSession(
                branch: branch,
                groupKey: groupKey,
                sessionId: sessionId
            )
            closeDetails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func myState(in sessionId: String) -> ParticipantState? {
        guard selectedSession?.id == sessionId else { return nil }
        return participantResponses.first(where: { $0.uid == myUid })?.state
    }

    func canManage(_ session: FreeSession) -> Bool {
        session.createdByUid == myUid
    }

    private func systemNowMillisCompat() -> Int64 {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return Int64(startOfToday.timeIntervalSince1970 * 1000)
    }
}
