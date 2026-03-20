import SwiftUI

struct SideDrawerMenuView: View {

    let items: [SideDrawerItem]
    let onSelect: (SideDrawerItem) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 12) {

                HStack {
                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImage)
                                .frame(width: 26)

                            Text(item.title)
                                .font(.system(size: 18, weight: .heavy))

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
            .frame(width: min(geo.size.width * 0.50, 320))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.top, 14)
        }
    }
}
