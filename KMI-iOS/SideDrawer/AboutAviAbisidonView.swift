import SwiftUI
import AudioToolbox

struct AboutAviAbisidonView: View {

    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.94)
            : Color.black.opacity(0.88)
    }

    private var secondaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.78)
            : Color.black.opacity(0.82)
    }

    private var cardColor: Color {
        isDarkMode
            ? Color(hex: 0xFF111827).opacity(0.97)
            : Color.white
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // רקע כהה כמו בסקרין
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.23),
                    Color(red: 0.01, green: 0.05, blue: 0.14),
                    Color(red: 0.11, green: 0.33, blue: 0.80)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // הכרטיס
            VStack(spacing: 0) {
                Text("אבי אביסידון")
                    .kmiFont(size: 22, weight: .heavy)
                    .foregroundStyle(primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .overlay(
                        isDarkMode
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.12)
                    )

                ScrollView {
                    VStack(alignment: .trailing, spacing: 12) {

                        paragraph("""
מייסד שיטת ק.מ.י קרב מגן ישראלי
אבי אבסידון דאן 10 ראש שיטת ק.מ.י. ויו"ר עמותת ק.מ.י.
""")

                        paragraph("אבי אביסידון עוסק במקצועות קרב מגע וקרב מגן ישראלי, למעלה מ-40 שנה.")

                        paragraph("""
בשנת 1979 הוענקה לאבי חגורה שחורה דאן 1 בקרב מגע.
על חגורה זו ועד דרגת דאן 4 חתום מייסד קרב המגע אימי ליכטנפלד והמדריך אלי אביקזר.
""")

                        paragraph("""
בשלב זה, החל להרקם אצל אלי אביקזר רעיון מיסוד השינויים והשיפורים שפיתח בתרגילי קרב המגע ואיחודם למקצוע חדש בשם ק.מ.י. - קרב מגן ישראלי. אלי פנה לתלמידו הבכיר אבי, שהיה לסגנו ויד ימינו בהקמת והטמעת השיטה.
""")

                        paragraph("""
כ-15 שנה שימש אבי אביסידון בתפקיד סגן ראש שיטת ק.מ.י. וסגן יו"ר עמותת ק.מ.י.
דרגות דאן 5 ועד דאן 7 הוענקו לאבי ע"י מייסד ק.מ.י. אלי אביקזר.
""")

                        paragraph("""
לאחר פטירת אלי אביקזר, נבחר אבי אביסידון ביוני 2004 לראש שיטת ק.מ.י. וליו"ר עמותת ק.מ.י.
אבי אביסידון מוסמך מטעם מכון וינגייט.
""")

                        divider()

                        sectionTitle("בידיו התעודות הבאות:")

                        Bulleted("„מדריך קרב מגע\" מטעם מכון וינגייט - בי\"ס למאמנים.")
                        Bulleted("„מאמן באומנויות לחימה\" מטעם מכון וינגייט - בי\"ס למאמנים.")
                        Bulleted("„מורה בכיר באומנויות לחימה\" מטעם המכללה האקדמית בוינגייט ע\"ש זינמן.")

                        paragraph("משנת 1991 מלמד אבי קורסים לקרב מגן ישראלי במכללה האקדמית בוינגייט.")

                        divider()

                        sectionTitle("ניסיון צבאי וביטחוני:")

                        paragraph("""
במשך שרותו הצבאי בשנים 1977-1979 שימש אבי כסגן ראש מדור קרב מגע בצה"ל.
בין השנים 1979-1991 אימן את שייטת-13 בקרב מגע ובכושר גופני.
אבי המשיך בשרות מילואים בשייטת עד 2004 ובמקביל אימן יחידות מיוחדות.
""")

                        divider()

                        paragraph("""
משנת 1992 עוסק אבי אבסידון וצוות מדריכים מטעמו בניהול אימון והכשרת מאבטחים לגופים ממשלתיים ולמגזר העסקי:
""")

                        Bulleted("משרד התחבורה,")
                        Bulleted("משרד החינוך,")
                        Bulleted("משרד הבריאות - אימון מאבטחי בתי החולים ואימון הסגל הרפואי של בתי החולים הפסיכיאטרים.")
                        Bulleted("רשות הדואר,")
                        Bulleted("רשות הנמלים חיפה ואילת,")
                        Bulleted("המכללה לבטחון וחקירות.")

                        paragraph("""
במקביל העביר אבי אבסידון השתלמויות למדריכות קרב מגע בצה"ל בדגש על ההיבט האזרחי לצורך הכשרתן כמדריכות בבתי הספר.
""")

                        divider()

                        sectionTitle("פעילות בינלאומית:")

                        paragraph("""
אבי מעורב בהכנת מאבטחים אישיים עבור נכבדים ופוליטיקאים בארץ ובחו"ל ומעביר קורסים למשלחות המגיעות מטעם הקהילות היהודיות.
""")

                        divider()

                        sectionTitle("אקדמיה והכשרות:")

                        paragraph("""
אבי אבסידון מרכז תחום של אומנות לחימה במכללה האקדמית בוינגייט אשר כולל כל סוגי האומנות לחימה למיניהם.
במסגרת זו קיים קורסים שנתיים וקורסים מרוכזים עבור מדריכים, מאמנים ומאמנים בכירים.
""")

                        divider()

                        sectionTitle("שב\"ס:")

                        paragraph("אבי כיום מנחה את תוכנית ההדרכה של שירות בתי הסוהר ומעביר להם השתלמויות.")

                        divider()

                        sectionTitle("החזון של אבי אבסידון: העצמת שיטת ק.מ.י בארץ ובעולם.")

                        Spacer(minLength: 10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isDarkMode
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)

            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .kmiFont(size: 17, weight: .semibold)
            .foregroundStyle(primaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }

    private func paragraph(_ s: String) -> some View {
        Text(s)
            .kmiFont(size: 16, weight: .regular)
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }

    private func divider() -> some View {
        Divider()
            .overlay(
                isDarkMode
                    ? Color.white.opacity(0.12)
                    : Color.black.opacity(0.12)
            )
            .padding(.vertical, 4)
    }

    // MARK: - Haptics + Click sound (global-ish like Android)

    private func heavyHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred()
    }

    private func playClick() {
        // קצר, כמו clickSound
        AudioServicesPlaySystemSound(1104)
    }
}

// MARK: - Bullet row (כמו Bulleted באנדרואיד)
private struct Bulleted: View {
    let text: String

    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String) {
        self.text = text
    }

    private var textColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.78)
            : Color.black.opacity(0.82)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .kmiFont(size: 16, weight: .bold)
                .foregroundStyle(textColor)

            Text(text)
                .kmiFont(size: 16, weight: .regular)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    NavigationStack {
        AboutAviAbisidonView(onClose: { })
    }
}
