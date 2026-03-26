import SwiftUI

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

        // פריטים למאמן בלבד
        if auth.userRole == "coach" {
            base.insert(
                .init(title: "ניהול משתמשים", subtitle: "צפייה בכל המשתמשים"),
                at: 0
            )
        }

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
                        ForEach(items) { it in
                            Button {

                                if it.title == "התנתקות" {
                                    auth.signOut()
                                }

                                onSelect(it)

                            } label: {                                VStack(spacing: 4) {
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
                                        .fill(Color.white.opacity(0.10))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }

                Spacer(minLength: 0)
            }
        }
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
