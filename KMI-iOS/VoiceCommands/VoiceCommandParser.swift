import Foundation

// MARK: - VoiceCommandParser

enum VoiceCommandParser {

    static func parse(
        _ rawText: String
    ) -> VoiceAppCommand {
        let originalText =
            rawText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let normalizedText =
            normalize(originalText)

        guard !normalizedText.isEmpty else {
            return .unknown(
                originalText: originalText
            )
        }

        if let explanationQuery =
            extractValue(
                from: normalizedText,
                prefixes: [
                    "הסבר על",
                    "תן הסבר על",
                    "תסביר על",
                    "תסביר לי על",
                    "פתח הסבר על",
                    "אני רוצה הסבר על",
                    "explain",
                    "explain exercise",
                    "explain the exercise",
                    "give explanation for",
                    "open explanation for"
                ]
            ) {
            return .explainExercise(
                query: explanationQuery
            )
        }

        if let findQuery =
            extractValue(
                from: normalizedText,
                prefixes: [
                    "מצא ופתח",
                    "חפש ופתח",
                    "תמצא ותפתח",
                    "פתח את התרגיל",
                    "פתח תרגיל",
                    "find and open",
                    "search and open",
                    "open exercise",
                    "open the exercise"
                ]
            ) {
            return .findAndOpen(
                query: findQuery
            )
        }

        if let beltQuery =
            extractValue(
                from: normalizedText,
                prefixes: [
                    "פתח חגורה",
                    "תפתח חגורה",
                    "עבור לחגורה",
                    "עבור אל חגורה",
                    "הצג חגורה",
                    "open belt",
                    "open the belt",
                    "go to belt",
                    "show belt"
                ]
            ) {
            return .openBelt(
                beltQuery: beltQuery
            )
        }

        if let topicQuery =
            extractValue(
                from: normalizedText,
                prefixes: [
                    "פתח נושא",
                    "תפתח נושא",
                    "עבור לנושא",
                    "עבור אל נושא",
                    "הצג נושא",
                    "open topic",
                    "open the topic",
                    "go to topic",
                    "show topic"
                ]
            ) {
            return .openTopic(
                topicQuery: topicQuery
            )
        }

        if let searchQuery =
            extractValue(
                from: normalizedText,
                prefixes: [
                    "חפש",
                    "תחפש",
                    "חיפוש של",
                    "חיפוש עבור",
                    "מצא",
                    "search for",
                    "search",
                    "find"
                ]
            ) {
            return .search(
                query: searchQuery
            )
        }

        if let drawerDestination =
            resolveDrawerDestination(
                normalizedText
            ) {
            return .openDrawerItem(
                destination: drawerDestination
            )
        }

        if containsAny(
            normalizedText,
            [
                "פתח את מסך הבית",
                "פתח מסך הבית",
                "עבור למסך הבית",
                "עבור לבית",
                "חזור לבית",
                "מסך הבית",
                "open home",
                "open home screen",
                "go home",
                "go to home",
                "home screen"
            ]
        ) {
            return .openHome
        }

        if containsAny(
            normalizedText,
            [
                "פתח הגדרות",
                "פתח את ההגדרות",
                "עבור להגדרות",
                "מסך הגדרות",
                "open settings",
                "go to settings",
                "settings screen"
            ]
        ) {
            return .openSettings
        }

        if containsAny(
            normalizedText,
            [
                "פתח התקדמות",
                "פתח מד התקדמות",
                "פתח סטטיסטיקה",
                "פתח סטטיסטיקות",
                "עבור להתקדמות",
                "עבור לסטטיסטיקה",
                "open progress",
                "open statistics",
                "open stats",
                "go to progress",
                "progress screen",
                "statistics screen"
            ]
        ) {
            return .openProgress
        }

        if containsAny(
            normalizedText,
            [
                "פתח אימונים",
                "פתח את האימונים",
                "עבור לאימונים",
                "מסך אימונים",
                "לוח אימונים",
                "open trainings",
                "open training",
                "go to trainings",
                "training screen",
                "trainings screen"
            ]
        ) {
            return .openTrainings
        }

        if containsAny(
            normalizedText,
            [
                "פתח נושאים",
                "פתח את הנושאים",
                "עבור לנושאים",
                "תרגילים לפי נושא",
                "open topics",
                "go to topics",
                "topics screen",
                "exercises by topic"
            ]
        ) {
            return .openTopics
        }

        if containsAny(
            normalizedText,
            [
                "פתח חגורות",
                "פתח את החגורות",
                "עבור לחגורות",
                "תרגילים לפי חגורה",
                "open belts",
                "go to belts",
                "belts screen",
                "exercises by belt"
            ]
        ) {
            return .openBelts
        }

        if containsAny(
            normalizedText,
            [
                "פתח חיפוש",
                "פתח את החיפוש",
                "עבור לחיפוש",
                "מסך חיפוש",
                "open search",
                "open the search",
                "go to search",
                "search screen"
            ]
        ) {
            return .openSearch
        }

        if containsAny(
            normalizedText,
            [
                "חזור אחורה",
                "חזרה",
                "מסך קודם",
                "חזור למסך הקודם",
                "לך אחורה",
                "go back",
                "back",
                "previous screen",
                "return to previous screen"
            ]
        ) {
            return .goBack
        }

        if let beltName =
            resolveStandaloneBelt(
                normalizedText
            ) {
            return .openBelt(
                beltQuery: beltName
            )
        }

        return .unknown(
            originalText: originalText
        )
    }
}

// MARK: - Drawer destinations

private extension VoiceCommandParser {

    static func resolveDrawerDestination(
        _ text: String
    ) -> VoiceDrawerDestination? {
        if containsAny(
            text,
            [
                "הפרופיל שלי",
                "פתח פרופיל",
                "פתח את הפרופיל",
                "פתח את הפרופיל שלי",
                "my profile",
                "open profile",
                "open my profile"
            ]
        ) {
            return .myProfile
        }

        if containsAny(
            text,
            [
                "עדכון נוכחות",
                "דוח נוכחות",
                "רישום נוכחות",
                "פתח נוכחות",
                "פתח עדכון נוכחות",
                "mark attendance",
                "attendance report",
                "open attendance"
            ]
        ) {
            return .coachAttendance
        }

        if containsAny(
            text,
            [
                "שליחת הודעה",
                "שלח הודעה",
                "שידור מאמן",
                "הודעה למתאמנים",
                "פתח שליחת הודעה",
                "send message",
                "coach broadcast",
                "message trainees"
            ]
        ) {
            return .coachBroadcast
        }

        if containsAny(
            text,
            [
                "רשימת מתאמנים",
                "המתאמנים שלי",
                "פתח רשימת מתאמנים",
                "פתח מתאמנים",
                "מסך המתאמנים",
                "trainees list",
                "my trainees",
                "open trainees",
                "trainees screen"
            ]
        ) {
            return .coachTrainees
        }

        if containsAny(
            text,
            [
                "דוח תשלומים",
                "דוח התשלומים",
                "פתח דוח תשלומים",
                "תשלומי מתאמנים",
                "payments report",
                "open payments report",
                "trainee payments"
            ]
        ) {
            return .coachPaymentsReport
        }

        if containsAny(
            text,
            [
                "מבחן פנימי",
                "מבחן פנימי לחגורה",
                "פתח מבחן פנימי",
                "מבחן חגורה",
                "internal exam",
                "internal belt exam",
                "open internal exam"
            ]
        ) {
            return .coachInternalExam
        }

        if containsAny(
            text,
            [
                "אודות אבי",
                "אבי אביסידון",
                "פתח אודות אבי",
                "about avi",
                "about avi abisidon"
            ]
        ) {
            return .aboutAvi
        }

        if containsAny(
            text,
            [
                "אודות המאמנים",
                "מאמני הרשת",
                "המאמנים ברשת",
                "network coaches",
                "about the coaches"
            ]
        ) {
            return .networkCoaches
        }

        if containsAny(
            text,
            [
                "אודות השיטה",
                "פתח אודות השיטה",
                "about the method",
                "open about the method"
            ]
        ) {
            return .aboutMethod
        }

        if containsAny(
            text,
            [
                "תרגילי הדגמה",
                "סרטוני הדגמה",
                "פתח הדגמות",
                "exercises demo",
                "demo exercises",
                "demo videos"
            ]
        ) {
            return .exercisesDemo
        }

        if containsAny(
            text,
            [
                "טפסים ותשלומים",
                "פתח טפסים",
                "טופס רישום",
                "forms and payments",
                "open forms",
                "registration form"
            ]
        ) {
            return .formsAndPayments
        }

        if containsAny(
            text,
            [
                "צור קשר",
                "יצירת קשר",
                "פתח צור קשר",
                "contact us",
                "open contact"
            ]
        ) {
            return .contactUs
        }

        if containsAny(
            text,
            [
                "פורום הסניף",
                "פתח פורום",
                "פתח את הפורום",
                "branch forum",
                "open forum"
            ]
        ) {
            return .branchForum
        }

        if containsAny(
            text,
            [
                "החלף שפה",
                "שנה שפה",
                "בחירת שפה",
                "change language",
                "switch language",
                "language settings"
            ]
        ) {
            return .language
        }

        if containsAny(
            text,
            [
                "ניהול מנוי",
                "פתח מנוי",
                "פתח ניהול מנוי",
                "manage subscription",
                "open subscription"
            ]
        ) {
            return .manageSubscription
        }

        if containsAny(
            text,
            [
                "דרג את האפליקציה",
                "דירוג האפליקציה",
                "פתח דירוג",
                "rate the app",
                "rate app",
                "open rating"
            ]
        ) {
            return .rateUs
        }

        if containsAny(
            text,
            [
                "התנתק",
                "התנתקות",
                "צא מהחשבון",
                "logout",
                "log out",
                "sign out"
            ]
        ) {
            return .logout
        }

        return nil
    }
}

// MARK: - Belt recognition

private extension VoiceCommandParser {

    static func resolveStandaloneBelt(
        _ text: String
    ) -> String? {
        let belts: [(String, [String])] = [
            (
                "white",
                [
                    "חגורה לבנה",
                    "חגורה לבן",
                    "לבנה",
                    "לבן",
                    "white belt",
                    "white"
                ]
            ),
            (
                "yellow",
                [
                    "חגורה צהובה",
                    "חגורה צהוב",
                    "צהובה",
                    "צהוב",
                    "yellow belt",
                    "yellow"
                ]
            ),
            (
                "orange",
                [
                    "חגורה כתומה",
                    "חגורה כתום",
                    "כתומה",
                    "כתום",
                    "orange belt",
                    "orange"
                ]
            ),
            (
                "green",
                [
                    "חגורה ירוקה",
                    "חגורה ירוק",
                    "ירוקה",
                    "ירוק",
                    "green belt",
                    "green"
                ]
            ),
            (
                "blue",
                [
                    "חגורה כחולה",
                    "חגורה כחול",
                    "כחולה",
                    "כחול",
                    "blue belt",
                    "blue"
                ]
            ),
            (
                "brown",
                [
                    "חגורה חומה",
                    "חגורה חום",
                    "חומה",
                    "חום",
                    "brown belt",
                    "brown"
                ]
            ),
            (
                "black",
                [
                    "חגורה שחורה",
                    "חגורה שחור",
                    "שחורה",
                    "שחור",
                    "black belt",
                    "black"
                ]
            )
        ]

        for (belt, aliases) in belts {
            if containsAny(text, aliases) {
                return belt
            }
        }

        return nil
    }
}

// MARK: - Text helpers

private extension VoiceCommandParser {

    static func extractValue(
        from text: String,
        prefixes: [String]
    ) -> String? {
        let orderedPrefixes =
            prefixes
                .map(normalize)
                .filter { !$0.isEmpty }
                .sorted {
                    $0.count > $1.count
                }

        for prefix in orderedPrefixes {
            guard text == prefix ||
                    text.hasPrefix(prefix + " ") else {
                continue
            }

            let value =
                String(
                    text.dropFirst(
                        prefix.count
                    )
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            guard !value.isEmpty else {
                continue
            }

            return value
        }

        return nil
    }

    static func containsAny(
        _ text: String,
        _ variants: [String]
    ) -> Bool {
        variants.contains { variant in
            text.contains(normalize(variant))
        }
    }

    static func normalize(
        _ source: String
    ) -> String {
        source
            .replacingOccurrences(
                of: "\u{200E}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{200F}",
                with: ""
            )
            .replacingOccurrences(
                of: "\u{00A0}",
                with: " "
            )
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: Locale(identifier: "he_IL")
            )
            .lowercased()
            .replacingOccurrences(
                of: #"[\u{0591}-\u{05C7}]"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"[.,!?;:()\[\]{}"'״׳]"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }
}
