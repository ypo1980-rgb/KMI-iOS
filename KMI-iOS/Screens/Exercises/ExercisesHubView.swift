//
//  ExercisesHubView.swift
//  KMI-iOS
//
//  Created by יובל פולק on 28/02/2026.
//
import SwiftUI
import Shared

struct ExercisesHubView: View {

    private enum Tab: String, CaseIterable, Identifiable {
        case byBelt = "לפי חגורה"
        case byTopic = "לפי נושא"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .byBelt
    @State private var belt: Belt = .orange

    var body: some View {
        ZStack {
            BeltTopicsGradientBackground()

            VStack(spacing: 12) {

                // "לפי חגורה | לפי נושא"
                WhiteCard {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // תוכן
                if tab == .byBelt {
                    ExercisesByBeltCarouselView(selectedBelt: $belt)
                } else {
                    TopicsBySubjectListView()
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("חגורה ירוקה")
        .navigationBarTitleDisplayMode(.inline)
    }
}
