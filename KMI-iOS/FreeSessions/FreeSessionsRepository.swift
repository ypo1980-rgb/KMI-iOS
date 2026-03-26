import Foundation
import FirebaseFirestore

final class FreeSessionsRepository {

    static let shared = FreeSessionsRepository()
    private let db = Firestore.firestore()

    private init() {}

    private enum Paths {
        static let rootBranches = "branches"
        static let rootGroups = "groups"
        static let colFreeSessions = "free_sessions"
        static let colParticipants = "participants"

        static func freeSessionsCollection(branch: String, groupKey: String) -> CollectionReference {
            Firestore.firestore()
                .collection(rootBranches)
                .document(branch.trimmingCharacters(in: .whitespacesAndNewlines))
                .collection(rootGroups)
                .document(groupKey.trimmingCharacters(in: .whitespacesAndNewlines))
                .collection(colFreeSessions)
        }
    }

    func systemNowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    func observeUpcoming(
        branch: String,
        groupKey: String,
        nowMillis: Int64,
        onChange: @escaping ([FreeSession]) -> Void
    ) -> ListenerRegistration {
        Paths.freeSessionsCollection(branch: branch, groupKey: groupKey)
            .whereField("startsAt", isGreaterThanOrEqualTo: nowMillis)
            .order(by: "startsAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard error == nil else {
                    onChange([])
                    return
                }

                let sessions: [FreeSession] = snapshot?.documents.compactMap { d in
                    let title = d.get("title") as? String ?? ""
                    let createdByUid = d.get("createdByUid") as? String ?? ""
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || createdByUid.isEmpty {
                        return nil
                    }

                    let status = (d.get("status") as? String ?? "OPEN")
                    let item = FreeSession(
                        id: (d.get("id") as? String) ?? d.documentID,
                        branch: (d.get("branch") as? String) ?? branch,
                        groupKey: (d.get("groupKey") as? String) ?? groupKey,
                        title: title,
                        locationName: d.get("locationName") as? String,
                        lat: d.get("lat") as? Double,
                        lng: d.get("lng") as? Double,
                        startsAt: d.get("startsAt") as? Int64 ?? Int64(d.get("startsAt") as? Int ?? 0),
                        createdAt: d.get("createdAt") as? Int64 ?? Int64(d.get("createdAt") as? Int ?? 0),
                        createdByUid: createdByUid,
                        createdByName: (d.get("createdByName") as? String) ?? "",
                        status: status,
                        goingCount: d.get("goingCount") as? Int ?? Int(d.get("goingCount") as? Int64 ?? 0),
                        onWayCount: d.get("onWayCount") as? Int ?? Int(d.get("onWayCount") as? Int64 ?? 0),
                        arrivedCount: d.get("arrivedCount") as? Int ?? Int(d.get("arrivedCount") as? Int64 ?? 0),
                        cantCount: d.get("cantCount") as? Int ?? Int(d.get("cantCount") as? Int64 ?? 0)
                    )

                    return item.isOpen ? item : nil
                } ?? []

                onChange(sessions)
            }
    }

    func observeParticipants(
        branch: String,
        groupKey: String,
        sessionId: String,
        onChange: @escaping ([FreeSessionPart]) -> Void
    ) -> ListenerRegistration {
        Paths.freeSessionsCollection(branch: branch, groupKey: groupKey)
            .document(sessionId)
            .collection(Paths.colParticipants)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard error == nil else {
                    onChange([])
                    return
                }

                let parts: [FreeSessionPart] = snapshot?.documents.compactMap { d in
                    let uid = (d.get("uid") as? String) ?? d.documentID
                    guard let name = d.get("name") as? String, !name.isEmpty else { return nil }

                    let updated = d.get("updatedAt") as? Int64 ?? Int64(d.get("updatedAt") as? Int ?? 0)

                    return FreeSessionPart(
                        uid: uid,
                        name: name,
                        state: ParticipantState.from(d.get("state") as? String),
                        updatedAt: updated
                    )
                } ?? []

                onChange(parts)
            }
    }

    func createFreeSession(
        branch: String,
        groupKey: String,
        title: String,
        locationName: String?,
        lat: Double?,
        lng: Double?,
        startsAt: Int64,
        createdByUid: String,
        createdByName: String
    ) async throws -> String {
        let col = Paths.freeSessionsCollection(branch: branch, groupKey: groupKey)
        let doc = col.document()
        let now = systemNowMillis()

        let safeName = createdByName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "משתמש"
            : createdByName.trimmingCharacters(in: .whitespacesAndNewlines)

        let data: [String: Any?] = [
            "id": doc.documentID,
            "branch": branch.trimmingCharacters(in: .whitespacesAndNewlines),
            "groupKey": groupKey.trimmingCharacters(in: .whitespacesAndNewlines),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "locationName": locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
            "lat": lat,
            "lng": lng,
            "startsAt": startsAt,
            "createdAt": now,
            "createdByUid": createdByUid,
            "createdByName": safeName,
            "status": "OPEN",
            "goingCount": 0,
            "onWayCount": 0,
            "arrivedCount": 0,
            "cantCount": 0
        ]

        try await setDocument(doc, data: compactMapValues(data))

        try await setParticipantState(
            branch: branch,
            groupKey: groupKey,
            sessionId: doc.documentID,
            uid: createdByUid,
            name: safeName,
            state: .going
        )

        return doc.documentID
    }

    func setParticipantState(
        branch: String,
        groupKey: String,
        sessionId: String,
        uid: String,
        name: String,
        state: ParticipantState
    ) async throws {
        let sessionDoc = Paths.freeSessionsCollection(branch: branch, groupKey: groupKey).document(sessionId)
        let partDoc = sessionDoc.collection(Paths.colParticipants).document(uid)
        let now = systemNowMillis()

        try await setDocument(partDoc, data: [
            "uid": uid,
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "state": state.rawValue,
            "updatedAt": now
        ])

        let snapshot = try await getDocuments(sessionDoc.collection(Paths.colParticipants))
        var going = 0
        var onWay = 0
        var arrived = 0
        var cant = 0

        for doc in snapshot.documents {
            switch ParticipantState.from(doc.get("state") as? String) {
            case .going: going += 1
            case .onWay: onWay += 1
            case .arrived: arrived += 1
            case .cant: cant += 1
            case .invited: break
            }
        }

        try await updateDocument(sessionDoc, data: [
            "goingCount": going,
            "onWayCount": onWay,
            "arrivedCount": arrived,
            "cantCount": cant,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func closeSession(
        branch: String,
        groupKey: String,
        sessionId: String
    ) async throws {
        let doc = Paths.freeSessionsCollection(branch: branch, groupKey: groupKey).document(sessionId)
        try await updateDocument(doc, data: [
            "status": "CLOSED",
            "closedAt": systemNowMillis()
        ])
    }

    func deleteFreeSession(
        branch: String,
        groupKey: String,
        sessionId: String
    ) async throws {
        let sessionDoc = Paths.freeSessionsCollection(branch: branch, groupKey: groupKey).document(sessionId)
        let participantsCol = sessionDoc.collection(Paths.colParticipants)

        while true {
            let snap = try await getDocuments(participantsCol.limit(to: 450))
            if snap.documents.isEmpty { break }

            let batch = db.batch()
            for d in snap.documents {
                batch.deleteDocument(d.reference)
            }
            try await commitBatch(batch)
        }

        try await deleteDocument(sessionDoc)
    }

    private func compactMapValues(_ dict: [String: Any?]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            if let v { out[k] = v }
        }
        return out
    }
}

// MARK: - Async wrappers

private extension FreeSessionsRepository {
    func setDocument(_ ref: DocumentReference, data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func updateDocument(_ ref: DocumentReference, data: [String: Any]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func deleteDocument(_ ref: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func getDocuments(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "FreeSessionsRepository",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing snapshot"]
                        )
                    )
                }
            }
        }
    }

    func commitBatch(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
