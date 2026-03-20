//
//  GlobalExerciseSearchSheet.swift
//  KMI-iOS
//
//  Created by יובל פולק on 03/03/2026.
//

import SwiftUI
import Shared

struct GlobalExerciseSearchSheet: View {

    @Environment(\.dismiss) private var dismiss

    private let catalog = CatalogData.shared.data
    private let belts: [Belt] = [.yellow, .orange, .green, .blue, .brown, .black]

    @State private var selectedBelt: Belt = .orange
    @State private var query: String = ""
    @State private var selectedItem: String? = nil
    @State private var explanationText: String = ""

    private func allItems(for belt: Belt) -> [String] {
        guard let beltContent = catalog[belt] else { return [] }

        var out: [String] = []
        for t in beltContent.topics {
            out.append(contentsOf: t.items)
            for st in t.subTopics {
                out.append(contentsOf: st.items)
            }
        }

        // unique keep order
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    private var results: [String] {
        let base = allItems(for: selectedBelt)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return base }

        return base.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private func pick(_ item: String) {
        selectedItem = item
        explanationText = """
        הסבר זמני – קובץ ההסברים ל-iOS עדיין לא נבנה.

        פריט: \(item)
        חגורה: \(selectedBelt.heb)
        """    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // belt picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(belts, id: \.id) { b in
                            Button {
                                selectedBelt = b
                                selectedItem = nil
                                explanationText = ""
                            } label: {
                                Text(b.heb)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(selectedBelt == b ? Color.black.opacity(0.10) : Color.black.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.top, 8)

                // search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.black.opacity(0.45))

                    TextField("חפש תרגיל…", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                )
                .padding(.horizontal, 14)

                // results + explanation
                ScrollView {
                    VStack(spacing: 12) {

                        // results list
                        VStack(spacing: 10) {
                            ForEach(results, id: \.self) { item in
                                Button {
                                    pick(item)
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(item)
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(Color.black.opacity(0.85))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .lineLimit(2)

                                            Text(selectedItem == item ? "נבחר" : "")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.black.opacity(0.45))
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }

                                        Image(systemName: "chevron.left")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.black.opacity(0.28))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.92))
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if results.isEmpty {
                                Text("לא נמצאו תרגילים")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.black.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 14)
                            }
                        }
                        .padding(.horizontal, 14)

                        // explanation card
                        if let selectedItem, !explanationText.isEmpty {
                            WhiteCard {
                                VStack(alignment: .trailing, spacing: 10) {
                                    Text("הסבר")
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(Color.black.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .trailing)

                                    Text(selectedItem)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Color.black.opacity(0.72))
                                        .frame(maxWidth: .infinity, alignment: .trailing)

                                    Text(explanationText)
                                        .font(.body)
                                        .foregroundStyle(Color.black.opacity(0.82))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                        }

                        Spacer(minLength: 14)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("חיפוש תרגיל")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }
}
