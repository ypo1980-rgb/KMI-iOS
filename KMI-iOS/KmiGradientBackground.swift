//
//  KmiGradientBackground.swift
//  KMI-iOS
//
//  Created by יובל פולק on 01/03/2026.
//
// KmiGradientBackground.swift
import SwiftUI

struct KmiGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.05, blue: 0.14),
                Color(red: 0.07, green: 0.10, blue: 0.23),
                Color(red: 0.11, green: 0.33, blue: 0.80),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            // קצת “אור” עדין כדי שיראה מודרני
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 240, height: 240)
                    .blur(radius: 2)
                    .offset(x: 140, y: -160)

                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 320, height: 320)
                    .blur(radius: 4)
                    .offset(x: -140, y: 220)
            }
        )
    }
}
