import Foundation

// MARK: - VoiceDrawerDestination

/// יעדים שניתן לפתוח מתוך התפריט הראשי באמצעות פקודה קולית.
///
/// הפעולה עצמה תתבצע בהמשך דרך אותם יעדי ניווט
/// שבהם משתמשים ContentView ו-AppRoute.
enum VoiceDrawerDestination: String, CaseIterable, Hashable {

    case myProfile

    case coachAttendance
    case coachBroadcast
    case coachTrainees
    case coachPaymentsReport
    case coachInternalExam

    case aboutAvi
    case networkCoaches
    case aboutMethod
    case exercisesDemo
    case formsAndPayments
    case contactUs
    case branchForum
    case language
    case manageSubscription
    case rateUs
    case logout
}

// MARK: - VoiceAppCommand

/// פקודות קוליות להפעלת האפליקציה.
///
/// מנגנון זה נפרד לחלוטין מהעוזר הקולי.
/// הוא מפעיל ניווט ופעולות במקום לחיצה על כפתורים.
enum VoiceAppCommand: Equatable {

    /// פתיחת מסך הבית.
    case openHome

    /// פתיחת מסך ההגדרות.
    case openSettings

    /// פתיחת מסך ההתקדמות והסטטיסטיקה.
    case openProgress

    /// פתיחת מסך האימונים.
    case openTrainings

    /// פתיחת מסך הנושאים.
    case openTopics

    /// פתיחת מסך החגורות.
    case openBelts

    /// פתיחת חגורה לפי טקסט שאמר המשתמש.
    case openBelt(
        beltQuery: String
    )

    /// פתיחת נושא לפי טקסט שאמר המשתמש.
    case openTopic(
        topicQuery: String
    )

    /// פתיחת החיפוש הגלובלי.
    case openSearch

    /// חזרה למסך הקודם.
    case goBack

    /// פתיחת יעד מתוך התפריט הראשי.
    case openDrawerItem(
        destination: VoiceDrawerDestination
    )

    /// חיפוש תרגיל ופתיחת התוצאה.
    case findAndOpen(
        query: String
    )

    /// פתיחת הסבר לתרגיל.
    case explainExercise(
        query: String
    )

    /// ביצוע חיפוש בלי פתיחה אוטומטית.
    case search(
        query: String
    )

    /// פקודה שלא זוהתה.
    case unknown(
        originalText: String
    )
}

// MARK: - Convenience

extension VoiceAppCommand {

    /// האם הפקודה דורשת טקסט נלווה.
    var hasQuery: Bool {
        switch self {
        case .openBelt,
             .openTopic,
             .findAndOpen,
             .explainExercise,
             .search,
             .unknown:
            return true

        case .openHome,
             .openSettings,
             .openProgress,
             .openTrainings,
             .openTopics,
             .openBelts,
             .openSearch,
             .goBack,
             .openDrawerItem:
            return false
        }
    }

    /// הטקסט הנלווה לפקודה, כאשר קיים.
    var query: String? {
        switch self {
        case .openBelt(let beltQuery):
            return beltQuery

        case .openTopic(let topicQuery):
            return topicQuery

        case .findAndOpen(let query):
            return query

        case .explainExercise(let query):
            return query

        case .search(let query):
            return query

        case .unknown(let originalText):
            return originalText

        case .openHome,
             .openSettings,
             .openProgress,
             .openTrainings,
             .openTopics,
             .openBelts,
             .openSearch,
             .goBack,
             .openDrawerItem:
            return nil
        }
    }
}
