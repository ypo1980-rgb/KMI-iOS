import Foundation
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

enum TrainingOverrideRepositoryError:
    LocalizedError {

    case missingSignedInUser
    case missingBranch
    case missingGroup
    case missingOccurrenceKey
    case cancellationReasonTooShort
    case invalidNewStartTime
    case invalidNewEndTime
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .missingSignedInUser:
            return "No signed-in user"

        case .missingBranch:
            return "Missing training branch"

        case .missingGroup:
            return "Missing training group"

        case .missingOccurrenceKey:
            return "Missing occurrence key"

        case .cancellationReasonTooShort:
            return "Cancellation reason is too short"

        case .invalidNewStartTime:
            return "Invalid new training start time"

        case .invalidNewEndTime:
            return "New training end time must be after start time"

        case .invalidDateRange:
            return "Invalid training override date range"
        }
    }
}

/*
 * שכבת הגישה המרכזית לשינויים באימונים.
 *
 * אין להכניס לוגיקת Firestore ישירות
 * לתוך HomeView.
 */
enum TrainingOverrideRepository {

    private static let collectionName =
        "trainingOverrides"

    private static let notificationStatusPending =
        "pending"

    private static let sourceIOS =
        "ios_training_override"

    private static let defaultTrainingDurationMillis:
        Int64 = 90 * 60 * 1000

    private static var auth: Auth {
        Auth.auth()
    }

    private static var firestore: Firestore {
        Firestore.firestore()
    }

    // MARK: - Occurrence identity

    /*
     * יצירת מפתח קבוע למופע אימון.
     *
     * המפתח כולל את זמן ההתחלה המקורי.
     * שינוי שעה אינו משנה את זהות האימון.
     */
    static func buildOccurrenceKey(
        training: TrainingData,
        branch: String,
        group: String
    ) -> String {
        let originalStartMillis =
            millis(from: training.date)

        let originalEndMillis =
            endMillis(
                for: training,
                originalStartMillis:
                    originalStartMillis
            )

        return buildOccurrenceKey(
            branch: branch,
            group: group,
            place: training.place,
            address: training.address,
            coachName: training.coach,
            originalStartMillis:
                originalStartMillis,
            originalEndMillis:
                originalEndMillis
        )
    }

    static func buildOccurrenceKey(
        branch: String,
        group: String,
        place: String,
        address: String,
        coachName: String,
        originalStartMillis: Int64,
        originalEndMillis: Int64
    ) -> String {
        [
            normalizeIdentityPart(branch),
            normalizeIdentityPart(group),
            normalizeIdentityPart(place),
            normalizeIdentityPart(address),
            normalizeIdentityPart(coachName),
            String(originalStartMillis),
            String(originalEndMillis)
        ]
        .joined(separator: "|")
    }

    /*
     * מזהה מסמך בטוח לשימוש ב־Firestore.
     */
    static func documentIdForOccurrenceKey(
        _ occurrenceKey: String
    ) -> String {
        let digest =
            SHA256.hash(
                data: Data(
                    occurrenceKey.utf8
                )
            )

        return digest.map {
            String(
                format: "%02x",
                $0
            )
        }
        .joined()
    }

    // MARK: - Save changes

    static func cancelTraining(
        training: TrainingData,
        branch: String,
        group: String,
        reason: String,
        changedByName: String,
        completion:
            @escaping (Result<Void, Error>) -> Void
    ) {
        let cleanReason =
            reason.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard cleanReason.count >= 3 else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .cancellationReasonTooShort
                )
            )
            return
        }

        saveOverride(
            training: training,
            branch: branch,
            group: group,
            type: .cancelled,
            reason: cleanReason,
            changedByName: changedByName,
            newStartMillis: nil,
            newEndMillis: nil,
            completion: completion
        )
    }

    static func changeTrainingTime(
        training: TrainingData,
        branch: String,
        group: String,
        newStartMillis: Int64,
        newEndMillis: Int64,
        reason: String,
        changedByName: String,
        completion:
            @escaping (Result<Void, Error>) -> Void
    ) {
        guard newStartMillis > 0 else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .invalidNewStartTime
                )
            )
            return
        }

        guard newEndMillis > newStartMillis else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .invalidNewEndTime
                )
            )
            return
        }

        let cleanReason =
            reason
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        saveOverride(
            training: training,
            branch: branch,
            group: group,
            type: .timeChanged,
            reason:
                cleanReason.isEmpty
                ? "Training time changed"
                : cleanReason,
            changedByName: changedByName,
            newStartMillis: newStartMillis,
            newEndMillis: newEndMillis,
            completion: completion
        )
    }

    /*
     * ביטול השינוי והחזרת האימון להגדרה המקורית.
     *
     * המסמך אינו נמחק כדי לשמור היסטוריה.
     */
    static func restoreOriginalTraining(
        training: TrainingData,
        branch: String,
        group: String,
        changedByName: String,
        completion:
            @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUser =
                auth.currentUser,
              !currentUser.uid
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .missingSignedInUser
                )
            )
            return
        }

        let occurrenceKey =
            buildOccurrenceKey(
                training: training,
                branch: branch,
                group: group
            )

        let documentId =
            documentIdForOccurrenceKey(
                occurrenceKey
            )

        let documentReference =
            firestore
                .collection(collectionName)
                .document(documentId)

        let resolvedChangedByName =
            firstNonEmpty(
                changedByName,
                currentUser.displayName ?? "",
                currentUser.email ?? "",
                "מאמן"
            )

        let updateData: [String: Any] = [
            "isActive": false,
            "restoredByUid":
                currentUser.uid,
            "restoredByName":
                resolvedChangedByName,
            "restoredAt":
                FieldValue.serverTimestamp(),
            "updatedAt":
                FieldValue.serverTimestamp(),
            "notificationRequested": true,
            "notificationStatus":
                notificationStatusPending,
            "source": sourceIOS
        ]

        documentReference.updateData(
            updateData
        ) { error in
            deliverResult(
                error: error,
                completion: completion
            )
        }
    }

    // MARK: - Real-time listeners

    static func listenForOccurrenceKeys(
        occurrenceKeys: Set<String>,
        onChanged:
            @escaping (
                [String: TrainingOverride]
            ) -> Void,
        onInitialLoadFinished:
            @escaping () -> Void = {},
        onError:
            @escaping (Error) -> Void = { _ in }
    ) -> TrainingOverrideListenerHandle {
        let cleanOccurrenceKeys =
            Array(
                Set(
                    occurrenceKeys
                        .map {
                            $0.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                        }
                        .filter {
                            !$0.isEmpty
                        }
                )
            )

        guard !cleanOccurrenceKeys.isEmpty else {
            DispatchQueue.main.async {
                onChanged([:])
                onInitialLoadFinished()
            }

            return TrainingOverrideListenerHandle(
                registrations: []
            )
        }

        let stateQueue =
            DispatchQueue(
                label:
                    "il.kmi.trainingOverrides.listener"
            )

        var overridesByOccurrenceKey:
            [String: TrainingOverride] = [:]

        var pendingOccurrenceKeys = Set(cleanOccurrenceKeys)

        let registrations =
            cleanOccurrenceKeys.map {
                occurrenceKey in

                let documentId =
                    documentIdForOccurrenceKey(
                        occurrenceKey
                    )

                return firestore
                    .collection(collectionName)
                    .document(documentId)
                    .addSnapshotListener {
                        snapshot,
                        error in

                        if let error {
                            stateQueue.async {
                                let didFinishInitialLoad =
                                    pendingOccurrenceKeys.remove(occurrenceKey) != nil
                                    && pendingOccurrenceKeys.isEmpty

                                DispatchQueue.main.async {
                                    onError(error)

                                    if didFinishInitialLoad {
                                        onInitialLoadFinished()
                                    }
                                }
                            }
                            return
                        }

                        let parsed =
                            snapshot?
                                .toTrainingOverride()

                        stateQueue.async {
                            if let parsed,
                               parsed.isActive {
                                overridesByOccurrenceKey[
                                    occurrenceKey
                                ] = parsed
                            } else {
                                overridesByOccurrenceKey
                                    .removeValue(
                                        forKey:
                                            occurrenceKey
                                    )
                            }

                            let currentOverrides =
                                overridesByOccurrenceKey

                            let didFinishInitialLoad =
                                pendingOccurrenceKeys.remove(occurrenceKey) != nil
                                && pendingOccurrenceKeys.isEmpty

                            DispatchQueue.main.async {
                                onChanged(
                                    currentOverrides
                                )

                                if didFinishInitialLoad {
                                    onInitialLoadFinished()
                                }
                            }
                        }
                    }
            }

        return TrainingOverrideListenerHandle(
            registrations:
                registrations
        )
    }

    /*
     * האזנה לכל השינויים בטווח תאריכים.
     *
     * הסינון לפי isActive נעשה בצד האפליקציה
     * כדי לא לדרוש אינדקס מורכב נוסף.
     */
    static func listenForOverridesInRange(
        fromOriginalStartMillis: Int64,
        toOriginalStartMillis: Int64,
        onChanged:
            @escaping (
                [String: TrainingOverride]
            ) -> Void,
        onError:
            @escaping (Error) -> Void = { _ in }
    ) -> TrainingOverrideListenerHandle {
        guard fromOriginalStartMillis > 0,
              toOriginalStartMillis > 0,
              toOriginalStartMillis
                >= fromOriginalStartMillis else {
            DispatchQueue.main.async {
                onChanged([:])
                onError(
                    TrainingOverrideRepositoryError
                        .invalidDateRange
                )
            }

            return TrainingOverrideListenerHandle(
                registrations: []
            )
        }

        let registration =
            firestore
                .collection(collectionName)
                .whereField(
                    "originalStartMillis",
                    isGreaterThanOrEqualTo:
                        fromOriginalStartMillis
                )
                .whereField(
                    "originalStartMillis",
                    isLessThanOrEqualTo:
                        toOriginalStartMillis
                )
                .addSnapshotListener {
                    snapshot,
                    error in

                    if let error {
                        DispatchQueue.main.async {
                            onError(error)
                        }
                        return
                    }

                    let overrides =
                        Dictionary(
                            uniqueKeysWithValues:
                                (
                                    snapshot?
                                        .documents
                                        ?? []
                                )
                                .compactMap {
                                    document
                                    -> (
                                        String,
                                        TrainingOverride
                                    )? in

                                    guard let override =
                                            document
                                                .toTrainingOverride(),
                                          override.isActive else {
                                        return nil
                                    }

                                    return (
                                        override
                                            .occurrenceKey,
                                        override
                                    )
                                }
                        )

                    DispatchQueue.main.async {
                        onChanged(overrides)
                    }
                }

        return TrainingOverrideListenerHandle(
            registrations: [
                registration
            ]
        )
    }

    // MARK: - Single read

    static func getOverride(
        occurrenceKey: String,
        completion:
            @escaping (
                Result<
                    TrainingOverride?,
                    Error
                >
            ) -> Void
    ) {
        let cleanOccurrenceKey =
            occurrenceKey
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !cleanOccurrenceKey.isEmpty else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .missingOccurrenceKey
                )
            )
            return
        }

        let documentId =
            documentIdForOccurrenceKey(
                cleanOccurrenceKey
            )

        firestore
            .collection(collectionName)
            .document(documentId)
            .getDocument {
                snapshot,
                error in

                if let error {
                    DispatchQueue.main.async {
                        completion(
                            .failure(error)
                        )
                    }
                    return
                }

                let override =
                    snapshot?
                        .toTrainingOverride()
                        .flatMap {
                            $0.isActive
                            ? $0
                            : nil
                        }

                DispatchQueue.main.async {
                    completion(
                        .success(override)
                    )
                }
            }
    }

    // MARK: - Private save

    private static func saveOverride(
        training: TrainingData,
        branch: String,
        group: String,
        type: TrainingOverrideType,
        reason: String,
        changedByName: String,
        newStartMillis: Int64?,
        newEndMillis: Int64?,
        completion:
            @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUser =
                auth.currentUser,
              !currentUser.uid
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .missingSignedInUser
                )
            )
            return
        }

        let cleanBranch =
            branch.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup =
            group.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanBranch.isEmpty else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .missingBranch
                )
            )
            return
        }

        guard !cleanGroup.isEmpty else {
            completion(
                .failure(
                    TrainingOverrideRepositoryError
                        .missingGroup
                )
            )
            return
        }

        let originalStartMillis =
            millis(from: training.date)

        let originalEndMillis =
            endMillis(
                for: training,
                originalStartMillis:
                    originalStartMillis
            )

        let occurrenceKey =
            buildOccurrenceKey(
                branch: cleanBranch,
                group: cleanGroup,
                place: training.place,
                address: training.address,
                coachName: training.coach,
                originalStartMillis:
                    originalStartMillis,
                originalEndMillis:
                    originalEndMillis
            )

        let documentId =
            documentIdForOccurrenceKey(
                occurrenceKey
            )

        let cleanChangedByName =
            firstNonEmpty(
                changedByName,
                currentUser.displayName ?? "",
                currentUser.email ?? "",
                "מאמן"
            )

        let documentReference =
            firestore
                .collection(collectionName)
                .document(documentId)

        firestore.runTransaction({
            transaction,
            errorPointer -> Any? in

            do {
                let existingSnapshot =
                    try transaction.getDocument(
                        documentReference
                    )

                var data: [String: Any] = [
                    "overrideId":
                        documentId,
                    "occurrenceKey":
                        occurrenceKey,
                    "type":
                        type.rawValue,
                    "branch":
                        cleanBranch,
                    "group":
                        cleanGroup,
                    "place":
                        training.place
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    "address":
                        training.address
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    "coachName":
                        training.coach
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    "originalStartMillis":
                        originalStartMillis,
                    "originalEndMillis":
                        originalEndMillis,
                    "reason":
                        reason.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                    "changedByUid":
                        currentUser.uid,
                    "changedByName":
                        cleanChangedByName,
                    "isActive":
                        true,
                    "updatedAt":
                        FieldValue.serverTimestamp(),
                    "notificationRequested":
                        true,
                    "notificationStatus":
                        notificationStatusPending,
                    "source":
                        sourceIOS
                ]

                if let newStartMillis {
                    data["newStartMillis"] =
                        newStartMillis
                } else {
                    data["newStartMillis"] =
                        FieldValue.delete()
                }

                if let newEndMillis {
                    data["newEndMillis"] =
                        newEndMillis
                } else {
                    data["newEndMillis"] =
                        FieldValue.delete()
                }

                if !existingSnapshot.exists {
                    data["createdAt"] =
                        FieldValue.serverTimestamp()
                }

                transaction.setData(
                    data,
                    forDocument:
                        documentReference,
                    merge: true
                )

                return nil
            } catch {
                errorPointer?.pointee =
                    error as NSError
                return nil
            }
        }) {
            _,
            error in

            deliverResult(
                error: error,
                completion: completion
            )
        }
    }

    // MARK: - Date helpers

    private static func millis(
        from date: Date
    ) -> Int64 {
        Int64(
            date.timeIntervalSince1970
            * 1000
        )
    }

    private static func endMillis(
        for training: TrainingData,
        originalStartMillis: Int64
    ) -> Int64 {
        let cleanEndText =
            training.endText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        let components =
            cleanEndText.split(
                separator: ":"
            )

        guard components.count == 2,
              let hour =
                Int(components[0]),
              let minute =
                Int(components[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return originalStartMillis
                + defaultTrainingDurationMillis
        }

        var dateComponents =
            Calendar.current.dateComponents(
                [
                    .year,
                    .month,
                    .day
                ],
                from: training.date
            )

        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard var endDate =
                Calendar.current.date(
                    from: dateComponents
                ) else {
            return originalStartMillis
                + defaultTrainingDurationMillis
        }

        let startDate =
            training.date

        /*
         * אימון שמסתיים אחרי חצות.
         */
        if endDate <= startDate {
            endDate =
                Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: endDate
                )
                ?? endDate
        }

        return millis(from: endDate)
    }

    // MARK: - Text helpers

    private static func normalizeIdentityPart(
        _ rawValue: String
    ) -> String {
        rawValue
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "־",
                with: "-"
            )
            .replacingOccurrences(
                of: "–",
                with: "-"
            )
            .replacingOccurrences(
                of: "—",
                with: "-"
            )
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .lowercased(
                with: Locale(
                    identifier: "he_IL"
                )
            )
    }

    private static func firstNonEmpty(
        _ values: String...
    ) -> String {
        values
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first {
                !$0.isEmpty
            }
            ?? ""
    }

    private static func deliverResult(
        error: Error?,
        completion:
            @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            if let error {
                completion(
                    .failure(error)
                )
            } else {
                completion(
                    .success(())
                )
            }
        }
    }
}

// MARK: - Firestore parsing

private extension DocumentSnapshot {

    func toTrainingOverride()
        -> TrainingOverride? {
        guard exists,
              let data = data() else {
            return nil
        }

        let occurrenceKey =
            (
                data["occurrenceKey"]
                as? String
                ?? ""
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !occurrenceKey.isEmpty else {
            return nil
        }

        guard let type =
                TrainingOverrideType
                    .fromFirestoreValue(
                        data["type"]
                        as? String
                    ) else {
            return nil
        }

        guard let originalStartMillis =
                int64Value(
                    data[
                        "originalStartMillis"
                    ]
                ),
              let originalEndMillis =
                int64Value(
                    data[
                        "originalEndMillis"
                    ]
                ) else {
            return nil
        }

        return TrainingOverride(
            documentId:
                documentID,
            occurrenceKey:
                occurrenceKey,
            type:
                type,
            branch:
                data["branch"]
                as? String
                ?? "",
            group:
                data["group"]
                as? String
                ?? "",
            place:
                data["place"]
                as? String
                ?? "",
            address:
                data["address"]
                as? String
                ?? "",
            coachName:
                data["coachName"]
                as? String
                ?? "",
            originalStartMillis:
                originalStartMillis,
            originalEndMillis:
                originalEndMillis,
            newStartMillis:
                int64Value(
                    data["newStartMillis"]
                ),
            newEndMillis:
                int64Value(
                    data["newEndMillis"]
                ),
            reason:
                data["reason"]
                as? String
                ?? "",
            changedByUid:
                data["changedByUid"]
                as? String
                ?? "",
            changedByName:
                data["changedByName"]
                as? String
                ?? "",
            isActive:
                data["isActive"]
                as? Bool
                ?? false,
            createdAt:
                data["createdAt"]
                as? Timestamp,
            updatedAt:
                data["updatedAt"]
                as? Timestamp,
            notificationRequested:
                data["notificationRequested"]
                as? Bool
                ?? false,
            notificationStatus:
                data["notificationStatus"]
                as? String
                ?? ""
        )
    }

    private func int64Value(
        _ value: Any?
    ) -> Int64? {
        if let value = value as? Int64 {
            return value
        }

        if let value = value as? Int {
            return Int64(value)
        }

        if let value = value as? NSNumber {
            return value.int64Value
        }

        if let value = value as? Double {
            return Int64(value)
        }

        return nil
    }
}
