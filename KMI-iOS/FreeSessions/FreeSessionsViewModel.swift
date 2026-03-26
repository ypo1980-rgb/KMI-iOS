import Foundation
import Combine
import FirebaseFirestore

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
    private var participantsListener: ListenerRegistration?

    init(repo: FreeSessionsRepository = .shared) {
        self.repo = repo
    }

    deinit {
        upcomingListener?.remove()
        participantsListener?.remove()
    }

    func setContext(
        branch: String,
        groupKey: String,
        myUid: String,
        myName: String
    ) {
        self.branch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        self.groupKey = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.myUid = myUid.trimmingCharacters(in: .whitespacesAndNewlines)
        self.myName = myName.trimmingCharacters(in: .whitespacesAndNewlines)

        bindUpcoming()
    }

    func bindUpcoming() {
        guard !branch.isEmpty, !groupKey.isEmpty else {
            upcoming = []
            return
        }

        upcomingListener?.remove()
        upcomingListener = repo.observeUpcoming(
            branch: branch,
            groupKey: groupKey,
            nowMillis: systemNowMillisCompat()
        ) { [weak self] items in
            DispatchQueue.main.async {
                self?.upcoming = items
            }
        }
    }

    func bindParticipants(for sessionId: String) {
        participantsListener?.remove()
        participantsListener = repo.observeParticipants(
            branch: branch,
            groupKey: groupKey,
            sessionId: sessionId
        ) { [weak self] parts in
            DispatchQueue.main.async {
                self?.participants = parts
            }
        }
    }

    func openDetails(_ session: FreeSession) {
        selectedSession = session
        bindParticipants(for: session.id)
    }

    func closeDetails() {
        selectedSession = nil
        participants = []
        participantsListener?.remove()
        participantsListener = nil
    }

    func createSession(
        title: String,
        locationName: String?,
        lat: Double? = nil,
        lng: Double? = nil,
        startsAt: Int64
    ) async {
        guard !branch.isEmpty, !groupKey.isEmpty, !myUid.isEmpty, !myName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await repo.createFreeSession(
                branch: branch,
                groupKey: groupKey,
                title: title,
                locationName: locationName,
                lat: lat,
                lng: lng,
                startsAt: startsAt,
                createdByUid: myUid,
                createdByName: myName
            )
            isCreating = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
        participants.first(where: { $0.uid == myUid && selectedSession?.id == sessionId })?.state
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
