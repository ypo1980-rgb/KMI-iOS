//
//  PracticeView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 22/02/2026.
//
import SwiftUI
import Shared

struct PracticeView: View {
    let belt: Belt
    var topic: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("תרגול")
                .font(.title2).bold()
            Text("חגורה: \(belt.heb)")
                .foregroundStyle(.secondary)
            if let topic { Text("נושא: \(topic)").foregroundStyle(.secondary) }

            Divider().padding(.vertical, 8)

            Text("כאן נחבר את Practice (practiceNavGraph) מהאנדרואיד")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding()
        .navigationTitle("תרגול")
        .navigationBarTitleDisplayMode(.inline)
    }
}
