import Foundation

enum ExerciseTitlesEnAliases {

    static let map: [String: String] = [

        // ---------------------------------------------------------
        // Breakfalls / rolls - old names and spacing variants
        // ---------------------------------------------------------

        "בלימה לצד ימין": "Breakfall to the Right",
        "בלימה לצד שמאל": "Breakfall to the Left",

        "בלימה לצד - ימין/שמאל": "Side Breakfall - Right/Left",
        "בלימה לצד – ימין/שמאל": "Side Breakfall - Right/Left",
        "בלימה לצד ימין/שמאל": "Side Breakfall - Right/Left",
        "בלימה לצד שמאל/ימין": "Side Breakfall - Right/Left",

        "גלגול לפנים שמאל": "Forward Roll - Left",
        "גלגול לפנים - שמאל": "Forward Roll - Left",
        "גלגול לפנים – שמאל": "Forward Roll - Left",
        "גלגול לפנים צד שמאל": "Forward Roll - Left Side",

        "גלגול לאחור": "Backward Roll",
        "גלגול לאחור - ימין/שמאל": "Backward Roll - Right/Left",
        "גלגול לאחור – ימין/שמאל": "Backward Roll - Right/Left",
        "גלגול לאחור - שמאל/ימין": "Backward Roll - Right/Left",
        "גלגול לאחור – שמאל/ימין": "Backward Roll - Right/Left",
        "גלגול לאחור צד ימין": "Backward Roll - Right Side",
        "גלגול לאחור צד שמאל": "Backward Roll - Left Side",

        // ---------------------------------------------------------
        // Combination aliases
        // ---------------------------------------------------------

        "שילובי ידיים רגליים": "Hand and Leg Combinations",
        "שילובי ידיים ורגליים": "Hand and Leg Combinations",

        // ---------------------------------------------------------
        // Hand strikes aliases
        // ---------------------------------------------------------

        "מכת פטיש יד שמאל": "Left Hammerfist Strike",

        // ---------------------------------------------------------
        // Ground releases - צואר / צוואר variants
        // ---------------------------------------------------------

        "שחרור מחביקת צואר מהצד בשכיבה": "Release from Side Neck Hold on the Ground",
        "שחרור מחביקת צוואר מהצד בשכיבה": "Release from Side Neck Hold on the Ground",

        "שחרור מחביקת צואר ויד מהצד בשכיבה": "Release from Side Neck-and-Arm Hold on the Ground",
        "שחרור מחביקת צוואר ויד מהצד בשכיבה": "Release from Side Neck-and-Arm Hold on the Ground",

        // ---------------------------------------------------------
        // Ground defenses aliases
        // ---------------------------------------------------------

        "הגנה נגד אגרופים על הקרקע": "Defense Against Punches on the Ground",
        "הגנה נגד אגרופים בשכיבה": "Defense Against Punches on the Ground",

        // ---------------------------------------------------------
        // Android compatibility aliases
        // These names appear in the Android ContentRepo / HardSectionsCatalog
        // ---------------------------------------------------------

        "גלגול לפנים – צד ימין": "Forward Roll (Right)",
        "גלגול לפנים - צד ימין": "Forward Roll (Right)",

        "הוצאות אגן, הרמת אגן והפניית גוף למעלה": "Hip Escape, Bridge and Turn Upward",
        "הרמת אגן והפניית גוף לכיוון ההפלה": "Bridge and Turn Toward the Takedown",

        "מכת קשת האצבע והאגודל": "Thumb and Index Arc Strike",
        "מכת קשת האצבע והאגודל לקנה הנשימה": "Thumb and Index Arc Strike to the Trachea",

        "עמידת מוצא כללית מספר 1": "General Stance No. 1",
        "עמידת מוצא כללית מספר 2": "General Stance No. 2",

        "גלגול לאחור - ימין": "Backward Roll - Right",
        "גלגול לאחור – ימין": "Backward Roll - Right",
        "גלגול לאחור - שמאל": "Backward Roll - Left",
        "גלגול לאחור – שמאל": "Backward Roll - Left",
        "גלגול לאחור שמאל": "Backward Roll - Left",

        "קוואלר נגד התנגדות - הליכה לפנים": "Cavalier with Resistance - Walking Forward",
        "קוואלר נגד התנגדות – הליכה לפנים": "Cavalier with Resistance - Walking Forward",
        "קוואלר – מרפק": "Cavalier with an Elbow",

        "בעיטת לצד בסיבוב מלא בניתור": "Leaping Side-Kick with Spin",

        "הגנה נגד בעיטת מגל לפנים – בעיטה לצד": "Defense Against a Front Magal Kick with a Side Kick",
        "הגנה נגד בעיטת מגל לאחור - בעיטה שמאל": "Defense Against a Backward Magal Kick - Left Kick",
        "הגנה נגד בעיטת מגל לאחור בסיבוב – בעיטה": "Defense Against a Backward Magal Kick with Spin - Kick",

        "מניעת נפילה מחביקת שוקיים מלפנים להפלה": "Preventing a Double-Leg Takedown from the Front",
        "מניעת נפילה ממרחק שקיים מלפנים להפלה": "Preventing a Double-Leg Takedown from the Front",

        "גלגול לצד — ימין": "Roll to the Side - Right",
        "גלגול לצד — שמאל": "Roll to the Side - Left",
        "גלגול ברחיפה — ימין": "Hover Roll - Right",
        "גלגול ברחיפה — שמאל": "Hover Roll - Left",
        "גלגול לגובה — ימין": "High Roll - Right",
        "גלגול לגובה — שמאל": "High Roll - Left",
        "גלגול ללא ידיים — ימין": "Forward Roll without Hands - Right",
        "גלגול ללא ידיים — שמאל": "Forward Roll without Hands - Left"
    ]

    static func title(for value: String) -> String {
        map[value] ?? value
    }
}
