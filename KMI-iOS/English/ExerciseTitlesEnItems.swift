import Foundation

enum ExerciseTitlesEnItems {

    static let map: [String: String] = [

        // ---------------------------------------------------------
        // Yellow belt
        // ---------------------------------------------------------
        "בלימה רכה לפנים": "Soft Front Breakfall",
        "בלימה לאחור": "Backward Breakfall",
        "תזוזות": "Movement Drills",
        "גלגול לפנים - ימין": "Forward Roll (Right)",
        "הוצאת אגן": "Hip Escape",
        "הרמת אגן והפניית גוף לכיון ההפלה": "Bridge and Turn Toward the Takedown",
        "מוצא לעבודת קרקע": "Groundwork Starting Position",
        "צל בוקס": "Shadow Boxing",
        "סגירת אגרוף": "Fist Closing",
        "אצבעות לפנים": "Fingers Forward",
        "מכת קשת האגודל והאצבע לקנה הנשימה": "Thumb and Index Arc Strike to the Trachea",
        "מכת קשת האגודל והאצבע": "Thumb and Index Arc Strike",

        "עמידת מוצא רגילה": "Regular Stance",
        "עמידת מוצא להגנות פנימיות": "Internal Defence Stance",
        "עמידת מוצא להגנות חיצוניות": "External Defence Stance",
        "עמידת מוצא צידית": "Side Stance",
        "עמידת מוצא כללית מס' 1": "General Stance No. 1",
        "עמידת מוצא כללית מס' 2": "General Stance No. 2",

        "מכת מרפק אופקית לאחור": "Horizontal Elbow Strike Backward",
        "מכת מרפק אופקית לצד": "Horizontal Elbow Strike to the Side",
        "מכת מרפק אופקית לפנים": "Horizontal Elbow Strike Forward",
        "מכת מרפק לאחור": "Backward Elbow Strike",
        "מכת מרפק לאחור למעלה": "Backward Upward Elbow Strike",
        "מכת מרפק אנכי למטה": "Vertical Downward Elbow Strike",
        "מכת מרפק אנכי למעלה": "Vertical Upward Elbow Strike",

        "מכת פיסת יד שמאל לפנים": "Forward Left Palm Heel Strike",
        "מכת פיסת יד ימין לפנים": "Forward Right Palm Heel Strike",
        "מכת פיסת יד שמאל-ימין לפנים": "Forward Left-Right Palm Heel Strike",
        "מכת פיסת יד שמאל-ימין-שמאל לפנים": "Forward Left-Right-Left Palm Heel Strike",
        "מכת פיסת יד מהצד": "Side Palm Heel Strike",

        "אגרוף שמאל לפנים": "Forward Left Punch",
        "אגרוף ימין לפנים": "Forward Right Punch",
        "אגרוף שמאל-ימין לפנים": "Forward Left-Right Punches",
        "אגרוף שמאל בהתקדמות": "Left Punch While Advancing",
        "אגרוף ימין בהתקדמות": "Right Punch While Advancing",
        "אגרוף שמאל-ימין בהתקדמות": "Left-Right Punch While Advancing",
        "אגרוף שמאל-ימין ושמאל בהתקדמות": "Left-Right-Left Punch While Advancing",
        "אגרוף שמאל בנסיגה": "Left Punch While Retreating",
        "אגרוף שמאל למטה בהתקפה": "Left Low Punch in Attack",
        "אגרוף ימין למטה בהתקפה": "Right Low Punch in Attack",
        "אגרוף שמאל למטה בהגנה": "Left Low Punch in Defense",
        "אגרוף ימין למטה בהגנה": "Right Low Punch in Defense",

        "מכת מגל שמאל": "Magal (Circular) Left Punch",
        "מכת מגל ימין": "Magal (Circular) Right Punch",
        "מכת מגל למטה ולמעלה בהתחלפות": "Alternating Low and High Hook Punches",
        "מכת סנוקרת שמאל": "Left Uppercut",
        "מכת סנוקרת ימין": "Right Uppercut",

        "שחרור מתפיסת יד מול יד": "Release from Same-Side Wrist Grab",
        "שחרור מתפיסת יד נגדית": "Release from Cross Wrist Grab",
        "שחרור מתפיסת שתי ידיים למטה": "Release from Two Hands Grabbing Both Hands - Low",
        "שחרור מתפיסת שתי ידיים למעלה": "Release from Two Hands Grabbing Both Hands - High",

        "מניעת התקרבות תוקף": "Preventing attacker's forward motion",
        "מניעת חניקה": "Choke Prevention",
        "שחרור מחניקה מלפנים בכף היד": "Release from Choke from the Front",
        "שחרור מחניקה מאחור במשיכה": "Release from Rear Choke by Pull",
        "שחרור מחביקת צואר מהצד": "Release from Neck Hold from the Side",

        "בעיטה רגילה למפסעה": "Regular Kick to the Groin",
        "בעיטה רגילה לסנטר": "Regular Kick to the Chin",
        "בעיטת מגל נמוכה": "Low Magal (Circular) kick",
        "בעיטת מגל אופקית": "Horizontal Magal (Circular) kick",
        "בעיטת מגל אלכסונית": "Diagonal Magal (Circular) kick",
        "בעיטת מגל בהטעיה": "Magal (Circular) kick with Diversion",
        "בעיטת ברך גבוהה": "High Knee Strike",
        "בעיטת ברך מהצד": "Side Knee Strike",
        "בעיטת ברך נמוכה למפסעה": "Low Knee Strike to the Groin",
        "בעיטה לצד מעמידת פיסוק": "Side Kick From a Neutral Stance",

        "הגנה חיצונית רפלקסיבית 360 מעלות": "Reflexive 360 Degree Defence",
        "הגנה פנימית רפלקסיבית": "Reflexive Internal Defences",
        "הגנה פנימית נגד ימין בכף יד שמאל": "Inside Defense Against Right Punch with Left Palm",
        "הגנה פנימית נגד שמאל בכף יד ימין": "Inside Defense Against Left Punch with Right Palm",
        "הגנה פנימית נגד בעיטה רגילה למפסעה": "Inside Defense Against Regular Kick to the Groin",

        // ---------------------------------------------------------
        // Orange belt
        // ---------------------------------------------------------

        // Hand Strikes
        "מכת גב יד בהצלפה": "Whipping Backfist",
        "מכת גב יד בהצלפה בסיבוב": "Whipping Backfist with Spin",
        "מכת פטיש": "Hammer Punch",
        "מכת פטיש מהצד": "Side Hammer Punch",

        // Kicks
        "בעיטה רגילה בעקב לסנטר": "Regular Kick to the Chin with Your Heel",
        "בעיטת הגנה לפנים": "Defensive Kick Forward",
        "בעיטת סנוקרת לאחור": "Uppercut Kick Backwards",
        "בעיטה לצד בשיכול": "Side-Kick with Advance",
        "בעיטה לצד בנסיגה": "Side-Kick with Retreat",
        "בעיטה רגילה לאחור": "Regular Kick Backwards",
        "בעיטת הגנה לאחור": "Defensive Kick Backwards",
        "בעיטת סטירה פנימית": "internal Slap Kick",

        // Stop Kicks
        "בעיטת עצירה בכף הרגל האחורית": "Stop-Kick with Rear Leg",
        "בעיטת עצירה בכף הרגל הקדמית": "Stop-Kick with Front Leg",

        // Kick combinations
        "בעיטה רגילה ובעיטת מגל ברגל השנייה": "Regular Kick and Magal (Circular) kick",
        "שילובי בעיטות": "Kick Combinations",
        "שילובי אגרופים ובעיטות": "Hand Strikes and Kick Combinations",

        // Jumping kicks
        "ניתור ברגל ימין ובעיטה רגילה ברגל ימין": "Leaping with your Right Foot and Regular Kick with your Right Foot",

        // Breakfalls and Rolls
        "בלימה לצד": "Breakfall to the Side",
        "גלגול לפנים שמאל": "Forward Roll (Left)",
        "גלגול לאחור": "Backward Roll",

        // Body defence
        "הגנות נגד מכות עם הטיות גוף": "Defence Against Punches with Body Movement",

        // External defences
        "הגנה חיצונית מס' 1": "External Defence No. 1",
        "הגנה חיצונית מס' 2": "External Defence No. 2",
        "הגנה חיצונית מס' 3": "External Defence No. 3",
        "הגנה חיצונית מס' 4": "External Defence No. 4",
        "הגנה חיצונית מס' 5": "External Defence No. 5",
        "הגנה חיצונית מס' 6": "External Defence No. 6",

        "הגנה חיצונית נגד אגרופים למטה": "External Defence Against Low Punches",

        // 360 Defences
        "הגנה נגד מכה גבוהה מהצד - התוקף בצד שמאל": "Defence Against a High Strike from the Side with Attacker on Left",
        "הגנה נגד מכה מהצד לעורף - התוקף בצד שמאל": "Defence Against a Strike from the Side to the Back of the Head with Attacker on the Left",
        "הגנה נגד מכה מהצד לגב - התוקף בצד שמאל": "Defence Against a Strike from the Side to the Back with Attacker on the Left",

        "הגנה נגד מכה גבוהה מהצד - התוקף בצד ימין": "Defence Against a High Strike from the Side with Attacker on the Right",
        "הגנה נגד מכה מהצד לגרון - התוקף בצד ימין": "Defence Against a Strike from the Side to the Throat with Attacker on the Right",
        "הגנה נגד מכה מהצד לבטן - התוקף בצד ימין": "Defence Against a Strike from the Side to the Abdominal Area with Attacker on the Right",

        // Internal defences
        "הגנה פנימית נגד שמאל עם המרפק": "Internal Defence Againt a straight Left Punche with the Elbow",
        "הגנה פנימית נגד מכות ישרות למטה": "Internal Defence Againt Low Punches",

        // Left Right punches
        "הגנה נגד שמאל-ימין – אגרוף מהופך": "Defence Against a Left and Right Punch with an Upside-Down Punch",
        "הגנה נגד שמאל-ימין – הטייה לאחור": "Defence Against a Left and Right Punch by Leaning Backwards",
        "הגנה נגד שמאל-ימין (כמו חיצוניות)": "Defence Against Left and Right Punches - External Defences",

        // Knee
        "הגנה נגד בעיטת ברך": "Defence Against Knee Strikes",

        // Kick defences
        "הגנה חיצונית נגד בעיטה רגילה": "External Defence Against a Regular Kick",
        "הגנה נגד בעיטה רגילה - עצירה ברגל הקדמית": "Defence Against a Regular Kick with a Block Kick - Front Leg",
        "הגנה נגד בעיטה רגילה - עצירה ברגל האחורית": "Defence Against a Regular Kick with a Block Kick - Rear Leg",

        // Magal kick defences
        "הגנה חיצונית נגד בעיטת מגל לפנים - בעיטה בימין": "External Defence Against a Magal (Circular) kick with a Right Kick",
        "הגנה חיצונית נגד בעיטת מגל לפנים - בעיטה בשמאל": "External Defence Against a Magal (Circular) kick with a Left Kick",
        "הגנה חיצונית נגד בעיטת מגל לפנים - אגרוף בימין": "External Defence Against a Magal (Circular) kick with a Right Punch",

        "הגנה נגד בעיטת מגל לפנים באמות הידיים": "Defence Against a Magal (Circular) kick with your Forearms",

        "בעיטת עצירה נגד בעיטת מגל - עצירה ברגל האחורית": "Block-Kick Against a Magal (Circular) kick - Rear Leg",
        "בעיטת עצירה נגד בעיטת מגל - עצירה ברגל הקדמית": "Block-Kick Against a Magal (Circular) kick - Front Leg",

        "בעיטת עצירה נגד בעיטה לצד": "Btop-Kick Against a Side-Kick",

        // Releases from hand grabs
        "שחרור מתפיסת יד מול יד - בריח על האגודל": "Release From One Hand Grabbing the Hand in Front of it",
        "שחרור מתפיסת יד נגדית - פרקי אצבעות": "Release from One Hand Grabbing the Opposite Hand",

        "שחרור מתפיסת יד בשתי ידיים למעלה": "Release From Both Hands Grabbing One Hand - High",
        "שחרור מתפיסת יד בשתי ידיים למטה - מרווח": "Release From Both Hands Grabbing One Hand - Low With a Gap",
        "שחרור מתפיסת יד בשתי ידיים למטה - צמוד": "Release From Both Hands Grabbing One Hand - Low Without a Gap",

        "שחרור מתפיסת ידיים צמודה מאחור": "Release From a Close Low Hand Grab From the Behind",

        // Arm grabs
        "שחרור מתפיסת זרוע מהצד במשיכה": "Release From Arm Grab From the Side with a Pull",
        "שחרור מתפיסת זרוע מהצד בדחיפה": "Release From Arm Grab From the Side with a Push",

        // Shirt grabs
        "שחרור חולצה - בריח על האגודל": "Release From Shirt Hold Using Leverage on the Thumb",
        "שחרור חולצה - מכת פרקי אצבעות": "Release From Shirt Hold Using a Knuckle Strike",
        "שחרור חולצה - שתי ידיים": "Release From Shirt Hold with Both Hands",

        // Hair grabs
        "שחרור מתפיסת שיער מלפנים": "Release From a Front Hair Pull with One Hand",
        "שחרור מתפיסת שיער מלפנים בשתי ידיים": "Release From a Front Hair Pull with Two Hands",

        // Body hugs
        "שחרור מחביקה פתוחה מלפנים": "Release From an Open Body Hug From the Front",
        "שחרור מחביקה פתוחה מאחור": "Release From an Open Body Hug From the Rear",
        "שחרור מחביקה סגורה מלפנים": "Release From a Closed Body Hug From the Front",
        "שחרור מחביקה סגורה מאחור": "Release From a Closed Body Hug From the Rear",

        // Ground holds
        "שחרור מחביקת צואר מהצד בשכיבה": "Release from Neck Hold from the Side on the Ground",
        "שחרור מחביקת צואר ויד מהצד בשכיבה": "Release from Neck and Arm Hold from the Side on the Ground",

        // Chokes
        "שחרור מחניקה מלפנים בדחיפה": "Release from Choke from the Front with a Push",
        "שחרור מחניקה מאחור בדחיפה": "Release from Choke from the Back with a Push",
        "שחרור מחניקה מהצד - מרחוק": "Release from Choke from the Side - Distant",
        "שחרור מחניקה מהצד - מקרוב": "Release from Choke from the Side - Close",

        "שחרור מחניקה מהצד בשכיבה": "Release From a Choke From the Side While on the Ground",

        // Knife
        "הגנות יד רפלקסיביות נגד דקירות רגילות": "Reflexive Hand Defence Against Regular Stabs",
        "הגנות יד רפלקסיביות נגד דקירות מזרחיות": "Reflexive Hand Defence Against Eastern Stabs",
        "הגנות יד רפלקסיביות נגד דקירה ישרה": "Reflexive Hand Defence Against Straight Stabs",

        // Ground
        "הגנה נגד אגרופים בשכיבה": "Defence against Punches while in the Ground",

        // ---------------------------------------------------------
        // Green belt
        // ---------------------------------------------------------

        "מכת מרפק נגד קבוצה": "Elbow Strike against a Group",

        "בעיטה רגילה ובעיטת מגל באותה רגל": "A Regular Kick and a Magal (Circular) kick with the Same Leg",
        "בעיטת סטירה חיצונית": "External Slap Kick",
        "בעיטת מגל לאחור בשיכול אחורי": "Backward Magal (Circular) kick with a Cross-Step",
        "בעיטה לצד בסיבוב": "Side-Kick with Spin",

        "בלימה לאחור מגובה": "High Backward Breakfall",
        "בלימה לצד כהכנה לגזיזות": "Breakfall to the Side as Preperation for Cutting Kicks",
        "גלגול לפנים ובלימה לאחור - ימין/שמאל": "Front Roll and Break-Fall to the Back (Right and Left)",
        "גלגול לפנים ולאחור - ימין/שמאל": "Front Roll and a Backward Roll (Right and Left)",
        "גלגול ביד אחת - ימין/שמאל": "Front Roll with One Hand (Right and Left)",
        "גלגול לפנים עם קימה קדימה": "Front Roll with Getting Up Forward",

        "הגנה חיצונית נגד אגרוף ימין באגרוף מהופך": "External Defence Against a Right Punch with an Upside-Down Punch",
        "הגנה חיצונית נגד שמאל": "External Defence Against a Left Punch",
        "הגנה חיצונית נגד שמאל בהתקדמות": "External Defence Against a Left Punch with Progress",

        "הגנה פנימית נגד ימין באמה שמאל": "Internal Defence Against a Right Punch with the Left Forearm",
        "הגנה פנימית נגד שמאל באמה שמאל": "Internal Defence Against a Left Punch with the Left Forearm",
        "הגנה פנימית נגד אגרוף ימין באגרוף שמאל גולש": "Internal Defence Against a Right Punch with a Left Slide Punch",

        "הגנה נגד בעיטה רגילה - בעיטה לצד": "Defence Against a Regular Kick with a Side Kick",
        "הגנה נגד בעיטה רגילה - טיימינג לצד החי": "Defence Against a Regular Kick with Timing",
        "הגנה חיצונית באמת שמאל נגד בעיטה רגילה": "External Defence with the Left Forearm Against a Regular Kick",

        "הגנה נגד בעיטת מגל נמוכה": "Defence Against a Low Magal (Circular) kick",
        "הגנה נגד בעיטת מגל לפנים - בעיטה לצד": "Defence Against a Magal (Circular) kick with a Side Kick",

        "הגנה נגד בעיטת מגל לאחור - בעיטה בימין": "Defence Against a Backward Magal - Kick with your Right Foot",
        "הגנה נגד בעיטת מגל לאחור - בעיטה בשמאל": "Defence Against a Backward Magal - Kick with your Left Foot",
        "הגנה נגד בעיטת מגל לאחור - אגרוף שמאל": "Defence Against a Backward Magal - Punch with your Left Hand",
        "הגנה נגד בעיטת מגל לאחור בסיבוב - בעיטה": "Defence Against a Backward Magal with Spin - Kick",

        "הגנה חיצונית באמת ימין נגד בעיטה לצד": "External Defence with the Right Forearm Against a Side-Kick",
        "הגנה חיצונית באמת שמאל נגד בעיטה לצד": "External Defence with the Left Forearm Against a Side-Kick",
        "הגנה נגד בעיטה לצד - בעיטת סטירה חיצונית": "Defence Against a Side-Kick with an external Slap Kick",

        "חביקת זרוע מהצד - ראש התוקף מאחור": "Arm hug from the side - Attacker's head behind you",
        "חביקת זרוע מהצד - ראש התוקף מלפנים": "Arm hug from the side - Attacker's head in front",
        "שחרור מתפיסת יד גבוהה מאחור": "Release From a High Hand Grab From the Back",

        "שחרור מתפיסת חולצה מאחור": "Release From a Shirt Grab From the Back",

        "שחרור מתפיסת שיער מהצד - צד ימין": "Release From a Hair Grab from the Side - Right Side",
        "שחרור מתפיסת שיער מהצד - צד שמאל": "Release From a Hair Grab from the Side - Left Side",
        "שחרור מתפיסת שיער מאחור - צד מת": "Release From a Hair Grab From the Back - Blind Side",
        "שחרור מתפיסת שיער מאחור - צד חי": "Release From a Hair Grab From the Back - Live Side",

        "שחרור מחביקת צואר מאחור": "Release From a Neck Hold From the Back",

        "שחרור מחביקה פתוחה מהצד": "Open Body Hug From the Side",
        "חביקה סגורה מהצד": "Closed Body Hug From the Side",
        "חביקה פתוחה מלפנים בהרמה": "Open Body Hug From the Front while Lifting",
        "חביקה סגורה מלפנים בהרמה": "Closed Body Hug From the Front while Lifting",
        "חביקה פתוחה מאחור בהרמה": "Open Body Hug From the Back while Lifting",
        "חביקה סגורה מאחור בהרמה": "Closed Body Hug From the Back while Lifting",
        "חביקה פתוחה מאחור עם תפיסת אצבע": "Open Body Hug From the Back with a Finger Grab",

        "קוואלר - הליכה לאחור": "Cavalier with a Step Backwards",
        "קוואלר נגד ההתנגדות - הליכה לפנים": "Cavalier with Resistance - Walking Forward",
        "קוואלר - אגודלים": "Cavalier with Thumbs",
        "קוואלר - מרפק": "Cavalier with an Elbow",

        "הגנה נגד מקל - צד חי": "Defence Against a Stick - Live Side",
        "הגנה נגד מקל - צד מת": "Defence Against a Stick - Blind Side",

        "הגנה מאיום סכין לעורק שמאל": "Defence Against a Knife Threat to the Left Artery",
        "הגנה מאיום סכין לעורק ימין": "Defence Against a Knife Threat to the Right Artery",
        "הגנה מאיום סכין להב לגרגרת": "Defence Against a Knife Threat with the Blade on the Throat",
        "הגנה מאיום סכין מלפנים - חוד הסכין לגרגרת": "Defence Against a Knife Threat from the Front with the Tip Toward the Throat",
        "הגנה מאיום סכין מאחור - להב הסכין לגרגרת": "Defence Against a Knife Threat from the Back with the Blade on the Throat",
        "הגנה מאיום סכין מאחור - חוד לבטן": "Defence Against a Knife Threat from the Back with the Tip Pressed Against your Back",
        "הגנה מאיום סכין מאחור - חוד הסכין לגורגרת": "Defence Against a Knife Threat from the Front with the Tip Pressed Against your Body",

        "הגנה נגד דקירה רגילה עם בעיטה": "Defence Against a Regular Stab with a Kick",
        "הגנה נגד דקירה מזרחית עם בעיטה": "Defence Against an Eastern Stab with a Kick",
        "הגנה נגד דקירה ישרה נמוכה - בעיטה": "Defence Against a Low-Straight Stab with a Kick",
        "הגנה נגד דקירה ישרה - בעיטה": "Defence Against a Straight Stab with a Kick",
        "הגנה נגד דקירה ישרה מלפנים - הגנת גוף ובעיטת מגל למפשעה": "Defence Against a Straight Stab - Body Defence and a Magal (Circular) kick",
        "הגנה נגד דקירה ישרה מהצד": "Defence Against a Straight Stab from the Side",
        "הגנה נגד דקירה מזרחית מהצד": "Defence Against an Eastern Stab from the Side",
        "הגנה נגד דקירה רגילה מהצד": "Defence Against a Regular Stab from the Side",

        "הגנה נגד דקירה רגילה מהצד - התוקף בצד שמאל": "Defence Against a Regular Stab from the Side with Attacker on the Left",
        "הגנה נגד דקירה מהצד לעורף - התוקף משמאל": "Defence Against a Stab from the Side to the Back of the Head with Attacker on the Left",
        "הגנה נגד דקירה מהצד לגב - התוקף משמאל": "Defence Against a Stab from the Side to the Back with Attacker on the Left",
        "הגנה נגד דקירה רגילה מהצד - התוקף בצד ימין": "Defence Against a Regular Stab from the Side with Attacker on the Right",
        "הגנה נגד דקירה מהצד לגרגרת - התוקף בצד ימין": "Defence Against a Stab from the Side to the Throat with Attacker on the Right",
        "הגנה נגד דקירה מהצד לבטן - התוקף בצד ימין": "Defence Against a Stab from the Side to the Abdominal Area with Attacker on the Right",

        "מכה עם מקל / רובה לאזורים רגישים": "strike with the stick\\ rifle to vulnerable areas",

        // ---------------------------------------------------------
        // Blue belt
        // ---------------------------------------------------------

        "בעיטת פטיש": "Hammer Kick",
        "בעיטת גזיזה אחורית": "Backward Cutting Kick",
        "בעיטת גזיזה קדמית": "Forward Cutting Kick",
        "בעיטת גזיזה קדמית ובעיטת גזיזה אחורית בסיבוב": "Forward Cutting Kick and a Backward Cutting Kick with a Spin",
        "בעיטת מגל לאחור בסיבוב": "Backward Magal (Circular) kick with Spin",
        "בעיטת סטירה חיצונית בסיבוב": "External Slap Kick with Spin",

        "מניעת נפילה ממרחק שקיים מלפנים להפלה": "Preventing a double leg Take-Down from the front",

        "גלגול לצד - ימין/שמאל": "Roll to the Side (Left and Right)",
        "גלגול ברחיפה - ימין/שמאל": "Hover Roll (Left and Right)",
        "גלגול לגובה - ימין/שמאל": "High Roll (Left and Right)",
        "גלגול ללא ידיים - ימין/שמאל": "Forward Roll without Hands (Left and Right)",

        "הגנה נגד בעיטת ברך מלפנים": "Defence Against a Knee Strike from the Front",
        "הגנה נגד בעיטת ברך מהצד": "Defence Against a Knee Strike from the Side",

        "הגנה נגד בעיטה רגילה - סייד-סטפ לצד המת": "Defence Against a Regular Kick with a Sidestep to the Blind Side",
        "הגנה נגד בעיטה רגילה - סייד-סטפ לצד החי": "Defence Against a Regular Kick with a Sidestep to the live Side",

        "הגנה נגד בעיטת מגל לפנים עם השוק": "Defences Against a Front Magal (Circular) kick with the Shin",
        "הגנה נגד בעיטת מגל לצלעות": "Defences Against a Front Middle Magal (Circular) kick to the ribs",
        "הגנה פנימית נגד בעיטת מגל לפנים - בעיטה לצד": "Internal Defence Against a Magal (Circular) kick with a Side-Kick",
        "הגנה פנימית נגד בעיטת מגל לפנים - בעיטה לאחור": "Internal Defence Against a Magal (Circular) kick with a Backward Regular",

        "הגנה פנימית באמת ימין נגד בעיטה לצד": "Internal Defence Against a Side-Kick with Forearms",

        "שחרור תפיסת ידיים בשכיבה": "Release from Grabbing Both Hands on the Ground with a Pull",
        "שחרור מחביקת צוואר מהצד והפלה": "Release from Neck Hold from the Side with Falling",
        "שחרור מחביקת צוואר מאחור עם נעילה": "Release from Neck Hold from Behind with Lock",
        "שחרור מחביקת צוואר בשכיבה ברכיבה צמודה": "Release From a Mounted Neckhold",

        "שחרור מחניקה לקיר - מלפנים לא צמודה": "Release From a Front Choke Against the Wall",
        "שחרור מחניקה לקיר - צמודה מלפנים": "Release From a Front Choke Pressed Tightly Against the Wall",
        "שחרור מחניקה לקיר - דחיפה מאחור": "Release From a Choke From the Back with a Push Toward the Wall",
        "שחרור מחניקה לקיר - צמודה מאחור": "Release From a Choke From the Back While Pressed Tightly Against the Wall",

        "שחרור מחניקה בשכיבה - ידיים כפופות": "Release From a Mounted Choke - Attacker's Hands are Bent",
        "שחרור מחניקה בשכיבה - ידיים ישרות": "Release From a Mounted Choke - Attacker's Hands are Straight",
        "שחרור מחניקה צמודה בשכיבה": "Release From a Mounted Choke While Pressed Tightly",

        "הגנה מאיום סכין להב לגורגרת": "Defence From a Knife Threat with the Blade to the Throat",
        "הגנה מאיום סכין מלפנים - חוד הסכין לגרוגרת": "Defence From a Knife Threat From the Front - Tip of the Knife to the Throat",
        "הגנה מאיום סכין מאחור - להב הסכין לגרוגרת": "Defence From a Knife Threat From the Back - Blade of the Knife to the Throat",
        "הגנה מאיום סכין מאחור - חוד לגב": "Defence From a Knife Threat From the Back - Tip to the Back",
        "הגנה מאיום סכין מאחור - להב על העורף": "Defence From a Knife Threat From the Back - Blade on the Neck",

        "הגנה נגד דקירה מזרחית - יד": "Defence Against an Eastern Stab with a Hand",
        "הגנה נגד דקירה ישרה נמוכה": "Defence Against a Low Straight Stab",
        "הגנה נגד דקירה ישרה מהצד - צד מת": "Defence Against a Straight Stab from the Side - Blind Side",
        "הגנה נגד דקירה ישרה מהצד - צד חי": "Defence Against a Straight Stab from the Side - Live Side",
        "הגנה פנימית נגד דקירה ישרה - צד חי": "Internal Defence Against a Straight Stab - Live Side",
        "הגנה פנימית נגד דקירה ישרה - צד מת": "Internal Defence Against a Straight Stab - Blind Side",

        // ---------------------------------------------------------
        // Brown belt
        // ---------------------------------------------------------

        "בעיטה רגילה ובעיטת מגל בניתור": "Jumping Regular Kick and a Magal (Circular) kick",
        "בעיטת מגל בניתור": "Jumping Magal (Circular) kick",
        "בעיטת מגל כפולה בניתור": "Jumping Double Magal (Circular) kick",

        "גלגול עם רובה": "Forward Roll with a Rifle",

        "הגנה פנימית נגד בעיטה לסנטר": "Internal Defence Against a Kick to the Chin",
        "הגנה חיצונית נגד בעיטה רגילה – פריצה": "External Defence Against a Regular Kick with Bursting",
        "הגנה חיצונית נגד בעיטה רגילה – גזיזה": "External Defence Against a Regular Kick with a Cutting Kick",
        "הגנה חיצונית נגד בעיטה רגילה – טאטוא": "External Defence Against a Regular Kick with a Sweep",
        "הגנה פנימית נגד בעיטה רגילה – טאטוא": "Internal Defence Against a Regular Kick with a Forward Cutting Kick",
        "הגנה נגד בעיטת מגל – פריצה": "Defence Against a Magal (Circular) kick with Bursting",
        "הגנה חיצונית נגד מגל לפנים – גזיזה": "External Defence Against a Front Magal (Circular) kick with a Cutting Kick",
        "הגנה חיצונית נגד מגל לפנים – טאטוא": "External Defence Against a Front Magal (Circular) kick with a Sweep",
        "הגנה נגד בעיטת מגל לאחור – פריצה": "Defence Against a Reverse Magal (Circular) kick with Bursting",

        "חביקת צוואר מאחור – בריח על העורף, המגן כפוף לפנים": "Release From a Neck Hold From the Back with leverage - Defender is bent",

        "הגנה נגד מקל בסיבוב – צד חי": "Defence Against a Stick with a Spin to the Live Side",
        "הגנה נגד מקל עם קוואלר – צד מת": "Defence Against a Stick with a Cavalier to the Blind Side",
        "הגנה נגד מקל נקודת תורפה – לצד המת": "Defence Against a Stick to the Blind Side using a Vital Spot on the Attacker's Head",

        "הגנה נגד סכין בשיסוף – הטיה והגנה לצד החי": "Defence Against a Slash Attack by Leaning Backward and Defending to the Live Side",
        "הגנה נגד סכין בשיסוף – הטיה והגנה לצד המת": "Defence Against a Slash Attack by Leaning Backward and Defending to the Blind Side",
        "הגנה נגד סכין בשיסוף – פריצה והגנה לצד החי": "Defence Against a Slash Attack by Bursting to the Live Side",
        "הגנה נגד סכין בשיסוף – פריצה והגנה לצד המת": "Defence Against a Slash Attack by Bursting to the Blind Side",

        "הגנה מאיום אקדח מלפנים": "Defence from a Gun Threat from the Front",
        "הגנה מאיום אקדח מהצד הפנימי – תוקף בצד ימין": "Defence from a Gun Threat from the Side, in Front of the Arm, Attacker on Right",
        "הגנה מאיום אקדח מהצד הפנימי – תוקף בצד שמאל": "Defence from a Gun Threat from the Side, in Front of the Arm, Attacker on Left",
        "הגנה מאיום אקדח מהצד החיצוני": "Defence from a Gun Threat from the Side, Behind the Arm",
        "הגנה מאיום אקדח מאחור": "Defence from a Gun Threat from the Back",

        // ---------------------------------------------------------
        // Black belt
        // ---------------------------------------------------------

        "ניתור ברגל שמאל ובעיטה רגילה ברגל ימין": "Leaping with your Left Foot and a Regular Kick with your Right foot",
        "ניתור ברגל שמאל ובעיטה לצד ברגל ימין": "Leaping with your Left Foot and a Side-Kick with your Right foot",
        "ניתור ברגל שמאל ובעיטה לצד ברגל שמאל": "Leaping with your Left Foot and a Side-Kick with your Left foot",
        "בעיטה לצד בסיבוב מלא בניתור": "Leaping Side-Kick with Spin",
        "בעיטת מגל לאחור בסיבוב בניתור": "Leaping Backward Magal (Circular) Kick with Spin",
        "בעיטת הגנה לאחור בניתור": "Leaping Backward Defensive Kick",

        "הגנה פנימית נגד אגרוף שמאל - בעיטת הגנה": "Internal Defence Against a Left Punch- Defensive Kick",
        "הגנה פנימית נגד אגרוף שמאל - בעיטה לצד": "Internal Defence Against a Left Punch- Side-Kick",
        "הגנה פנימית נגד אגרוף שמאל - בעיטה רגילה לאחור": "Internal Defence Against a Left Punch- Regular Kick Backward",
        "הגנה פנימית נגד אגרוף שמאל - בעיטת מגל לאחור": "Internal Defence Against a Left Punch- Backward Magal (Circular) kick",
        "הגנה פנימית נגד אגרוף שמאל - בעיטת סטירה חיצונית": "Internal Defence Against a Left Punch- External Slapping Kick",
        "הגנה פנימית נגד אגרוף שמאל - בעיטת מגל לפנים": "Internal Defence Against a Left Punch- Front Magal (Circular) kick",
        "הגנה פנימית נגד אגרוף שמאל - גזיזה קדמית": "Internal Defence Against a Left Punch- Forward Cutting Kick",

        "הגנה נגד בעיטה רגילה - התחמקות בסיבוב": "Defence Against a Regular Kick- Evasion with a Spin",
        "הגנה נגד בעיטת מגל לפנים לראש - הדיפה באמת שמאל": "Defence Against Front Magal (Circular) kick- The Leg Passed Over the Head",
        "הגנה נגד בעיטת מגל לפנים לראש - רגל עברה מעל הראש": "Defence Against Front Magal (Circular) kick- The Leg Passed Over the Head",
        "הגנה נגד מגל לפנים  לראש - התחמקות גוף בסיבוב בגזיזה": "Defence Against Front Magal (Circular) Kick - Evasion with a Spin and a Cutting Kick",
        "הגנה נגד בעיטת סטירה - גזיזה": "Defences Against a Slap Kick - Cutting Kick",

        "שחרור מתפיסת נלסון": "Release From A Nelson Hold",
        "שחרור מחביקת צואר מהצד - משיכה לאחור": "Release from Neck Hold from the Side - Pulling Backward",
        "שחרור מחביקת צואר מאחור - משיכה לאחור": "Release from Rear Neck Hold - Pulling Backward",
        "שחרור מחביקת צואר מהצד - יד תפוסה": "Release from Neck Hold from the Side - One Arm Caught",
        "שחרור מחביקת צואר מהצד - זריקת רגל": "Release from Neck Hold from the Side - Leg Throw",
        "שחרור מחביקת צואר מהצד - ירידה לברך": "Release from Neck Hold from the Side - Kneeling",
        "שחרור מחביקת צואר מהצד - מהברך": "Release from Neck Hold from the Side - Kneeling",

        "שחרור מחביקה סגורה מהצד - היד הרחוקה משוחררת": "Release From a Closed Body Hug From the Side - the rear hand is free",
        "שחרור מחביקה סגורה מהצד": "Release From a Closed Body Hug From the Side",
        "שחרור מחביקה פתוחה מאחור - הטלה": "Release From an Open Body Hug From the Rear - Falling",
        "שחרור מחביקה סגורה מאחור - הטלה": "Release From a Closed Body Hug From the Rear - Falling",

        "הגנה נגד מקל ארוך-התקפה לצד ימין מגן": "Defence Against a Long Stick to the defender's Right Side",
        "הגנה נגד מקל ארוך-התקפה לצד שמאל מגן": "Defence Against a Long Stick to the defender's Left Side",
        "הגנה נגד מקל ארוך מצד ימין": "Defence Against a Long Stick from the Right Side",
        "הגנה נגד מקל ארוך מצד שמאל": "Defence Against a Long Stick from the Left Side",
        "הגנה נגד מקל ארוך דקירה - צד חי": "Defence Against a Long Stick Stab - Live Side",
        "הגנה נגד מקל ארוך דקירה - צד מת": "Defence Against a Long Stick Stab - Blind Side",

        "הגנה נגד דקירה - צד חי ימין": "Defence Against a Slash Attack to the Live Side - Right Side",
        "הגנה נגד דקירה - צד חי שמאל": "Defence Against a Slash Attack to the Live Side - Left Side",
        "הגנה נגד דקירה - צד מת ימין": "Defence Against a Slash Attack to the Blind Side - Right Side",
        "הגנה נגד דקירה - צד מת שמאל": "Defence Against a Slash Attack to the Blind Side - Left Side",

        "מקל נגד סכין - דקירה רגילה": "Stick Against Knife Defence Against a Regular Stab",
        "מקל נגד סכין - דקירה מזרחית": "Stick Against Knife Defence Against an Eastern Stab",
        "מקל נגד סכין - דקירה ישרה": "Stick Against Knife Defence Against a Straight Stab",
        "מקל נגד סכין - דקירה מעל מצד ימין": "Stick Against Knife Defence Against an Overhead Stab from the Right Side",
        "מקל נגד סכין - דקירה מעל מצד שמאל": "Stick Against a Knife Against a Regular Overhead Stab from the Left Side",
        "מקל נגד סכין - דקירה מזרחית מצד ימין": "Stick Against a Knife Against an Eastern Stab from the Right Side",
        "מקל נגד סכין - דקירה מזרחית מצד שמאל": "Stick Against a Knife Against an Eastern Stab from the Left Side",
        "מקל נגד סכין - דקירה ישירה מצד ימין (פנימית)": "Internal Defence with a Stick Against a Direct Stab from the Right Side",
        "מקל נגד סכין - דקירה ישירה מצד ימין (חיצונית)": "External Defence with a Stick Against a Direct Stab from the Right Side",
        "מקל נגד סכין - דקירה ישירה מצד שמאל (פנימית)": "Internal Defence with a Stick Against a Direct Stab from the Left Side",
        "מקל נגד סכין - דקירה ישירה מצד שמאל (חיצונית)": "External Defence with a Stick Against a Direct Stab from the Left Side",

        "מקל אחד וסכין אחת - המקל בצד חי": "One Stick and One Knife- Stick in the Live Side",
        "מקל אחד וסכין אחת - המקל בצד מת": "One Stick and One Knife- Stick in the Blind Side",
        "מקל אחד וסכין אחת - הסכין קרוב": "One Stick and One Knife- When the Knife is Closer",

        "הגנה נגד איום אקדח לראש מלפנים": "Defence from a Gun Threat from the Front to the Head",
        "הגנה נגד איום אקדח צמוד לראש מלפנים": "Defence from a Gun Threat from the Front - Barrel Touching the Head",
        "הגנה נגד איום אקדח מלפנים - קנה קצר": "Defence from a Gun Threat from the Front- Short Barrel",
        "הגנה נגד איום אקדח לראש - צד ימין": "Defence from a Gun Threat to the Head- Right Side",
        "הגנה נגד איום אקדח לראש - צד שמאל": "Defence from a Gun Threat to the Head- Left Side",
        "הגנה נגד איום אקדח מאחור באלכסון - צד שמאל": "Defence from a Gun Threat to the Head Diagonally from Behind- Left Side",
        "הגנה נגד איום אקדח לראש מאחור": "Defence from a Gun Threat to the Head from Behind",
        "הגנה נגד איום אקדח מאחור בידיים מורמות": "Defence from a Gun Threat from Behind with Hands Raised",
        "הגנה נגד איום אקדח בהובלה": "Defence Against a Gun Threat from Behind with the Attacker Leading",
        "הגנה מאיום אקדח מאחור דחיפה": "Defence Against a Gun Threat from Behind with the Attacker Pushing",

        "1 מקל 1 סכין – מקל בצד חי": "One Stick and One Knife- Stick in the Live Side",
        "1 מקל 1 סכין – מקל בצד מת": "One Stick and One Knife- Stick in the Blind Side",
        "1 מקל 1 סכין – במקרה והסכין קרוב": "One Stick and One Knife- When the Knife is Closer",

        "הדמיה כנגד 2 תוקפים": "Simulation Against Two Attackers",

        "מכת מקל לראש": "Stick Strike to the Head",
        "מכת מקל לרקה": "Stick Strike to the Temple",
        "מכת מקל ללסת / צוואר": "Stick Strike to the Jaw or Neck",
        "מכת מקל לפרקי האצבעות": "Stick Strike to the Knuckles",
        "מכת מקל לעצם הבריח": "Stick Strike to the Clavicle Bone",
        "מכת מקל למרפק": "Stick Strike to the Elbow",
        "מכת מקל לשורש כף היד": "Stick Strike to the Wrist",
        "מכת מקל לברך": "Stick Strike to the Knee",
        "מכת מקל למפסעה": "Stick Strike to the Groin",
        "הצלפת מקל לצלעות": "Stick Whip to the Ribs",
        "דקירת מקל חיצונית לצלעות": "External Stick Stab to the Ribs",
        "דקירת מקל ישרה לבטן / לגרון": "Straight Stick Stab to the Abdominal or Throat",
        "דקירת מקל הפוכה": "Reversed Stick Stab",

        "מכה אופקית לצוואר": "Horizontal Strike to the Neck",
        "דקירה": "Stab",
        "מכת מגל": "Magal (Circular) Strike",
        "שיסוף": "Slash",
        "מכה למפשעה": "Groin Strike",
        "מכה לצד": "Side Strike",
        "מכה לאחור": "Backward Strike",
        "מכה אופקית לאחור": "Backward Horizontal Strike",
        "מכת סנוקרת": "Uppercut",
        "מכה אופקית ובעיטה למפשעה": "Horizontal Strike and a Regular Kick to the Groin",
        "מכה אופקית ובעיטת הגנה": "Horizontal Strike and a Defensive Kick",
        "מכה לצד ובעיטה לצד": "Side Strike and a Side Kick"
    ]

    static func title(for value: String) -> String {
        map[value] ?? value
    }
}
