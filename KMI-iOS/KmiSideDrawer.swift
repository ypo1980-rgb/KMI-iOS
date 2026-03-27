import SwiftUI
import FirebaseAuth

// MARK: - Drawer Item Model
struct KmiDrawerItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
}

// MARK: - Drawer UI
struct KmiSideDrawer: View {

    @EnvironmentObject private var auth: AuthViewModel

    let onClose: () -> Void
    let onSelect: (KmiDrawerItem) -> Void

    private var effectiveRole: String {
        let loginRole = UserDefaults.standard.string(forKey: "user_role")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let loginRole, !loginRole.isEmpty {
            print("DRAWER ROLE (from defaults) =", loginRole)
            return loginRole
        }

        let profileRole = auth.userRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        print("DRAWER ROLE (from profile) =", profileRole)
        return profileRole
    }

    private var isCoach: Bool {
        effectiveRole == "coach" || effectiveRole == "trainer" || effectiveRole == "מאמן"
    }

    private var isAdminUser: Bool {
        let email = Auth.auth().currentUser?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return email == "ypo1980@gmail.com"
    }

    private var coachItems: [KmiDrawerItem] {
        var items: [KmiDrawerItem] = []

        if isCoach {
            items.append(contentsOf: [
                .init(title: "דו״ח נוכחות", subtitle: nil),
                .init(title: "שליחת הודעה", subtitle: nil),
                .init(title: "רשימת מתאמנים", subtitle: nil),
                .init(title: "מבחן פנימי לחגורה", subtitle: nil)
            ])
        }

        if isAdminUser {
            items.append(
                .init(title: "ניהול משתמשים", subtitle: "צפייה בכל המשתמשים")
            )
        }

        return items
    }
    
    private var items: [KmiDrawerItem] {

        var base: [KmiDrawerItem] = [
            .init(title: "אודות אבי אביסידון", subtitle: "ראש השיטה"),
            .init(title: "אודות איציק ביטון", subtitle: "מאמן בכיר"),
            .init(title: "אודות הרשת", subtitle: "נוקאאוט"),
            .init(title: "אודות השיטה", subtitle: "ק.מ.י"),
            .init(title: "פורום הסניף", subtitle: nil),
            .init(title: "ניהול מנוי", subtitle: nil),
            .init(title: "⭐ דרגו אותנו ⭐", subtitle: nil)
        ]

        base.append(.init(title: "התנתקות", subtitle: nil))

        return base
    }
    
    var body: some View {
        ZStack {
            // background panel
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.20),
                    Color(red: 0.06, green: 0.16, blue: 0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // top row (X)
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.95))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.top, 6)
                .padding(.horizontal, 12)

                ScrollView {
                    VStack(spacing: 12) {

                        if !coachItems.isEmpty {
                            ForEach(coachItems) { it in
                                drawerButton(it, isCoachButton: true)
                            }

                            Divider()
                                .overlay(Color.white.opacity(0.22))
                                .padding(.top, 6)
                                .padding(.bottom, 10)
                        }

                        ForEach(items) { it in
                            drawerButton(it, isCoachButton: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func drawerButton(_ it: KmiDrawerItem, isCoachButton: Bool) -> some View {
        Button {

            if it.title == "התנתקות" {
                auth.signOut()
            }

            onSelect(it)

        } label: {
            VStack(spacing: 4) {
                Text(it.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)

                if let sub = it.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isCoachButton
                        ? Color(red: 0.92, green: 0.44, blue: 0.70)
                        : Color.white.opacity(0.10)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isCoachButton
                        ? Color.white.opacity(0.00)
                        : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Container (wrap any screen)
struct KmiSideDrawerContainer<Content: View>: View {
    @Binding var isOpen: Bool
    let content: Content
    let onItem: (KmiDrawerItem) -> Void

    init(
        isOpen: Binding<Bool>,
        onItem: @escaping (KmiDrawerItem) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._isOpen = isOpen
        self.onItem = onItem
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.82, 320)

            ZStack(alignment: .leading) {
                content
                    .overlay {
                        if isOpen {
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .zIndex(1)
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        isOpen = false
                                    }
                                }
                        }
                    }
                    .simultaneousGesture(edgeOpenGesture())
                    .disabled(isOpen)

                if isOpen {
                    KmiSideDrawer(
                        onClose: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                        },
                        onSelect: { item in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isOpen = false
                            }
                            onItem(item)
                        }
                    )
                    .frame(width: drawerWidth)
                    .transition(.move(edge: .leading))
                    .zIndex(2)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isOpen)
        }
    }

    private func edgeOpenGesture() -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                // פתיחה רק אם מתחילים ממש בקצה שמאל
                if !isOpen, value.startLocation.x < 18, value.translation.width > 60 {
                    isOpen = true
                }
                // סגירה אם פתוח וגוררים שמאלה
                if isOpen, value.translation.width < -60 {
                    isOpen = false
                }
            }
    }
}
