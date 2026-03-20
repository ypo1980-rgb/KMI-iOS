//
//  MultiSelectSheet.swift
//  KMI-iOS
//
//  Created by יובל פולק on 22/02/2026.
//
import SwiftUI

struct MultiSelectSheet: View {
    let title: String
    let options: [String]
    let maxSelected: Int
    @Binding var selected: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.self) { opt in
                        let isOn = selected.contains(opt)
                        Button {
                            toggle(opt)
                        } label: {
                            HStack {
                                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                Text(opt)
                                Spacer()
                                if !isOn && selected.count >= maxSelected {
                                    Text("מקס׳")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .disabled(!isOn && selected.count >= maxSelected)
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("נבחרו: \(selected.count)/\(maxSelected)")
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("סגור") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ opt: String) {
        if selected.contains(opt) {
            selected.remove(opt)
        } else {
            if selected.count < maxSelected {
                selected.insert(opt)
            }
        }
    }
}
