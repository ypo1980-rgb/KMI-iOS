import SwiftUI
import AudioToolbox

struct AboutAviAbisidonView: View {

    let onClose: () -> Void

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
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().opacity(0.8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

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

                        Text("בידיו התעודות הבאות:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

                        Bulleted("„מדריך קרב מגע\" מטעם מכון וינגייט - בי\"ס למאמנים.")
                        Bulleted("„מאמן באומנויות לחימה\" מטעם מכון וינגייט - בי\"ס למאמנים.")
                        Bulleted("„מורה בכיר באומנויות לחימה\" מטעם המכללה האקדמית בוינגייט ע\"ש זינמן.")

                        paragraph("משנת 1991 מלמד אבי קורסים לקרב מגן ישראלי במכללה האקדמית בוינגייט.")

                        divider()

                        Text("ניסיון צבאי וביטחוני:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

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

                        Text("פעילות בינלאומית:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

                        paragraph("""
אבי מעורב בהכנת מאבטחים אישיים עבור נכבדים ופוליטיקאים בארץ ובחו"ל ומעביר קורסים למשלחות המגיעות מטעם הקהילות היהודיות.
""")

                        divider()

                        Text("אקדמיה והכשרות:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

                        paragraph("""
אבי אבסידון מרכז תחום של אומנות לחימה במכללה האקדמית בוינגייט אשר כולל כל סוגי האומנות לחימה למיניהם.
במסגרת זו קיים קורסים שנתיים וקורסים מרוכזים עבור מדריכים, מאמנים ומאמנים בכירים.
""")

                        divider()

                        Text("שב\"ס:")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

                        paragraph("אבי כיום מנחה את תוכנית ההדרכה של שירות בתי הסוהר ומעביר להם השתלמויות.")

                        divider()

                        Text("החזון של אבי אבסידון: העצמת שיטת ק.מ.י בארץ ובעולם.")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.88))

                        Spacer(minLength: 10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)

            // כפתור X צף
            Button {
                playClick()
                heavyHaptic()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.white.opacity(0.92))
                    )
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 22)
            .padding(.top, 22)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI helpers

    private func paragraph(_ s: String) -> some View {
        Text(s)
            .font(.body)
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    private func divider() -> some View {
        Divider().opacity(0.7).padding(.vertical, 4)
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
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
                .foregroundStyle(Color.black.opacity(0.82))

            Text(text)
                .font(.body)
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        AboutAviAbisidonView(onClose: { })
    }
}
