import SwiftUI

// MARK: - KmiIconStripBar

enum KmiIconStripItem: CaseIterable, Identifiable {
    case share, assistant, settings, home, search

    var id: String { title }

    var systemName: String {
        switch self {
        case .share:     return "square.and.arrow.up"
        case .assistant: return "lightbulb"
        case .settings:  return "gearshape"
        case .home:      return "house.fill"
        case .search:    return "magnifyingglass"
        }
    }

    var title: String {
        switch self {
        case .share:     return "שתף"
        case .assistant: return "עוזר"
        case .settings:  return "הגדרות"
        case .home:      return "בית"
        case .search:    return "חיפוש"
        }
    }
}

struct KmiIconStripBar: View {

    let items: [KmiIconStripItem]
    let selected: KmiIconStripItem?          // ✅ NEW
    let onTap: (KmiIconStripItem) -> Void

    var body: some View {
        VStack(spacing: 0) {

            Divider().opacity(0.18)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    let isSelected = (selected == item)

                    Button {
                        onTap(item)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.systemName)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(height: 18)
                                .foregroundStyle(isSelected ? Color.purple.opacity(0.95)
                                                           : Color.black.opacity(0.70))

                            Text(item.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(isSelected ? Color.purple.opacity(0.95)
                                                           : Color.black.opacity(0.70))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.purple.opacity(0.12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white.opacity(0.92))

            Divider().opacity(0.18)
        }
    }
}

#Preview {
    KmiIconStripBar(
        items: KmiIconStripItem.allCases,
        selected: .home
    ) { _ in }
}
