import SwiftUI

struct DailyReminderCardView: View {
    @EnvironmentObject private var center: DailyReminderCenter
    let payload: DailyReminderPayload

    @State private var localPayload: DailyReminderPayload
    @State private var isFavorite: Bool

    init(payload: DailyReminderPayload) {
        self.payload = payload
        _localPayload = State(initialValue: payload)
        _isFavorite = State(initialValue: DailyReminderFavoritesStore.contains(payload.item))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("התרגיל היומי שלך")
                        .font(.system(size: 24, weight: .heavy))

                    Spacer()

                    Button {
                        isFavorite.toggle()
                        DailyReminderFavoritesStore.set(localPayload.item, favorite: isFavorite)
                    } label: {
                        Text(isFavorite ? "★" : "☆")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }

                Text("\(localPayload.beltHeb) • \(localPayload.topic)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(localPayload.item)
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text(localPayload.explanation)
                    .font(.system(size: 15, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                if localPayload.extraCount < 3 {
                    Button {
                        if let next = DailyReminderScheduler.shared.makeAnotherPayload(from: localPayload) {
                            localPayload = next
                            isFavorite = DailyReminderFavoritesStore.contains(next.item)
                        }
                    } label: {
                        Text("תרגיל נוסף להיום")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 12) {
                    Button {
                        center.dismiss()
                    } label: {
                        Text("סגור")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        center.dismiss()
                    } label: {
                        Text("מעבר לאפליקציה")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(20)
        }
    }
}
