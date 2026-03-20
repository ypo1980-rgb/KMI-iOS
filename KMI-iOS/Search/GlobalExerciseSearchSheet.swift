import SwiftUI
import Shared

struct GlobalExerciseSearchSheet_Legacy: View {

    @Environment(\.dismiss) private var dismiss

    @StateObject private var engine = GlobalExerciseSearchEngine.shared

    @State private var query: String = ""
    @State private var beltFilter: Belt? = nil

    @State private var results: [ExerciseSearchHit] = []
    @State private var selectedHit: ExerciseSearchHit? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // Search input
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)

                        TextField("חפש תרגיל…", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.search)
                            .onSubmit { refresh() }

                        if !query.isEmpty {
                            Button {
                                query = ""
                                refresh()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .opacity(0.7)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Optional belt filter (אפשר להוריד אם לא צריך)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            beltChip(title: "הכל", selected: beltFilter == nil) {
                                beltFilter = nil
                                refresh()
                            }

                            ForEach([Belt.yellow, .orange, .green, .blue, .brown, .black], id: \.self) { b in
                                beltChip(title: b.name, selected: beltFilter == b) {
                                    beltFilter = b
                                    refresh()
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Results
                Group {
                    if query.normHeb().isEmpty {
                        emptyState(text: "התחל להקליד כדי למצוא תרגיל")
                    } else if results.isEmpty {
                        emptyState(text: "אין תוצאות עבור \"\(query)\"")
                    } else {
                        List(results) { hit in
                            Button {
                                selectedHit = hit
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.displayTitle)
                                        .font(.headline)

                                    Text("\(hit.topic) • \(hit.belt.name)")
                                        .font(.subheadline)
                                        .opacity(0.75)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: results)
            }
            .navigationTitle("חיפוש תרגיל")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") { dismiss() }
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
            .navigationDestination(item: $selectedHit) { hit in
                ExerciseExplanationPlaceholderView(hit: hit)
            }
        }
    }

    private func refresh() {
        results = engine.search(query: query, beltFilter: beltFilter, limit: 50)
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .opacity(0.55)
            Text(text)
                .multilineTextAlignment(.center)
                .opacity(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func beltChip(title: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder explanation screen (until Explanations file is built)
private struct ExerciseExplanationPlaceholderView: View {

    let hit: ExerciseSearchHit

    var body: some View {
        VStack(spacing: 14) {
            Text(hit.displayTitle)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)

            Text("\(hit.topic) • \(hit.belt.name)")
                .font(.subheadline)
                .opacity(0.75)

            Divider().opacity(0.25)

            Text("כאן יוצג ההסבר מתוך קובץ ההסברים שנבנה בהמשך.\n\nכרגע זה מסך Placeholder בלבד.")
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 16)
        .navigationTitle("הסבר")
        .navigationBarTitleDisplayMode(.inline)
    }
}
