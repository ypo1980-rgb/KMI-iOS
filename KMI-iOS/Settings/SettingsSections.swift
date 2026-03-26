import SwiftUI

// MARK: - SettingsCard
struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let iconSystemName: String?
    let iconTint: Color?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        iconSystemName: String? = nil,
        iconTint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.iconTint = iconTint
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let iconSystemName {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill((iconTint ?? .accentColor).opacity(0.12))
                            .frame(width: 34, height: 34)

                        Image(systemName: iconSystemName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconTint ?? .accentColor)
                    }
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .lineLimit(2)
                    }
                }
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - KmiSegmentedTabsInt
struct KmiSegmentedTabsInt: View {
    let options: [Int]
    @Binding var selected: Int
    let label: (Int) -> String
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                let isSel = opt == selected

                Button {
                    selected = opt
                    onSelect(opt)
                } label: {
                    Text(label(opt))
                        .font(.system(size: 13, weight: isSel ? .bold : .semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .padding(.vertical, 8)
                        .foregroundStyle(isSel ? Color.white : Color.primary)
                        .background(isSel ? Color.accentColor : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - KmiVoiceTabs
struct KmiVoiceTabs: View {
    @Binding var voice: String
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            voiceButton("male", "קול גבר")
            voiceButton("female", "קול אישה")
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func voiceButton(_ value: String, _ text: String) -> some View {
        let selected = voice == value

        return Button {
            voice = value
            onChanged()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - KmiThemeTabs
struct KmiThemeTabs: View {
    @Binding var themeMode: String
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            themeButton("light", "מצב\nבהיר")
            themeButton("dark", "מצב\nכהה")
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func themeButton(_ mode: String, _ text: String) -> some View {
        let selected = themeMode == mode

        return Button {
            themeMode = mode
            onChanged()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - KmiLockTabs
struct KmiLockTabs: View {
    @Binding var lockMode: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            lockButton("none", "ללא\nנעילה")
            lockButton("biometric", "נעילה\nבאצבע")
            lockButton("pin", "נעילה\nבסיסמה")
        }
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func lockButton(_ mode: String, _ text: String) -> some View {
        let selected = lockMode == mode

        return Button {
            lockMode = mode
            onSelect(mode)
        } label: {
            Text(text)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LegalTile
struct LegalTile: View {
    let title: String
    let subtitle: String
    let systemIcon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BeltsProgressBarsIOS
struct BeltRow: Identifiable {
    let id = UUID()
    let title: String
    let pct: Int
    let color: Color
}

struct BeltsProgressBarsIOS: View {
    let rows: [BeltRow]

    var body: some View {
        GeometryReader { geo in
            let barMaxWidth = geo.size.width

            VStack(spacing: 10) {
                ForEach(rows) { row in
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(row.pct)%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.title.contains("שחורה") ? Color.primary : row.color)

                            Spacer()

                            Text(row.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.title.contains("שחורה") ? Color.primary : row.color)
                        }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(row.color)
                                .frame(
                                    width: max(0, min(100, CGFloat(row.pct))) / 100.0 * barMaxWidth,
                                    height: 12
                                )
                        }
                    }
                }
            }
        }
        .frame(height: CGFloat(max(rows.count, 1)) * 36)
    }
}
