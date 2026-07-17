import SwiftUI
import Shared

struct GlobalExerciseSearchSheet_Legacy: View {

    let initialQuery: String
    let onPick: (ExerciseSearchHit) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var engine =
        GlobalExerciseSearchEngine.shared

    @AppStorage("kmi_app_language")
    private var kmiAppLanguageCode: String = "he"

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = "he"

    @State private var query: String
    @State private var beltFilter: Belt? = nil
    @State private var results: [ExerciseSearchHit] = []

    init(
        initialQuery: String = "",
        onPick: @escaping (ExerciseSearchHit) -> Void
    ) {
        let cleanQuery =
            initialQuery.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        self.initialQuery = cleanQuery
        self.onPick = onPick
        _query = State(initialValue: cleanQuery)
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }

    private var screenLayoutDirection:
        LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchControls
                resultsContent
            }
            .navigationTitle(
                tr(
                    "חיפוש תרגיל",
                    "Exercise Search"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarLeading
                ) {
                    Button(
                        tr("סגור", "Close")
                    ) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                engine.ensureBuilt()
                refresh()
            }
            .onChange(of: query) { _, _ in
                refresh()
            }
            .onChange(of: beltFilter) { _, _ in
                refresh()
            }
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
    }

    private var searchControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(
                    systemName: "magnifyingglass"
                )
                .font(.headline)
                .foregroundStyle(
                    Color(hex: 0xFF10B981)
                )

                TextField(
                    tr(
                        "חפש תרגיל…",
                        "Search exercise…"
                    ),
                    text: $query
                )
                .textInputAutocapitalization(
                    .never
                )
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    refresh()
                }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .font(.title3)
                        .foregroundStyle(
                            Color.black.opacity(0.55)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr(
                            "נקה חיפוש",
                            "Clear Search"
                        )
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(0.92)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    Color.black.opacity(0.08),
                    lineWidth: 1
                )
            )

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 8) {
                    beltChip(
                        title: tr(
                            "הכל",
                            "All"
                        ),
                        selected:
                            beltFilter == nil
                    ) {
                        beltFilter = nil
                    }

                    ForEach(
                        [
                            Belt.yellow,
                            .orange,
                            .green,
                            .blue,
                            .brown,
                            .black
                        ],
                        id: \.self
                    ) { belt in
                        beltChip(
                            title: belt.name,
                            selected:
                                beltFilter == belt
                        ) {
                            beltFilter = belt
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if query.normHeb().isEmpty {
            emptyState(
                text: tr(
                    "התחל להקליד כדי למצוא תרגיל",
                    "Start typing to find an exercise"
                )
            )
        } else if results.isEmpty {
            emptyState(
                text: tr(
                    "אין תוצאות עבור „\(query)”",
                    "No results for “\(query)”"
                )
            )
        } else {
            List(results) { hit in
                Button {
                    onPick(hit)
                    dismiss()
                } label: {
                    VStack(
                        alignment:
                            isEnglish
                            ? .leading
                            : .trailing,
                        spacing: 4
                    ) {
                        Text(hit.displayTitle)
                            .font(.headline)
                            .foregroundStyle(
                                Color(hex: 0xFF172036)
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment:
                                    isEnglish
                                    ? .leading
                                    : .trailing
                            )

                        Text(
                            "\(hit.topic) • \(hit.belt.name)"
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            Color(hex: 0xFF64748B)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment:
                                isEnglish
                                ? .leading
                                : .trailing
                        )
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func refresh() {
        results = engine.search(
            query: query,
            beltFilter: beltFilter,
            limit: 50
        )
    }

    private func emptyState(
        text: String
    ) -> some View {
        VStack(spacing: 10) {
            Image(
                systemName: "magnifyingglass"
            )
            .font(
                .system(
                    size: 34,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Color(hex: 0xFF10B981)
                    .opacity(0.70)
            )

            Text(text)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    Color(hex: 0xFF475569)
                )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(24)
    }

    private func beltChip(
        title: String,
        selected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    selected
                    ? Color.white
                    : Color(hex: 0xFF475569)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(
                            selected
                            ? Color(hex: 0xFF4F46E5)
                            : Color.black.opacity(0.06)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func tr(
        _ hebrew: String,
        _ english: String
    ) -> String {
        isEnglish ? english : hebrew
    }
}
