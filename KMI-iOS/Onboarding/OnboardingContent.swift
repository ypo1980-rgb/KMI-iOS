import Foundation

enum OnboardingContent {

    static let steps: [OnboardingStep] = [

        OnboardingStep(
            id: "welcome",
            titleHe: "מסך הבית",
            titleEn: "Home screen",
            descriptionHe: """
            כל האימונים הקרובים, הודעות המאמן, סיכום ההתקדמות ולוח האימונים החודשי שלך — במקום אחד.
            """,
            descriptionEn: """
            Your upcoming training sessions, coach messages, progress summary and monthly schedule — all in one place.
            """,
            imageName: "onboarding_home",
            accentHex: 0xFF6D4ED8
        ),

        OnboardingStep(
            id: "roles",
            titleHe: "אזור המאמן ואזור המתאמן",
            titleEn: "Coach and trainee areas",
            descriptionHe: """
            תפריט הצד מרכז במקום אחד את כל האזורים החשובים באפליקציה.

            ממנו ניתן לפתוח את הפרופיל האישי, רשימת המתאמנים, מבחנים, תרגילים, תשלומים, יצירת קשר, הפורום, הגדרות השפה וכלי ניהול נוספים.
            """,
            descriptionEn: """
            The side menu provides quick access to the main areas of the app.

            From here you can open your profile, trainee list, exams, exercises, payments, contact options, the forum, language settings and additional management tools.
            """,
            imageName: "onboarding_roles",
            accentHex: 0xFFF59E0B
        ),

        OnboardingStep(
            id: "belts",
            titleHe: "תרגילים לפי חגורה",
            titleEn: "Exercises by Belt",
            descriptionHe: """
            במסך זה ניתן לצפות בכל התרגילים השייכים לחגורה שנבחרה.

            התרגילים מסודרים לפי נושאים ותתי־נושאים, כך שניתן למצוא במהירות את חומר הלימוד המתאים לרמה שלך.
            """,
            descriptionEn: """
            This screen displays all exercises included in the selected belt.

            The exercises are organized by topics and subtopics, making it easy to find the learning material relevant to your level.
            """,
            imageName: "onboarding_belts",
            accentHex: 0xFF0EA5E9
        ),

        OnboardingStep(
            id: "knowledge_status",
            titleHe: "סיווג תרגילים לפי נושא נבחר",
            titleEn: "Exercise Classification by Selected Topic",
            descriptionHe: """
            במסך זה ניתן לסווג כל תרגיל לפי מצב הידע שלך:

            ירוק – יודע
            אדום – לא יודע
            ללא סימון – עדיין לא נבדק

            הסיווגים נשמרים ומשמשים לסיכומים, לתרגול ממוקד ולדוחות PDF.
            """,
            descriptionEn: """
            On this screen, you can classify each exercise according to your knowledge status:

            Green – known
            Red – unknown
            Unmarked – not reviewed yet

            These classifications are saved and used for summaries, focused practice sessions and PDF reports.
            """,
            imageName: "onboarding_exercises",
            accentHex: 0xFF16A34A
        ),

        OnboardingStep(
            id: "topics",
            titleHe: "תרגילים לפי נושא",
            titleEn: "Exercises by Topic",
            descriptionHe: """
            במסך התרגילים לפי נושא יוצגו כל התרגילים השייכים לנושא שנבחר, מכל החגורות הרלוונטיות.

            ניתן לפתוח הסבר מפורט, לשמור הערה אישית ולהתחיל תרגול לפי הרשימה הפעילה.
            """,
            descriptionEn: """
            The Exercises by Topic screen displays all exercises related to the selected topic across the relevant belts.

            You can open a detailed explanation, save a personal note and start a practice session from the active list.
            """,
            imageName: "onboarding_topics",
            accentHex: 0xFF7C3AED
        ),

        OnboardingStep(
            id: "internal_exam",
            titleHe: "מבחן פנימי",
            titleEn: "Internal exam",
            descriptionHe: """
            המבחן הפנימי מאפשר לבחור נבחן, להזין ציונים ולשמור תוצאה מסודרת.

            בסיום ניתן ליצור דוח PDF הכולל את פרטי המבחן והציונים.
            """,
            descriptionEn: """
            The internal exam lets you select a trainee, enter scores and save an organized result.

            At the end, you can create a PDF report containing the exam details and scores.
            """,
            imageName: "onboarding_internal_exam",
            accentHex: 0xFFDB2777
        ),

        OnboardingStep(
            id: "payments_report",
            titleHe: "דוח תשלומים",
            titleEn: "Payments report",
            descriptionHe: """
            דוח התשלומים מרכז את מצב הגבייה של המתאמנים ומציג מי שילם ומי עדיין לא שילם.

            ניתן לסנן לפי סניף, לחפש מתאמן ולצפות באחוז הגבייה העדכני.
            """,
            descriptionEn: """
            The payments report summarizes trainee payments and shows who has paid and who has not.

            You can filter by branch, search for a trainee and view the current collection rate.
            """,
            imageName: "onboarding_payments_report",
            accentHex: 0xFF10B981
        ),

        OnboardingStep(
            id: "pdf",
            titleHe: "יצירת דוחות PDF",
            titleEn: "Creating PDF reports",
            descriptionHe: """
            אייקון השיתוף בסרגל האייקונים יוצר דוח PDF מהנתונים האמיתיים שמופיעים במסך.

            לאחר יצירת הקובץ ניתן לפתוח, לשמור או לשתף אותו באמצעות אפליקציות המכשיר.
            """,
            descriptionEn: """
            The share action in the icon rail creates a PDF report from the real data displayed on the screen.

            Once generated, the file can be opened, saved or shared using apps installed on the device.
            """,
            imageName: "onboarding_pdf",
            accentHex: 0xFFEC4899
        ),

        OnboardingStep(
            id: "summary",
            titleHe: "סרגל האייקונים וכלי האפליקציה",
            titleEn: "Icon rail and app tools",
            descriptionHe: """
            סרגל האייקונים מרכז פעולות שימושיות כמו בית, חיפוש, הגדרות, סטטיסטיקה, העוזר החכם ושיתוף.

            תמיד ניתן לחזור לסיור הזה דרך אייקון ההסברים שבסרגל.
            """,
            descriptionEn: """
            The icon rail provides quick access to Home, Search, Settings, Statistics, the smart assistant and Share.

            You can always reopen this tour using the Guide action in the rail.
            """,
            imageName: "onboarding_summary",
            accentHex: 0xFF2563EB
        ),

        OnboardingStep(
            id: "ai",
            titleHe: "יובל – העוזר האישי",
            titleEn: "Yuval – Personal Assistant",
            descriptionHe: """
            העוזר האישי מאפשר לקבל מידע על תרגילים, אימונים וחומר ק.מ.י.

            ניתן לבחור נושא מתוך האפשרויות המוצגות ולהפעיל פקודות קוליות בלחיצה על אייקון המיקרופון.
            """,
            descriptionEn: """
            The personal assistant provides information about exercises, training sessions and K.M.I. material.

            Select one of the displayed topics or activate voice commands by tapping the microphone icon.
            """,
            imageName: "onboarding_personal_assistant",
            accentHex: 0xFF7C3AED
        )
    ]
}
