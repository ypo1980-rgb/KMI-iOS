import SwiftUI
import Shared

struct ProgressScreenIOS: View {

    @StateObject private var vm = ProgressViewModel()
    @State private var showShareSheet: Bool = false
    @State private var shareItems: [Any] = []
    @State private var selectedBeltSheet: SelectedBeltSheet? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.05, blue: 0.14),
                    Color(red: 0.07, green: 0.10, blue: 0.23),
                    Color(red: 0.11, green: 0.33, blue: 0.80)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if vm.rows.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)

                    Text("טוען נתוני התקדמות...")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 16, weight: .semibold))
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ProgressSummaryHeader(
                            currentBeltTitle: vm.currentBeltTitle,
                            averagePercent: vm.averagePercent,
                            onShareTap: {
                                shareItems = [vm.shareText()]
                                showShareSheet = true
                            }
                        )

                        ForEach(vm.rows) { row in
                            Button {
                                selectedBeltSheet = SelectedBeltSheet(belt: row.belt)
                            } label: {
                                BeltProgressCard(row: row)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .sheet(item: $selectedBeltSheet) { selected in
            if let row = vm.beltRow(for: selected.belt) {
                ProgressBeltDetailsSheet(
                    belt: selected.belt,
                    row: row,
                    allItems: vm.allExercises(for: selected.belt),
                    vm: vm
                )
            }
        }
        .onAppear {
            vm.loadProgress()
        }
    }
}

private struct BeltProgressCard: View {
    let row: ProgressViewModel.BeltProgress

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(row.color.opacity(0.22))
                        .frame(width: 42, height: 42)

                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .frame(width: 42, height: 42)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        if row.isCurrentBelt {
                            Text("החגורה שלי")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.92))
                                )
                        }

                        Text(row.title)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                    }

                    Text("\(row.done) / \(row.total) תרגילים • \(row.percent)%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }

            ProgressView(value: Double(row.percent) / 100.0)
                .tint(row.color)

            HStack {
                Text("\(row.percent)%")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)

                Spacer()

                Text("לחץ לצפייה בתרגילים חסרים")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct ProgressSummaryHeader: View {
    let currentBeltTitle: String
    let averagePercent: Int
    let onShareTap: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("התקדמות לפי חגורות")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("החגורה הנוכחית: \(currentBeltTitle)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)

            HStack {
                Button(action: onShareTap) {
                    Label("שתף", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(averagePercent)%")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("ממוצע כללי")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct ProgressBeltDetailsSheet: View {
    let belt: Belt
    let row: ProgressViewModel.BeltProgress
    let allItems: [ProgressViewModel.MissingExercise]
    @ObservedObject var vm: ProgressViewModel

    var doneItemsCount: Int {
        allItems.filter { vm.isExerciseDone(belt: belt, itemTitle: $0.itemTitle) }.count
    }

    var missingItemsCount: Int {
        max(0, allItems.count - doneItemsCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.05, blue: 0.14),
                        Color(red: 0.07, green: 0.10, blue: 0.23),
                        Color(red: 0.11, green: 0.33, blue: 0.80)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 10) {
                            Text(row.title)
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Text("\(doneItemsCount) מתוך \(allItems.count) תרגילים הושלמו")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.86))
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            ProgressView(
                                value: allItems.isEmpty ? 0 : Double(doneItemsCount) / Double(allItems.count)
                            )
                            .tint(row.color)

                            Text("חסרים \(missingItemsCount) תרגילים")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                        if allItems.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "tray")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("לא נמצאו תרגילים בחגורה זו")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(.white)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(allItems) { item in
                                    let isDone = vm.isExerciseDone(belt: belt, itemTitle: item.itemTitle)

                                    Button {
                                        vm.toggleExerciseDone(belt: belt, itemTitle: item.itemTitle)
                                    } label: {
                                        VStack(alignment: .trailing, spacing: 6) {
                                            HStack(spacing: 10) {
                                                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 22, weight: .semibold))
                                                    .foregroundStyle(isDone ? Color.green : Color.white.opacity(0.75))

                                                Spacer()

                                                VStack(alignment: .trailing, spacing: 6) {
                                                    Text(item.itemTitle)
                                                        .font(.system(size: 17, weight: .heavy))
                                                        .foregroundStyle(.white)
                                                        .frame(maxWidth: .infinity, alignment: .trailing)

                                                    Text(item.topicTitle)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(.white.opacity(0.82))
                                                        .frame(maxWidth: .infinity, alignment: .trailing)

                                                    if let sub = item.subTopicTitle, !sub.isEmpty {
                                                        Text(sub)
                                                            .font(.system(size: 12, weight: .medium))
                                                            .foregroundStyle(.white.opacity(0.70))
                                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(isDone ? Color.white.opacity(0.16) : Color.white.opacity(0.10))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("פירוט התקדמות")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SelectedBeltSheet: Identifiable {
    let id = UUID()
    let belt: Belt
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
