import Foundation

enum ExerciseTitlesEnTopics {

    static let map: [String: String] = [

        // ---------------------------------------------------------
        // Main topics
        // ---------------------------------------------------------

        "כללי": "General",
        "עמידת מוצא": "Ready Stance",
        "עבודת ידיים": "Hand Techniques",
        "מניעת התקרבות התוקף": "Preventing the Attacker's Approach",
        "שחרורים": "Releases",
        "הכנה לעבודת קרקע": "Groundwork Preparation",
        "בעיטות": "Kicks",
        "הגנות": "Defenses",
        "בלימות וגלגולים": "Breakfalls and Rolls",
        "קוואלר": "Cavalier",
        "מכות מרפק": "Elbow Strikes",
        "מכות במקל / רובה": "Stick / Rifle Strikes",
        "בעיטות בניתור": "Jump Kicks",
        "מכות במקל קצר": "Short Stick Strikes",
        "גלגולים": "Rolls",

        // ---------------------------------------------------------
        // Hand techniques sub-topics
        // ---------------------------------------------------------

        "מרפק": "Elbow",
        "יד פיסת": "Palm Heel",
        "אגרופים ישרים": "Straight Punches",
        "מגל + סנוקרת": "Hooks + Uppercuts",
        "עבודת ידיים - מגל + סנוקרת": "Hand Techniques - Hooks + Uppercuts",

        // ---------------------------------------------------------
        // Releases sub-topics
        // ---------------------------------------------------------

        "שחרורים מתפיסות ידיים": "Releases from Hand Grabs",
        "שחרור מתפיסות ידיים": "Releases from Hand Grabs",
        "שחרורים מחניקות": "Releases from Chokes",
        "שחרורים מתפיסות חולצה": "Releases from Shirt Grabs",
        "שחרורים מתפיסות שיער": "Releases from Hair Grabs",
        "שחרורים מתפיסות צוואר וגוף": "Releases from Neck and Body Holds",
        "שחרורים מתפיסות צואר וגוף": "Releases from Neck and Body Holds",
        "שחרור מתפיסות": "Releases from Grabs",
        "שחרור מחביקות": "Releases from Bear Hugs",
        "שחרורים מחביקות צוואר": "Releases from Neck Holds",
        "שחרורים מחביקות צואר": "Releases from Neck Holds",
        "שחרורים מתפיסות נלסון": "Releases from Nelson Holds",
        "שחרורים מחביקות גוף": "Releases from Body Bear Hugs",

        // ---------------------------------------------------------
        // Defenses sub-topics
        // ---------------------------------------------------------

        "הגנות נגד מכות ישרות": "Defenses Against Straight Punches",
        "הגנות חיצוניות נגד מכות": "External Defenses Against Hand Strikes",
        "הגנות פנימיות נגד מכות": "Internal Defenses Against Hand Strikes",
        "6 הגנות חיצוניות נגד מכות": "6 Outside Defenses Against Strikes",
        "הגנות חיצוניות נגד מכות מהצד": "Outside Defenses Against Side Strikes",
        "הגנות נגד אגרוף שמאל-ימין": "Defenses Against Left and Right Punches",
        "הגנות נגד מכות אגרוף": "Defenses Against Punches",
        "הגנות גוף": "Body Defenses",

        "הגנות נגד בעיטות": "Defenses Against Kicks",
        "הגנה נגד בעיטות": "Defenses Against Kicks",
        "הגנות נגד ברכיות": "Defenses Against Knee Strikes",
        "הגנות נגד בעיטות ברך": "Defenses Against Knee Strikes",
        "הגנות נגד בעיטות רגילות": "Defenses Against Regular Kicks",
        "הגנות נגד בעיטות מגל לפנים": "Defenses Against Front Magal Kicks",
        "הגנות נגד בעיטות לצד": "Defenses Against Side Kicks",

        "הגנות נגד סכין": "Defenses Against Knife Attacks",
        "הגנות מאיום סכין": "Defenses Against Knife Threats",
        "הגנות נגד מקל": "Defenses Against Stick Attacks",
        "הגנות מאיום אקדח": "Defenses Against Gun Threats",
        "הגנות - מספר תוקפים": "Defenses - Multiple Attackers",
        "הגנות נגד מכות בשילוב בעיטות": "Defenses Against Punches Combined with Kicks",
        "הגנות – מקל נגד סכין": "Stick Defenses Against Knife",
        "הגנות - מקל נגד סכין": "Stick Defenses Against Knife",
        "הגנה עם רובה נגד סכין": "Rifle Defense Against Knife",
        "הגנה מאיום תמ\"ק": "Defense Against SMG Threat",

        // ---------------------------------------------------------
        // Short technical section names
        // ---------------------------------------------------------

        "הגנה – בעיטה": "Defense - Kicks",
        "הגנה - בעיטה": "Defense - Kicks",
        "הגנה – סכין": "Defense - Knife",
        "הגנה - סכין": "Defense - Knife",
        "הגנה – מקל": "Defense - Stick",
        "הגנה - מקל": "Defense - Stick",
        "הגנה – איום אקדח": "Defense - Gun Threat",
        "הגנה - איום אקדח": "Defense - Gun Threat",

        // ---------------------------------------------------------
        // Internal app ids / route ids
        // ---------------------------------------------------------

        "general": "General",
        "ready_stance": "Ready Stance",
        "hands_strikes": "Hand Techniques",
        "hand_techniques": "Hand Techniques",
        "releases": "Releases",
        "groundwork_preparation": "Groundwork Preparation",
        "kicks": "Kicks",
        "defenses": "Defenses",
        "defences": "Defenses",
        "topic_breakfalls_rolls": "Breakfalls and Rolls",
        "breakfalls_rolls": "Breakfalls and Rolls",
        "cavalier": "Cavalier",
        "elbow_strikes": "Elbow Strikes",
        "stick_rifle_strikes": "Stick / Rifle Strikes",
        "jump_kicks": "Jump Kicks",
        "short_stick_strikes": "Short Stick Strikes",
        "rolls": "Rolls",

        "def_internal_punch": "Internal Defenses Against Hand Strikes",
        "def_external_punch": "External Defenses Against Hand Strikes",
        "def_external_strikes": "External Defenses Against Hand Strikes",
        "def_straight_punches": "Defenses Against Straight Punches",
        "def_left_right_punches": "Defenses Against Left and Right Punches",
        "def_knee": "Defenses Against Knee Strikes",
        "def_internal_kick": "Defenses Against Kicks",
        "def_external_kick": "Defenses Against Kicks",
        "def_regular_kick": "Defenses Against Regular Kicks",
        "def_magal_kick": "Defenses Against Front Magal Kicks",
        "def_side_kick": "Defenses Against Side Kicks",

        "knife_defense": "Defenses Against Knife Attacks",
        "knife_threat_defense": "Defenses Against Knife Threats",
        "stick_defense": "Defenses Against Stick Attacks",
        "gun_threat_defense": "Defenses Against Gun Threats",
        "rifle_knife_defense": "Rifle Defense Against Knife",
        "stick_knife_defense": "Stick Defenses Against Knife",
        "smg_threat_defense": "Defense Against SMG Threat",
        "multiple_attackers_defense": "Defenses - Multiple Attackers",

        // ---------------------------------------------------------
        // Android compatibility topic aliases
        // ---------------------------------------------------------

        "מכות יד": "Hand Strikes",
        "מכות ידיים": "Hand Strikes",
        "פיסת יד": "Palm Heel",
        "הגנות נגד בעיטות ישרות / למפשעה": "Defenses Against Straight / Groin Kicks",
        "הגנות נגד מגל / מגל לאחור": "Defenses Against Magal / Backward Magal Kicks",
        "הגנות נגד ברך": "Defenses Against Knee Strikes",
        "שחרור מחניקות": "Releases from Chokes",
        "שחרור מתפיסות ידיים / שיער / חולצה": "Releases from Hand / Hair / Shirt Grabs",
        "שחרורים מתפיסות ידיים / שיער / חולצה": "Releases from Hand / Hair / Shirt Grabs",
        "הגנות מסכין": "Knife Defenses",
        "הגנות עם רובה נגד דקירות סכין": "Rifle Defense Against Knife Stabs",
        "הגנות נגד מספר תוקפים": "Defenses Against Multiple Attackers",

        "topic_ready_stance": "Ready Stance",
        "topic_ground_prep": "Groundwork Preparation",
        "topic_kavaler": "Cavalier",
        "topic_Kavaler": "Cavalier",
        "releases_hands_hair_shirt": "Releases from Hand / Hair / Shirt Grabs",
        "releases_chokes": "Choke Releases",
        "releases_hugs": "Bear Hug Releases",
        "knife_rifle_defense": "Rifle Defense Against Knife Stabs",
        "defense_rifle_knife": "Rifle Defense Against Knife Stabs",
        "defense_attackers_multiple": "Defenses Against Multiple Attackers",
        "hard_kicks": "Kick Defenses"
    ]

    static func title(for value: String) -> String {
        map[value] ?? value
    }
}
