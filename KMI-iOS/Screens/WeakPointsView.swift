//
//  WeakPointsView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 22/02/2026.
//
import SwiftUI
import Shared

struct WeakPointsView: View {
    let belt: Belt

    var body: some View {
        VStack(spacing: 12) {
            Text("נקודות תורפה")
                .font(.title2).bold()
            Text("חגורה: \(belt.heb)")
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            Text("כאן נחבר בהמשך את הלוגיקה כמו Route.WeakPoints באנדרואיד")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding()
        .navigationTitle("נקודות תורפה")
        .navigationBarTitleDisplayMode(.inline)
    }
}
