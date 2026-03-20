//
//  ExerciseSearchView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 03/03/2026.
//
import SwiftUI
import Shared

struct ExerciseSearchView: View {

    @State private var query: String = ""
    @State private var selected: ExerciseHit? = nil

    private let catalog = CatalogData.shared.data

    private let belts: [Belt] = [.white, .yellow, .orange, .green, .blue, .brown, .black]

    struct ExerciseHit: Identifiable, Hashable {
        let belt: Belt
        let title: String

        var id: String { "\(belt.id)::\(title)" }
    }

    private func allExercises(for belt: Belt) -> [String] {
        guard let beltContent = catalog[belt] else { return [] }
        var out: [String] = []

        for t in beltContent.topics {
            out.append(contentsOf: t.items)
            for st in t.subTopics {
                out.append(contentsOf: st.items)
            }
        }

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "״", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    private var results: [ExerciseHit] {
        let q = normalize(query)
        if q.isEmpty { return [] }

        var out: [ExerciseHit] = []
        for b in belts {
            for name in allExercises(for: b) {
                if normalize(name).localizedCaseInsensitiveContains(q) {
                    out.append(.init(belt: b, title: name))
                }
            }
        }
        return out
    }

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            VStack(spacing: 12) {

                WhiteCard {
                    VStack(alignment: .trailing, spacing: 10) {

                        Text("חיפוש תרגיל")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        TextField("הקלד שם תרגיל…", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )

                        if query.isEmpty {
                            Text("חפש לפי שם תרגיל כדי לקבל גם הסבר.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 10) {

                        ForEach(results) { hit in
                            Button {
                                selected = hit
                            } label: {
                                WhiteCard {
                                    HStack(spacing: 10) {
                                        Text(hit.belt.heb)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.black.opacity(0.55))

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(hit.title)
                                                .font(.body.weight(.heavy))
                                                .foregroundStyle(Color.black.opacity(0.82))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .lineLimit(2)

                                            Text("לחץ להסבר")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.black.opacity(0.55))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }

                                        Image(systemName: "chevron.left")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.35))
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 18)
                        }

                        if !query.isEmpty && results.isEmpty {
                            WhiteCard {
                                Text("לא נמצאו תוצאות")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 14)
                            }
                            .padding(.horizontal, 18)
                        }

                        Spacer(minLength: 18)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 22)
                }
            }
        }
        .navigationTitle("חיפוש")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { hit in
            ExerciseExplanationSheet(belt: hit.belt, title: hit.title)
        }
    }
}

private struct ExerciseExplanationSheet: View {

    let belt: Belt
    let title: String

    @Environment(\.dismiss) private var dismiss

    private var explanation: String {
        LocalExplanations.shared.get(belt: belt, item: title)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BeltTopicsGradientBackground()

                ScrollView {
                    WhiteCard {
                        VStack(alignment: .trailing, spacing: 10) {

                            Text(title)
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Text(belt.heb)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Divider().opacity(0.2)

                            Text(explanation)
                                .font(.body)
                                .foregroundStyle(Color.black.opacity(0.82))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
            .navigationTitle("הסבר")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }
}
