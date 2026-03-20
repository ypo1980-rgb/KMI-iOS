//
//  PdfExportView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 22/02/2026.
//
import SwiftUI
import Shared

struct PdfExportView: View {
    let belt: Belt

    var body: some View {
        VStack(spacing: 12) {
            Text("חומר סיכום (PDF)")
                .font(.title2).bold()
            Text("חגורה: \(belt.heb)")
                .foregroundStyle(.secondary)

            Divider().padding(.vertical, 8)

            Text("באנדרואיד אין Route ייעודי ל-PDF; זה בדרך כלל Share מתוך Summary.\nב־iOS נחבר כאן יצוא PDF + ShareSheet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding()
        .navigationTitle("PDF")
        .navigationBarTitleDisplayMode(.inline)
    }
}
