import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Progress Models

struct UserProgressComparison {
    let beltId: String
    let usersCount: Int
    let userKnownPercent: Int
    let averageKnownPercent: Int
    let percentileAbove: Int
    let hasEnoughData: Bool
}

struct CoachGroupProgressSummary {
    let beltId: String
    let groupsCount: Int
    let totalTrainees: Int
    let traineesWithProgress: Int
    let averageKnownPercent: Int

    var traineesWithoutProgress: Int {
        max(
            totalTrainees - traineesWithProgress,
            0
        )
    }

    var hasProgressData: Bool {
        traineesWithProgress > 0
    }
}

// MARK: - User Progress Repository

enum UserProgressRepository {

    // MARK: Bucket

    static func bucketForPercent(
        _ percent: Int
    ) -> Int {

        let safePercent =
            min(
                max(
                    percent,
                    0
                ),
                100
            )

        switch safePercent {

        case 0..<10:
            return 0

        case 10..<20:
            return 10

        case 20..<30:
            return 20

        case 30..<40:
            return 30

        case 40..<50:
            return 40

        case 50..<60:
            return 50

        case 60..<70:
            return 60

        case 70..<80:
            return 70

        case 80..<90:
            return 80

        case 90..<100:
            return 90

        default:
            return 100
        }
    }

    // MARK: Save Progress

    static func saveUserProgress(
        beltId: String,
        knownPercent: Int,
        knownCount: Int,
        totalCount: Int
    ) async throws {

        guard let uid =
            Auth.auth()
                .currentUser?
                .uid
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
              !uid.isEmpty else {

            return
        }

        let cleanBeltId =
            beltId.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanBeltId.isEmpty else {
            return
        }

        let safePercent =
            min(
                max(
                    knownPercent,
                    0
                ),
                100
            )

        let safeKnownCount =
            max(
                knownCount,
                0
            )

        let safeTotalCount =
            max(
                totalCount,
                0
            )

        /*
         * זהה ל-Android:
         *
         * userProgress/{uid}__{beltId}
         */
        let documentId =
            "\(uid)__\(cleanBeltId)"

        let data:
            [String: Any] = [

                "uid":
                    uid,

                "beltId":
                    cleanBeltId,

                "knownPercent":
                    safePercent,

                "knownCount":
                    safeKnownCount,

                "totalCount":
                    safeTotalCount,

                "bucket":
                    bucketForPercent(
                        safePercent
                    ),

                "updatedAt":
                    FieldValue
                        .serverTimestamp()
            ]

        try await Firestore
            .firestore()
            .collection(
                "userProgress"
            )
            .document(
                documentId
            )
            .setData(
                data
            )
    }

    // MARK: Belt Comparison

    static func loadBeltComparison(
        beltId: String,
        userKnownPercent: Int
    ) async throws -> UserProgressComparison? {

        guard let currentUid =
            Auth.auth()
                .currentUser?
                .uid
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
              !currentUid.isEmpty else {

            return nil
        }

        let cleanBeltId =
            beltId.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanBeltId.isEmpty else {
            return nil
        }

        let safeUserPercent =
            min(
                max(
                    userKnownPercent,
                    0
                ),
                100
            )

        /*
         * Source.DEFAULT:
         * Firestore רשאי להשתמש ב-cache כ-fallback.
         */
        let snapshot =
            try await Firestore
                .firestore()
                .collection(
                    "userProgress"
                )
                .whereField(
                    "beltId",
                    isEqualTo:
                        cleanBeltId
                )
                .getDocuments()

        /*
         * משתמשים רק במסמכים במבנה החדש:
         *
         *     {uid}__{beltId}
         *
         * מסמכי legacy אינם משתתפים בחישוב.
         */
        var percentByUid:
            [String: Int] = [:]

        for document in
            snapshot.documents {

            let data =
                document.data()

            let uid =
                (
                    data["uid"]
                    as? String
                    ?? ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard !uid.isEmpty else {
                continue
            }

            let totalCount =
                intValue(
                    data[
                        "totalCount"
                    ]
                )

            let knownPercent =
                intValue(
                    data[
                        "knownPercent"
                    ],
                    defaultValue:
                        -1
                )

            let expectedDocumentId =
                "\(uid)__\(cleanBeltId)"

            guard
                document.documentID
                    == expectedDocumentId,
                totalCount > 0,
                (0...100).contains(
                    knownPercent
                )
            else {
                continue
            }

            percentByUid[
                uid
            ] = knownPercent
        }

        /*
         * לצורך "אתה מעל" משווים רק
         * מול משתמשים אחרים.
         */
        let otherUserPercents =
            percentByUid
                .filter {
                    uid,
                    _ in

                    uid != currentUid
                }
                .map(
                    \.value
                )

        guard !otherUserPercents.isEmpty else {
            return nil
        }

        /*
         * הממוצע כולל גם את המשתמש הנוכחי.
         *
         * אם המסמך שלו עדיין לא זמין ב-query,
         * משתמשים זמנית באחוז המקומי.
         */
        let allUserPercents:
            [Int]

        if percentByUid[
            currentUid
        ] != nil {

            allUserPercents =
                Array(
                    percentByUid.values
                )

        } else {

            allUserPercents =
                Array(
                    percentByUid.values
                )
                + [
                    safeUserPercent
                ]
        }

        let averageKnownPercent =
            min(
                max(
                    Int(
                        round(
                            Double(
                                allUserPercents.reduce(
                                    0,
                                    +
                                )
                            )
                            / Double(
                                allUserPercents.count
                            )
                        )
                    ),
                    0
                ),
                100
            )

        let usersBelowCurrent =
            otherUserPercents.filter {
                $0 < safeUserPercent
            }
            .count

        let percentileAbove =
            min(
                max(
                    Int(
                        round(
                            Double(
                                usersBelowCurrent
                            )
                            / Double(
                                otherUserPercents.count
                            )
                            * 100.0
                        )
                    ),
                    0
                ),
                100
            )

        return UserProgressComparison(
            beltId:
                cleanBeltId,
            usersCount:
                allUserPercents.count,
            userKnownPercent:
                safeUserPercent,
            averageKnownPercent:
                averageKnownPercent,
            percentileAbove:
                percentileAbove,
            hasEnoughData:
                true
        )
    }

    // MARK: Coach Groups Progress

    static func loadCoachGroupsBeltProgress(
        beltId: String
    ) async throws -> CoachGroupProgressSummary? {

        guard let coachUid =
            Auth.auth()
                .currentUser?
                .uid
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                ),
              !coachUid.isEmpty else {

            return nil
        }

        let cleanBeltId =
            beltId.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        guard !cleanBeltId.isEmpty else {
            return nil
        }

        let firestore =
            Firestore.firestore()

        let coachDocument =
            try await firestore
                .collection(
                    "users"
                )
                .document(
                    coachUid
                )
                .getDocument()

        guard coachDocument.exists else {
            return nil
        }

        /*
         * קודם משתמשים במקור האמת החדש:
         * coachBranchAssignments.
         */
        let rawAssignments =
            coachDocument.data()?[
                RegistrationFormState
                    .BranchAssignmentsCodec
                    .firestoreKey
            ] as? [Any]
            ?? []

        let assignments =
            RegistrationFormState
                .BranchAssignmentsCodec
                .fromFirestoreList(
                    rawAssignments
                )

        var coachBranches =
            Set(
                RegistrationFormState
                    .BranchAssignmentsCodec
                    .flattenBranches(
                        assignments
                    )
                    .map(
                        normalizeAssignment
                    )
            )

        var coachGroups =
            Set(
                RegistrationFormState
                    .BranchAssignmentsCodec
                    .flattenGroups(
                        assignments
                    )
                    .map(
                        normalizeAssignment
                    )
            )

        /*
         * fallback לנתוני משתמש ישנים,
         * אם עדיין אין coachBranchAssignments.
         */
        if coachBranches.isEmpty {

            coachBranches =
                readAssignments(
                    data:
                        coachDocument.data()
                        ?? [:],
                    listFields: [
                        "branches",
                        "selected_branches"
                    ],
                    singleFields: [
                        "activeBranch",
                        "active_branch",
                        "branch",
                        "coachBranch",
                        "coach_branch",
                        "selected_branch",
                        "current_branch"
                    ],
                    csvFields: [
                        "branchesCsv",
                        "branches_csv"
                    ]
                )
        }

        if coachGroups.isEmpty {

            coachGroups =
                readAssignments(
                    data:
                        coachDocument.data()
                        ?? [:],
                    listFields: [
                        "groups",
                        "selected_groups"
                    ],
                    singleFields: [
                        "primaryGroup",
                        "activeGroup",
                        "active_group",
                        "groupKey",
                        "group_key",
                        "group",
                        "age_group",
                        "coachGroupKey",
                        "coach_groupKey",
                        "selected_groupKey",
                        "current_groupKey"
                    ],
                    csvFields: [
                        "groupsCsv",
                        "groups_csv"
                    ]
                )
        }

        /*
         * בלי קבוצה אין דרך בטוחה לזהות
         * אילו מתאמנים שייכים למאמן.
         */
        guard !coachGroups.isEmpty else {

            return CoachGroupProgressSummary(
                beltId:
                    cleanBeltId,
                groupsCount:
                    0,
                totalTrainees:
                    0,
                traineesWithProgress:
                    0,
                averageKnownPercent:
                    0
            )
        }

        let usersSnapshot =
            try await firestore
                .collection(
                    "users"
                )
                .getDocuments()

        var traineeUids =
            Set<String>()

        for document in
            usersSnapshot.documents {

            let data =
                document.data()

            let role =
                (
                    data["role"]
                    as? String
                    ?? ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

            let isTrainee =
                role == "trainee"
                || role.contains(
                    "trainee"
                )
                || role.contains(
                    "מתאמן"
                )

            guard isTrainee else {
                continue
            }

            let traineeBranches =
                readAssignments(
                    data:
                        data,
                    listFields: [
                        "branches",
                        "selected_branches"
                    ],
                    singleFields: [
                        "activeBranch",
                        "active_branch",
                        "branch",
                        "selected_branch",
                        "current_branch"
                    ],
                    csvFields: [
                        "branchesCsv",
                        "branches_csv"
                    ]
                )

            let traineeGroups =
                readAssignments(
                    data:
                        data,
                    listFields: [
                        "groups",
                        "selected_groups"
                    ],
                    singleFields: [
                        "primaryGroup",
                        "activeGroup",
                        "active_group",
                        "groupKey",
                        "group_key",
                        "group",
                        "age_group",
                        "selected_groupKey",
                        "current_groupKey"
                    ],
                    csvFields: [
                        "groupsCsv",
                        "groups_csv"
                    ]
                )

            let belongsToCoachGroup =
                !traineeGroups
                    .isDisjoint(
                        with:
                            coachGroups
                    )

            let belongsToCoachBranch =
                coachBranches.isEmpty
                || !traineeBranches
                    .isDisjoint(
                        with:
                            coachBranches
                    )

            guard
                belongsToCoachGroup,
                belongsToCoachBranch
            else {
                continue
            }

            let traineeUid =
                (
                    data["uid"]
                    as? String
                    ?? document.documentID
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            if !traineeUid.isEmpty,
               traineeUid != coachUid {

                traineeUids.insert(
                    traineeUid
                )
            }
        }

        guard !traineeUids.isEmpty else {

            return CoachGroupProgressSummary(
                beltId:
                    cleanBeltId,
                groupsCount:
                    coachGroups.count,
                totalTrainees:
                    0,
                traineesWithProgress:
                    0,
                averageKnownPercent:
                    0
            )
        }

        let progressSnapshot =
            try await firestore
                .collection(
                    "userProgress"
                )
                .whereField(
                    "beltId",
                    isEqualTo:
                        cleanBeltId
                )
                .getDocuments()

        var progressByUid:
            [String: Int] = [:]

        for document in
            progressSnapshot.documents {

            let data =
                document.data()

            let uid =
                (
                    data["uid"]
                    as? String
                    ?? ""
                )
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            guard traineeUids.contains(
                uid
            ) else {
                continue
            }

            let totalCount =
                intValue(
                    data[
                        "totalCount"
                    ]
                )

            let knownPercent =
                intValue(
                    data[
                        "knownPercent"
                    ],
                    defaultValue:
                        -1
                )

            let expectedDocumentId =
                "\(uid)__\(cleanBeltId)"

            guard
                document.documentID
                    == expectedDocumentId,
                totalCount > 0,
                (0...100).contains(
                    knownPercent
                )
            else {
                continue
            }

            progressByUid[
                uid
            ] = knownPercent
        }

        let averageKnownPercent:
            Int

        if progressByUid.isEmpty {

            averageKnownPercent =
                0

        } else {

            let total =
                progressByUid
                    .values
                    .reduce(
                        0,
                        +
                    )

            averageKnownPercent =
                min(
                    max(
                        Int(
                            round(
                                Double(total)
                                / Double(
                                    progressByUid.count
                                )
                            )
                        ),
                        0
                    ),
                    100
                )
        }

        return CoachGroupProgressSummary(
            beltId:
                cleanBeltId,
            groupsCount:
                coachGroups.count,
            totalTrainees:
                traineeUids.count,
            traineesWithProgress:
                progressByUid.count,
            averageKnownPercent:
                averageKnownPercent
        )
    }

    // MARK: Helpers

    nonisolated private static func normalizeAssignment(
        _ value: String
    ) -> String {

        value
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of:
                    "־",
                with:
                    "-"
            )
            .replacingOccurrences(
                of:
                    "–",
                with:
                    "-"
            )
            .replacingOccurrences(
                of:
                    "—",
                with:
                    "-"
            )
            .replacingOccurrences(
                of:
                    "\\s+",
                with:
                    " ",
                options:
                    .regularExpression
            )
            .lowercased()
    }

    private static func readAssignments(
        data: [String: Any],
        listFields: [String],
        singleFields: [String],
        csvFields: [String]
    ) -> Set<String> {

        var values:
            [String] = []

        for fieldName in
            listFields {

            if let list =
                data[fieldName]
                as? [Any] {

                values.append(
                    contentsOf:
                        list.compactMap {
                            $0 as? String
                        }
                )
            }
        }

        for fieldName in
            singleFields {

            if let value =
                data[fieldName]
                as? String {

                values.append(
                    value
                )
            }
        }

        for fieldName in
            csvFields {

            if let value =
                data[fieldName]
                as? String {

                values.append(
                    contentsOf:
                        value.components(
                            separatedBy:
                                ","
                        )
                )
            }
        }

        return Set(
            values
                .map(
                    normalizeAssignment
                )
                .filter {
                    !$0.isEmpty
                }
        )
    }

    nonisolated private static func intValue(
        _ value: Any?,
        defaultValue: Int = 0
    ) -> Int {

        if let number =
            value as? NSNumber {

            return number.intValue
        }

        if let int =
            value as? Int {

            return int
        }

        if let string =
            value as? String,
           let int =
            Int(string) {

            return int
        }

        return defaultValue
    }
}
