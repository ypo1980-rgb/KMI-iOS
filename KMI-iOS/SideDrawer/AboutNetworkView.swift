//
//  AboutNetworkView.swift
//  KMI-iOS
//
//  SideDrawer Screen: "אודות הרשת"
//

import SwiftUI
import AudioToolbox

struct AboutNetworkView: View {

    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // רקע (כמו שאר מסכי SideDrawer)
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

            // Card
            VStack(spacing: 0) {

                Text("בית ספר לקרב מגע והגנה עצמית")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().opacity(0.8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        paragraph("""
רשת נוקאאוט הוקמה בשנת 2010 מתוך רצון שכל אדם ידע להגן על עצמו מפני הסכנות הנמצאות כיום ברחוב. המדריכים ברשת מעבירים אימונים במסגרות שונות ומגוונות כגון מכינות קדם צבאיות, מרכזים להכשרות מאבטחים, מרכזי גמילה מסמים ואלכוהול, פרויקטים לנוער בסיכון, בתי ספר לחינוך מיוחד, מרכזים קהילתיים ועוד. הרשת שלנו כוללת סניפים רבים ברחבי הארץ כגון בנתניה, פרדס חנה, צופים, כפר יעבץ, פורת ועוד.

הייחודיות שלנו היא לקחת תרגיל לחימה ולהקביל אותו למצב בחיים וללמוד איך להתמודד עם המצב בחיי היום־יום ולא רק בלחימה.
""")

                        Spacer(minLength: 6)

                        sectionTitle("קרב מגע מעניין אתכם? מוזמנים לקרוא עוד בנושא:")
                        Spacer(minLength: 2)
                        Bulleted("הגנה תומכת לכל האוכלוסיות ובכל הגילאים")
                        Bulleted("תורם לילדים עם ADHD וכיו\"ב – מיקוד ומשמעת עצמית")
                        Bulleted("מגבש קבוצה ובונה ביטחון עצמי")

                        Spacer(minLength: 6)

                        paragraph("""
המדריכים ברשת נוקאאוט מתמחים בעבודה עם ילדים ומעבירים את החומר בדרכים חווייתיות כגון משחקי קרב, תחרויות וסימולציות.

המטרה העיקרית אצלנו באימונים היא קודם כל להפוך את החניך לאדם טוב שמכבד ועוזר לכל אדם. בתוך כך אנו מכניסים משמעת, ביטחון עצמי, שליטה, ריסון וקבלת השונה. במהלך השגת מטרה זו אנו כמובן מתייחסים לפן ההגנה העצמית והלחימה.

הדרך שלנו בתחום זה היא להביא את המציאות שברחוב לאימונים וללמד את התלמיד לצמצם את ההלם הראשוני עד כמה שאפשר ולפעול כפי יכולתו בהתאם למצב.
""")

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)

            // כפתור X אחיד (כמו שאר המסכים)
            Button {
                playClick()
                heavyHaptic()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.92)))
                    .overlay(Circle().stroke(Color.black.opacity(0.10), lineWidth: 1))
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
        AboutNetworkView(onClose: {})
    }
}
