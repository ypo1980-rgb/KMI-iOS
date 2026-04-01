import SwiftUI
import Shared

struct WeakPointsView: View {
    let belt: Belt
    @ObservedObject var nav: AppNavModel

    var body: some View {
        ZStack {
            weakPointsBackground
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        warningCard

                        smallSectionHeader("מפרקים / אצבעות (כללי)")

                        InfoCard(
                            title: "מפרקים",
                            text: "כל תנועה כנגד כיוון לתנועה הטבעית – שבר."
                        )

                        InfoCard(
                            title: "שבר באצבע",
                            text: "אדם מתעלף במקום."
                        )
                        
                        SectionTitle(text: "חזית")

                        WeakPointRow(place: "שיער", bodyPart: "ראש", effect: "נקודת אחיזה – ניתן להוציא משיווי משקל.")
                        WeakPointRow(place: "מצח", bodyPart: "ראש", effect: "אזור קשה – הפגיעה פחות אפקטיבית יחסית.")
                        WeakPointRow(place: "גבה", bodyPart: "ראש", effect: "נקודה רגישה – דימום יכול לרדת לעיניים ולפגוע בראייה.")
                        WeakPointRow(place: "עין", bodyPart: "ראש", effect: "פגיעה בעין גורמת לנזק חמור/עיוורון אפשרי.")
                        WeakPointRow(place: "גשר האף / שורש האף", bodyPart: "ראש", effect: "פגיעה באף יכולה לגרום לדמעות/דימום ועד שבר עצם האף וזעזוע מוח.")
                        WeakPointRow(place: "שורש האף / שפה תחתונה מתחת לאף", bodyPart: "ראש", effect: "נקודה להוצאה משיווי משקל ע״י הרמת שורש האף.")
                        WeakPointRow(place: "לסת עליונה", bodyPart: "ראש", effect: "ניתן לשבור שיניים בקלות יחסית ע״י מכה.")
                        WeakPointRow(place: "שפתיים", bodyPart: "ראש", effect: "השפה עלולה להיפצע ע״י השיניים.")
                        WeakPointRow(place: "לסת פתוחה", bodyPart: "ראש", effect: "קל יותר לשבור ע״י מכה.")
                        WeakPointRow(place: "לסת סגורה", bodyPart: "ראש", effect: "זעזוע – קשה יותר לשבור.")
                        WeakPointRow(place: "גרוגרת", bodyPart: "ראש", effect: "לחיצה/מכה קדימה – סכנת חיים, דורש טיפול רפואי מיידי.")
                        WeakPointRow(place: "שקע הגרוגרת", bodyPart: "ראש", effect: "דימום קל/כאב למספר שניות.")
                        WeakPointRow(place: "עצם הבריח", bodyPart: "חלק עליון", effect: "שבר יכול לשתק את הצד ולמנוע תנועת יד בצורה תקינה.")
                        WeakPointRow(place: "בית החזה", bodyPart: "פנימי", effect: "שבר בצלעות יכול לגרום לקרע בריאה.")
                        WeakPointRow(place: "כבד", bodyPart: "פנימי", effect: "שבר בצלעות יכול לגרום לקרע בכבד.")
                        WeakPointRow(place: "מפתח הלב", bodyPart: "פנימי", effect: "פגיעה קשה מאוד – סכנת חיים.")
                        WeakPointRow(place: "כליות", bodyPart: "פנימי", effect: "פגיעה בכליה – נזק משמעותי אפשרי.")
                        WeakPointRow(place: "בטן", bodyPart: "פנימי", effect: "פגיעה יכולה לגרום לשטף דם פנימי.")
                        WeakPointRow(place: "אשכים", bodyPart: "חלק תחתון", effect: "נקודה חלשה מאוד – תגובת כאב חריפה.")
                        WeakPointRow(place: "פיקה (ברך)", bodyPart: "חלק תחתון", effect: "ניתן לרסק/לגרום לנזק – נכות אפשרית.")
                        WeakPointRow(place: "שוק הרגל", bodyPart: "חלק תחתון", effect: "עצם חשופה יחסית – כאב משמעותי מפגיעה.")
                        WeakPointRow(place: "גב כף הרגל", bodyPart: "חלק תחתון", effect: "מבנה עדין – בדריכה הנזק יכול להיות גדול, רצועות עלולות להיקרע.")
                        WeakPointRow(place: "שרירים", bodyPart: "כללי", effect: "פגיעה בשריר/כלי דם גורמת כאב ופגיעה בתפקוד.")

                        SectionTitle(text: "צד")

                        WeakPointRow(place: "פגיעה ברקה", bodyPart: "ראש", effect: "מוות.")
                        WeakPointRow(place: "אוזן", bodyPart: "ראש", effect: "קריעת עור התוף – דימום.")
                        WeakPointRow(place: "צוואר", bodyPart: "ראש", effect: "פגיעה בכלי דם: עד ~5 שניות עילפון; זמן נוסף/חניקה – סכנת חיים.")
                        WeakPointRow(place: "כתף", bodyPart: "חלק עליון", effect: "ניתן להוציא מהמקום ע״י הוצאת העצם מהשקע.")
                        WeakPointRow(place: "בית השחי", bodyPart: "חלק עליון", effect: "שריר רגיש מאוד – פגיעה כואבת מאוד.")
                        WeakPointRow(place: "צלעות", bodyPart: "חלק עליון", effect: "נכנסות פנימה בקלות; פגיעה בעצב גורמת כאב.")
                        WeakPointRow(place: "שבירת צלעות", bodyPart: "חלק עליון", effect: "גרימת קרע בריאה – אפילו מוות.")
                        WeakPointRow(place: "שקע הברך מהצד", bodyPart: "חלק תחתון", effect: "קל לשבור ולגרום לקרע – אין התנגדות.")
                        WeakPointRow(place: "קרסול", bodyPart: "חלק תחתון", effect: "בפגיעה נכונה (אלכסונית למעלה, ימינה/שמאלה) – נפגע הקרסול וקשה ללכת.")

                        SectionTitle(text: "מאחור")

                        WeakPointRow(place: "מוח גדול", bodyPart: "ראש", effect: "העצבים בגוף (אינסטינקט).")
                        WeakPointRow(place: "מוח קטן", bodyPart: "ראש", effect: "שיווי משקל – פגיעה גורמת לאיבוד שיווי משקל.")
                        WeakPointRow(place: "שבירת מפרקת", bodyPart: "ראש", effect: "מוות מיידי.")
                        WeakPointRow(place: "פגיעה בחוליות", bodyPart: "חלק עליון", effect: "נזק למפרקת.")
                        WeakPointRow(place: "עמוד השדרה", bodyPart: "חלק עליון", effect: "בנוי מחוליות – קשה לגרום לשבר.")
                        WeakPointRow(place: "עצם הזנב", bodyPart: "חלק תחתון", effect: "האדם לא יכול לשבת (משם ומטה).")
                        WeakPointRow(place: "גיד אכילס", bodyPart: "חלק תחתון", effect: "פגיעה ואי אפשר להזיז את העקב למעלה/למטה.")

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var weakPointsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 2/255, green: 6/255, blue: 23/255),
                Color(red: 17/255, green: 24/255, blue: 39/255),
                Color(red: 29/255, green: 78/255, blue: 216/255),
                Color(red: 34/255, green: 211/255, blue: 238/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var warningCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 245/255, green: 124/255, blue: 0/255))

            Text(
                "לפגיעה בנקודות התורפה יש פוטנציאל נזק גבוה. אין לבצע אלא במצב חירום.\nחל איסור מוחלט לתרגל ללא פיקוח מאמן מוסמך וציוד בטיחות מתאים.\nתרגול שגוי עלול להסתיים בפציעה ואף במוות."
            )
            .font(.system(size: 15))
            .foregroundStyle(Color(red: 78/255, green: 52/255, blue: 46/255))
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 255/255, green: 243/255, blue: 224/255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 255/255, green: 183/255, blue: 77/255), lineWidth: 1)
        )
    }

    private func smallSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(.white)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 4)
    }
}

private struct InfoCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 229/255, green: 231/255, blue: 235/255))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 29/255, green: 78/255, blue: 216/255), lineWidth: 1)
        )
    }
}

private struct WeakPointRow: View {
    let place: String
    let bodyPart: String
    let effect: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(place)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(bodyPart)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 191/255, green: 219/255, blue: 254/255))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(effect)
                .font(.system(size: 15))
                .foregroundStyle(Color(red: 229/255, green: 231/255, blue: 235/255))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 30/255, green: 58/255, blue: 138/255), lineWidth: 1)
        )
    }
}
