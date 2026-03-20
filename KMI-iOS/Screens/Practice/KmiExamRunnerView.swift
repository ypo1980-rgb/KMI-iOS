import SwiftUI

struct KmiExamRunnerView: View {

    let title: String
    let subtitle: String
    let items: [String]
    let accent: Color

    /// אופציונלי: אם רוצים לבצע פעולה מיוחדת בסיום (למשל nav.pop())
    let onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    @State private var isMuted: Bool = false

    init(
        title: String,
        subtitle: String,
        items: [String],
        accent: Color,
        onFinish: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.accent = accent
        self.onFinish = onFinish
    }

    private var total: Int { max(items.count, 1) }
    private var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(total)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 1.0),
                    Color(red: 0.92, green: 0.97, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    // כרטיס עליון
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.headline.weight(.heavy))
                                    .foregroundStyle(Color.black.opacity(0.78))
                                Text(subtitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                            }

                            Spacer()

                            Text("\(currentIndex + 1)/\(total)")
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.85))
                                )
                        }

                        ProgressView(value: progress)
                            .tint(accent)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.55))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // כרטיס שאלה
                    VStack(spacing: 12) {
                        if items.isEmpty {
                            Text("אין תרגילים זמינים")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.70))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            Text(items[currentIndex])
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.82))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)

                            HStack(spacing: 10) {
                                Button {
                                    isMuted.toggle()
                                    // אם יש אצלך TTS – פה המקום לעצור/להפעיל
                                    // KmiTtsManager.stop()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(accent)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle().fill(Color.white.opacity(0.90))
                                        )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    // דלג
                                    if currentIndex < items.count - 1 {
                                        currentIndex += 1
                                    }
                                } label: {
                                    Text("דלג")
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(accent.opacity(0.85))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.85))
                    )
                    .padding(.horizontal, 16)

                    // ✅ כפתור סיום מבחן (תמיד עובד)
                    Button {
                        finish()
                    } label: {
                        Text("סיום מבחן")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func finish() {
        // אם יש TTS/טיימרים אצלך – כאן לעצור אותם לפני יציאה
        // KmiTtsManager.stop()

        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}
