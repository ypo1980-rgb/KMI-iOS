import SwiftUI

struct SideDrawerContainer<Content: View>: View {

    @ObservedObject var drawer: SideDrawerState
    let items: [SideDrawerItem]
    let onSelect: (SideDrawerItem) -> Void
    let onClose: () -> Void
    let content: Content

    init(
        drawer: SideDrawerState,
        items: [SideDrawerItem],
        onSelect: @escaping (SideDrawerItem) -> Void,
        onClose: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.drawer = drawer
        self.items = items
        self.onSelect = onSelect
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if drawer.isOpen {

                // ✅ Overlay לסגירה: מאחורי התפריט
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        drawer.close()
                        onClose()
                    }
                    .zIndex(1)

                // ✅ התפריט: מעל ה-overlay כדי לקבל טאצ׳ים
                SideDrawerMenuView(
                    items: items,
                    onSelect: { item in
                        // קודם לסגור, ואז לנווט בפריים הבא
                        drawer.close()
                        onClose()

                        DispatchQueue.main.async {
                            onSelect(item)
                        }
                    },
                    onClose: {
                        drawer.close()
                        onClose()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: drawer.isOpen)
    }
}
