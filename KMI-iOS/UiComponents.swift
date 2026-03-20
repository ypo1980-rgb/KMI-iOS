import SwiftUI

// MARK: - Icon Strip Row (shared)

struct IconStripRow: View {
    struct Item {
        let system: String
        let title: String
    }

    let items: [Item]
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 22) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                Button {
                    onTap(idx)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: it.system)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.75))
                        Text(it.title)
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.70))
                    }
                    .frame(minWidth: 46)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.92))
    }
}

// MARK: - Segmented Tabs (shared)

struct SegmentedTabs: View {
    enum Selection { case left, right }

    let leftTitle: String
    let rightTitle: String
    let selected: Selection
    let onSelect: (Selection) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 0) {
                tabButton(title: leftTitle, isSelected: selected == .left) {
                    onSelect(.left)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1)

                tabButton(title: rightTitle, isSelected: selected == .right) {
                    onSelect(.right)
                }
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 2)
    }

    private func tabButton(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.80))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.52, green: 0.26, blue: 0.95),
                                            Color(red: 0.36, green: 0.18, blue: 0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(3)
                                .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - White Card (shared)

struct WhiteCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}
