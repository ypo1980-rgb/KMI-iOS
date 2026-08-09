import Foundation
import FirebaseFirestore

/*
 * סוג השינוי שבוצע במופע אימון מסוים.
 *
 * cancelled:
 * האימון בוטל לחלוטין.
 *
 * timeChanged:
 * האימון מתקיים, אך בשעה שונה.
 */
enum TrainingOverrideType:
    String,
    CaseIterable,
    Codable {

    case cancelled = "cancelled"
    case timeChanged = "time_changed"

    static func fromFirestoreValue(
        _ rawValue: String?
    ) -> TrainingOverrideType? {
        guard let rawValue else {
            return nil
        }

        let cleanValue =
            rawValue
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        return TrainingOverrideType(
            rawValue: cleanValue
        )
    }
}

/*
 * שינוי פעיל או היסטורי של מופע אימון יחיד.
 *
 * occurrenceKey מתייחס תמיד לאימון המקורי.
 * גם כאשר שעת האימון משתנה, המפתח אינו משתנה.
 */
struct TrainingOverride:
    Identifiable,
    Equatable {

    let documentId: String
    let occurrenceKey: String

    let type: TrainingOverrideType

    let branch: String
    let group: String
    let place: String
    let address: String
    let coachName: String

    let originalStartMillis: Int64
    let originalEndMillis: Int64

    let newStartMillis: Int64?
    let newEndMillis: Int64?

    let reason: String

    let changedByUid: String
    let changedByName: String

    let isActive: Bool

    let createdAt: Timestamp?
    let updatedAt: Timestamp?

    let notificationRequested: Bool
    let notificationStatus: String

    var id: String {
        documentId
    }

    var isCancelled: Bool {
        isActive
        && type == .cancelled
    }

    var hasChangedTime: Bool {
        guard isActive,
              type == .timeChanged,
              let newStartMillis,
              let newEndMillis else {
            return false
        }

        return newEndMillis
            > newStartMillis
    }

    /*
     * זמן ההתחלה שבו יש להשתמש בפועל.
     */
    var effectiveStartMillis: Int64 {
        if hasChangedTime {
            return newStartMillis
                ?? originalStartMillis
        }

        return originalStartMillis
    }

    /*
     * זמן הסיום שבו יש להשתמש בפועל.
     */
    var effectiveEndMillis: Int64 {
        if hasChangedTime {
            return newEndMillis
                ?? originalEndMillis
        }

        return originalEndMillis
    }

    var effectiveStartDate: Date {
        Date(
            timeIntervalSince1970:
                Double(effectiveStartMillis)
                / 1000
        )
    }

    var effectiveEndDate: Date {
        Date(
            timeIntervalSince1970:
                Double(effectiveEndMillis)
                / 1000
        )
    }

    var originalStartDate: Date {
        Date(
            timeIntervalSince1970:
                Double(originalStartMillis)
                / 1000
        )
    }

    var originalEndDate: Date {
        Date(
            timeIntervalSince1970:
                Double(originalEndMillis)
                / 1000
        )
    }

    /*
     * תאריך השינוי האחרון.
     *
     * אם updatedAt אינו קיים משתמשים
     * בתאריך היצירה.
     */
    var lastChangedAt: Date? {
        updatedAt?.dateValue()
        ?? createdAt?.dateValue()
    }
}

/*
 * ידית שמרכזת מספר מאזיני Firestore.
 *
 * במסך הבית עשוי להיות מאזין נפרד לכל
 * מופע אימון, אך כל המאזינים נסגרים יחד.
 */
final class TrainingOverrideListenerHandle {

    private var registrations:
        [ListenerRegistration]

    private let lock =
        NSLock()

    init(
        registrations:
            [ListenerRegistration]
    ) {
        self.registrations =
            registrations
    }

    func remove() {
        lock.lock()

        let registrationsToRemove =
            registrations

        registrations.removeAll()

        lock.unlock()

        registrationsToRemove.forEach {
            registration in

            registration.remove()
        }
    }

    deinit {
        remove()
    }
}
