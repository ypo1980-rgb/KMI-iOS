import SwiftUI
import UserNotifications

struct FreeSessionDetailsSheet: View {

    @ObservedObject var vm: FreeSessionsViewModel
    let session: FreeSession
    let currentUid: String
    let onClose: () -> Void

    private var myState: ParticipantState? {
        vm.myState(in: session.id)
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 18) {

                    sessionInfoCard

                    statusSelector

                    participantsList

                    actionButtons

                }
                .padding()

            }

            .navigationTitle("פרטי אימון")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") {
                        onClose()
                    }
                }
            }
        }
    }
}

extension FreeSessionDetailsSheet {

    private var sessionInfoCard: some View {

        VStack(alignment: .trailing, spacing: 8) {

            Text(session.title)
                .font(.title3.bold())

            Text("נוצר ע״י \(session.createdByName)")
                .foregroundStyle(.secondary)

            Label(fmtTimeHeb(session.startsAt), systemImage: "calendar")

            if let location = session.locationName, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
            }

        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var statusSelector: some View {

        VStack(alignment: .trailing, spacing: 12) {

            Text("הסטטוס שלי")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))]) {

                ForEach(ParticipantState.allCases) { state in

                    Button {

                        Task {
                            await vm.setMyState(
                                sessionId: session.id,
                                state: state
                            )
                        }

                    } label: {

                        Text(state.titleHeb)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(
                                myState == state
                                ? Color.blue
                                : Color(.systemGray5)
                            )
                            .foregroundStyle(
                                myState == state ? .white : .primary
                            )
                            .clipShape(Capsule())

                    }

                }

            }

        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var participantsList: some View {

        VStack(alignment: .trailing, spacing: 10) {

            Text("משתתפים")
                .font(.headline)

            if vm.participants.isEmpty {

                Text("אין עדיין משתתפים")
                    .foregroundStyle(.secondary)

            } else {

                ForEach(vm.participants) { part in

                    HStack {

                        Text(part.state.titleHeb)
                            .font(.caption.bold())
                            .padding(6)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())

                        Spacer()

                        Text(part.name)
                            .font(.body)

                    }

                }

            }

        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var actionButtons: some View {

        VStack(spacing: 10) {

            Button {
                openNavigation()
            } label: {
                Label("פתח ניווט", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)

            Button {
                shareSession()
            } label: {
                Label("שתף ב-WhatsApp", systemImage: "paperplane.fill")
            }
            .buttonStyle(.bordered)

            Button {
                scheduleReminder()
            } label: {
                Label("תזכורת לאימון", systemImage: "bell.fill")
            }
            .buttonStyle(.bordered)

            if vm.canManage(session) {

                Button(role: .destructive) {
                    Task { await vm.deleteSession(sessionId: session.id) }
                } label: {
                    Text("מחק אימון")
                }

            }

        }

    }
}

extension FreeSessionDetailsSheet {

    private func shareSession() {

        let message =
"""
אימון קרב מגן ישראלי 💪

\(session.title)

🕒 \(fmtTimeHeb(session.startsAt))
📍 \(session.locationName ?? "")

מוזמנים להצטרף!
"""

        let encoded = message.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""

        if let url = URL(string: "https://wa.me/?text=\(encoded)") {
            UIApplication.shared.open(url)
        }

    }

    private func openNavigation() {

        if let lat = session.lat, let lng = session.lng {

            let waze = URL(string: "waze://?ll=\(lat),\(lng)&navigate=yes")

            if let waze, UIApplication.shared.canOpenURL(waze) {
                UIApplication.shared.open(waze)
                return
            }

            if let apple = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)") {
                UIApplication.shared.open(apple)
            }

        }

    }

    private func scheduleReminder() {

        let content = UNMutableNotificationContent()

        content.title = "אימון קרב מגן ישראלי"
        content.body = session.title

        let fireDate = Date(
            timeIntervalSince1970: TimeInterval(session.startsAt / 1000)
        ).addingTimeInterval(-1800)

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: fireDate.timeIntervalSinceNow,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: session.id,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func fmtTimeHeb(_ millis: Int64) -> String {

        let date = Date(timeIntervalSince1970: TimeInterval(millis)/1000)

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.dateFormat = "EEEE · d.M.yyyy · HH:mm"

        return fmt.string(from: date)
    }
}
