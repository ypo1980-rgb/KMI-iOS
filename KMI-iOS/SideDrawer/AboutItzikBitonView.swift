import SwiftUI
import AudioToolbox

struct AboutItzikBitonView: View {

    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // רקע כהה כמו ה-Drawer screens
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

                Text("איציק ביטון – מייסד נוקאאוט, דאן 5")
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
איציק ביטון הינו מאמן קרב מגן ישראלי ומאמן אומנויות לחימה בנתניה, מוסמך מטעם המכללה האקדמית בוינגייט. עוסק בתחום מאז 1997.

את דרכו החל אצל המאמן רפי אלגריסי, מתלמידיו הבכירים של אימי ליכטנפלד. אצל רפי התמחה בקרב מגע וכמקצוע משני באייקידו.

ב־2004 הצטרף לעמותת ק.מ.י; ב־2005 השלים קורס מדריכים בוינגייט וקיבל חגורה שחורה מאבי אביסידון ורפי אלגריסי. ב־2006 פתח את סניף נוקאאוט הראשון בנתניה.

לאורך השנים הדריך מסגרות ביטחוניות שונות (שב״ס, המכללה לפיקוד טקטי בצה״ל, מוסדות לבריאות הנפש) ומכשיר מאבטחים. לוקח חלק קבוע בקורסי מדריכים בוינגייט, ומאז 2009 גם מאמן אומנויות לחימה מוסמך.

ב־2005 החל להתאמן בנינג׳יטסו אצל שיהאן משה קסטיאל (דאן 10) ולמד רפואה משלימה – אוסטיאופתיה. כיום מנהל את רשת נוקאאוט עם מאות מתאמנים, עשרות חגורות שחורות ומדריכים מוסמכים.
""")

                        Spacer(minLength: 6)

                        sectionTitle("תחומי עשייה נוספים")
                        Bulleted("עבודה חינוכית עם נוער, ילדים בסיכון ואוכלוסיות מיוחדות.")
                        Bulleted("בניית תכניות מותאמות לארגונים, לבתי־ספר ולחברות.")
                        Bulleted("רקע נוסף: BJJ, איגרוף ו־MMA.")

                        Spacer(minLength: 6)

                        sectionTitle("מאמנים שהשפיעו עליו")
                        Bulleted("רן סודאי, ארז שרעבי, ג׳ון אסקודרו, רון רותם.")

                        Spacer(minLength: 6)

                        sectionTitle("סניפי רשת נוקאאוט (מבחר)")
                        Bulleted("מרכז קהילתי אופק, שיכון מזרחי, נורדאו, נאות שקד, קריית השרון (נתניה).")
                        Bulleted("כפר יעבץ (עזריאל), בני ברק, פתח תקווה, הרצליה – נווה עמל.")
                        Bulleted("סניף צופים, סוקולוב ואחרים.")

                        Spacer(minLength: 18)
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

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.top, 2)
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
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AboutItzikBitonView(onClose: {})
    }
}
