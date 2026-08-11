import SwiftUI
import AudioToolbox

struct AboutMethodView: View {

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

    private var tertiaryTextColor: Color {
        isDarkMode
            ? Color.white.opacity(0.64)
            : Color.black.opacity(0.65)
    }

    private var cardColor: Color {
        isDarkMode
            ? Color(hex: 0xFF111827).opacity(0.97)
            : Color.white
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // רקע (כמו שאר מסכי SideDrawer)
            LinearGradient(
                colors: isDarkMode
                    ? [
                        Color(red: 0.07, green: 0.10, blue: 0.23),
                        Color(red: 0.01, green: 0.05, blue: 0.14),
                        Color(red: 0.11, green: 0.33, blue: 0.80)
                    ]
                    : [
                        Color(hex: 0xFFF8FBFF),
                        Color(hex: 0xFFEAF4FF),
                        Color(hex: 0xFFB7DDF7),
                        Color(hex: 0xFF1F78B4)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Card
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .trailing, spacing: 12) {

                        paragraph("""
קרב מגן ישראלי - ק.מ.י שיטת לחימה ישראלית
מטרת ק.מ.י הגנה עצמית והתמודדות בקרב פנים אל פנים. השיטה פותחה מתוך קרב המגע ויוסדה ע"י אלי אביקזר בשנת 1989.

לאחר פטירת המייסד בשנת 2004 נבחר אבי אביסידון לראש השיטה וליו"ר עמותת ק.מ.י.

שיטת ק.מ.י. מבוססת על התנועות הטבעיות של גוף האדם ומצטיינת בפשטותה, במהירותה וביעילותה.

משמעות השם קרב מגן ישראלי:
"קרב מגן" - מטרת התרגילים והקרב להגן על החיים. "ישראלי" - המקצוע פותח בישראל ולאלי אביקזר היה חשוב שהשיטה שפיתח, תישא את שם מדינת ישראל בפי כל מתאמן, או מתעניין.
השם "קרב מגן ישראלי" מסמל אפוא את השיטה.
""")

                        Spacer(minLength: 6)

                        sectionTitle("האידיאולוגיה של ק.מ.י מאופיינת בכללים:")
                        Bulleted("לא להיפגע.")
                        Bulleted("פעל לפי יכולתך, אך פעל נכון.")
                        Bulleted("השתמש בידע לפי הצורך.")
                        Bulleted("הדרך הפשוטה — הקצרה ביותר והמהירה ביותר.")

                        Spacer(minLength: 6)

                        paragraph("""
שיטת ק.מ.י. מאושרת ע"י המכללת האקדמית בוינגייט. מורים לחינוך גופני משתלמים במכללת האקדמית בוינגייט בקורסים להגנה עצמית מטעם ק.מ.י. השיטה הומלצה לנעמ"ת ע"י משטרת ישראל להעברת סדנאות להגנה עצמית לנערות ולנשים. שיטת ק.מ.י. משמשת בזרועות הביטחון השונים ומבוקשת ברחבי העולם. שיטת ק.מ.י. זכתה להכרה בין לאומית.
""")

                        Spacer(minLength: 6)

                        sectionTitle("קרב מגן ישראלי - ק.מ.י., מתמקד בשני תחומים:")
                        bulletTitle("הגנה עצמית הכוללת:")
                        bulletSub("הדרכה בזיהוי מוקדי אלימות והתרחקות מהם; חינוך לריסון עצמי; תרגילים להגנה עצמית ולהימום התוקף; התאמה לבנות ובנים, נשים וגברים, קשישים ומוגבלים.")
                        bulletTitle("קרב פנים אל פנים:")
                        bulletSub("כאשר תרגיל ההגנה העצמית לא הושלם והתוקף ממשיך בתקיפה — עוברים לקרב קצר, ממוקד ויעיל עד ניטרול האיום.")

                        Spacer(minLength: 6)

                        sectionTitle("התרגילים הנלמדים בשיטת ק.מ.י:")
                        Bulleted("הגנות נגד מכות שונות.")
                        Bulleted("הגנות נגד בעיטות שונות; מכות ובעיטות להימום התוקף.")
                        Bulleted("שחרורים מתפיסות ידיים/שיער/חולצה, מחביקות ומחניקות (גם בקרקע).")
                        Bulleted("התמודדות והגנות מול תוקף חמוש — מקל, סכין, אקדח.")
                        Bulleted("תרגילים נוספים וקרבות מול תוקף אחד או יותר.")
                        Bulleted("סדנאות להגנה עצמית לנשים.")

                        Spacer(minLength: 6)

                        sectionTitle("עקרון הפשטות")
                        paragraph("""
התרגילים בק.מ.י פותחו על עקרון הפשטות: תנועה טבעית, פשוטה, הינה תנועה מהירה. תנועה מהירה מפיקה עוצמה. שימוש בתנועה בסיסית ולא מסורבלת מהווה מינימום תנועת הגנה נגד מקסימום תנועת התקפה ומאפשר לכל אדם יכולת הגנה עצמית והימום התוקף.

מכאן המשפט שטבע אלי אביקזר: "מינימום הגנה נגד מקסימום התקפה".
""")

                        Spacer(minLength: 6)

                        sectionTitle("פילוסופיה מעשית ומתעדכנת")
                        paragraph("""
בניגוד לשיטות לחימה מסורתיות, ק.מ.י. מתאים עצמו למציאות המשתנה ברחוב ולסכנות המידיות. ק.מ.י. מחדש, משפר, מוסיף או גורע תרגילים ומציע פתרונות עדכניים. השלמות היא שאיפה — אך המטרה היא שמירת החיים, שליטה וריסון עצמי.
""")

                        Spacer(minLength: 6)

                        sectionTitle("דירוג חגורות")
                        paragraph("לבן, צהוב, כתום, ירוק, כחול, חום, שחור: דאן 1–2; פסים אדום־לבן: דאן 3–4; קטעים אדום־שחור: דאן 5; קטעים אדום־לבן: דאן 6–7; אדום: דאן 8–10.")

                        Spacer(minLength: 6)

                        sectionTitle("הסמכות והכשרות המדריכים ברשת נוקאאוט")
                        Bulleted("תואר ראשון/שני בחינוך גופני; תנועה לגיל הרך.")
                        Bulleted("קורסי מדריכי ירי; אבטחת אישים; לחימה ופיקוד בזרועות הביטחון.")
                        Bulleted("ידע בשיטות לחימה שונות; סדנאות ופעילות ייעודית לנשים.")
                        Bulleted("מועדונים בארץ ובעולם; אימונים מגיל 4 ומעלה; התאמות למוגבלויות.")

                        Spacer(minLength: 6)

                        sectionTitle("השפעה חינוכית וחברתית")
                        paragraph("מתאמני ק.מ.י מציינים שיפור בתנועה ובקואורדינציה, עלייה בביטחון האישי והעצמי, אומץ לב, קור רוח, משמעת ושליטה עצמית, והתרחקות ממוקדי אלימות.")

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
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
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI helpers

    private func paragraph(_ s: String) -> some View {
        Text(s)
            .kmiFont(size: 16, weight: .regular)
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .kmiFont(size: 17, weight: .semibold)
            .foregroundStyle(primaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            .padding(.top, 2)
    }

    private func bulletTitle(_ s: String) -> some View {
        Text(s)
            .kmiFont(size: 17, weight: .semibold)
            .foregroundStyle(primaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            .padding(.top, 2)
    }

    private func bulletSub(_ s: String) -> some View {
        Text("–  \(s)")
            .kmiFont(size: 15, weight: .regular)
            .foregroundStyle(tertiaryTextColor)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            .padding(.trailing, 10)
    }

    // MARK: - Haptics + Click

    private func heavyHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred()
    }

    private func playClick() {
        AudioServicesPlaySystemSound(1104)
    }
}

// MARK: - Bullets
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
        .padding(.vertical, 2)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    NavigationStack {
        AboutMethodView(onClose: {})
    }
}
