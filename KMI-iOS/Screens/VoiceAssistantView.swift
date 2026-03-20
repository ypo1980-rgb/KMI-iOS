//
//  VoiceAssistantView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 22/02/2026.
//
import SwiftUI

struct VoiceAssistantView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("עוזר קולי")
                .font(.title2).bold()

            Divider().padding(.vertical, 8)

            Text("באנדרואיד: Route.VoiceAssistant רק פותח AiAssistantDialog וסוגר מסך.\nב־iOS נחבר כאן Dialog/Sheet קולי.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)

            Spacer()
        }
        .padding()
        .navigationTitle("עוזר קולי")
        .navigationBarTitleDisplayMode(.inline)
    }
}
