import SwiftUI

struct HomeFloatingMenu: View {

    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let action: () -> Void
    }

    let items: [Item]
    @State private var isOpen: Bool = false

    var body: some View {
        Group {
            if isOpen {
                // ✅ מצב פתוח: overlay מסך מלא (חוסם טאפים בכוונה)
                ZStack(alignment: .bottom) {

                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                isOpen = false
                            }
                        }

                    VStack(spacing: 10) {
                        VStack(spacing: 10) {
                            ForEach(items) { item in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        isOpen = false
                                    }
                                    item.action()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: item.systemImage)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.70))

                                        Text(item.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.black.opacity(0.80))

                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.92))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)

                        fabButton
                            .padding(.bottom, 22)
                    }
                }
            } else {
                // ✅ מצב סגור: *רק* ה-FAB. לא מסך מלא => לא חוסם טאפים לכפתורים מתחת.
                fabButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 22)
                    .padding(.horizontal, 18)
                    .allowsHitTesting(true)
            }
        }
    }

    private var fabButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                isOpen.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .rotationEffect(.degrees(isOpen ? 45 : 0))
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
    }
}
