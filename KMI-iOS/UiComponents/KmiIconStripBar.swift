
import SwiftUI

// MARK: - KmiIconStripBar

enum KmiIconStripItem: CaseIterable, Identifiable {
    case share, assistant, settings, home, search

    var id: String {
        rawKey
    }

    var rawKey: String {
        switch self {
        case .share:     return "share"
        case .assistant: return "assistant"
        case .settings:  return "settings"
        case .home:      return "home"
        case .search:    return "search"
        }
    }

    var systemName: String {
        switch self {
        case .share:     return "square.and.arrow.up"
        case .assistant: return "lightbulb"
        case .settings:  return "gearshape"
        case .home:      return "house.fill"
        case .search:    return "magnifyingglass"
        }
    }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .share:
            return isEnglish ? "Share" : "שתף"
        case .assistant:
            return isEnglish ? "Assistant" : "עוזר"
        case .settings:
            return isEnglish ? "Settings" : "הגדרות"
        case .home:
            return isEnglish ? "Home" : "בית"
        case .search:
            return isEnglish ? "Search" : "חיפוש"
        }
    }
}

struct KmiIconStripBar: View {

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    let items: [KmiIconStripItem]
    let selected: KmiIconStripItem?
    let onTap: (KmiIconStripItem) -> Void

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = (selected == item)

                Button {
                    onTap(item)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemName)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(height: 18)
                            .foregroundStyle(
                                isSelected
                                ? Color.purple.opacity(0.95)
                                : Color.black.opacity(0.70)
                            )

                        Text(item.title(isEnglish: isEnglish))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .foregroundStyle(
                                isSelected
                                ? Color.purple.opacity(0.95)
                                : Color.black.opacity(0.70)
                            )
                    }
                    .frame(width: isEnglish ? 70 : 64)
                    .padding(.vertical, 8)
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
        .background(Color.clear)
        .environment(\.layoutDirection, .leftToRight)
    }
}

#Preview {
    KmiIconStripBar(
        items: KmiIconStripItem.allCases,
        selected: .home
    ) { _ in }
}
