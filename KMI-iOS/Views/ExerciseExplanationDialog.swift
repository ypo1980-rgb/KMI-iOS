import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Shared

struct ExerciseExplanationDialog: View {
    let belt: Belt
    let topic: String
    let item: String
    let branch: String
    let groupKey: String
    let isEnglish: Bool

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.colorScheme)
    private var colorScheme

    @State private var explanationText = ""
    @State private var explanationSourceText = ""
    @State private var errorText: String?
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var draftText = ""
    @State private var favorites: Set<String> = []

    private var db: Firestore {
        Firestore.firestore()
    }

    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var displayName: String {
        let clean = item.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? tr("תרגיל", "Exercise") : clean
    }

    private var beltLabel: String {
        isEnglish ? belt.id.capitalized : belt.heb
    }

    private var subtitle: String {
        let cleanTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTopic.isEmpty else {
            return beltLabel
        }

        return "\(beltLabel) · \(cleanTopic)"
    }

    private var accentColor: Color {
        KmiBeltPalette.color(for: belt)
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: KmiAppTheme.screenBackgroundColors(for: colorScheme),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardColor: Color {
        KmiAppTheme.surface(for: colorScheme)
    }

    private var secondaryCardColor: Color {
        KmiAppTheme.surfaceVariant(for: colorScheme)
    }

    private var borderColor: Color {
        KmiAppTheme.outlineVariant(for: colorScheme)
    }

    private var primaryTextColor: Color {
        KmiAppTheme.onSurface(for: colorScheme)
    }

    private var secondaryTextColor: Color {
        KmiAppTheme.onSurfaceVariant(for: colorScheme)
    }

    private var isFavorite: Bool {
        favorites.contains(normalizedItemId)
    }

    private var documentId: String {
        "\(belt.id)__\(normalizedItemId)"
    }

    private var normalizedItemId: String {
        normalizeIdentifier(item)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    header

                    ScrollView {
                        VStack(alignment: stackAlignment, spacing: 12) {
                            explanationCard

                            if let errorText, !errorText.isEmpty {
                                errorCard(errorText)
                            }

                            sourceCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    closeButton
                }

                if isLoading {
                    KmiLoadingOverlay()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditor) {
                explanationEditor
            }
            .task {
                loadFavorites()
                await loadExplanation()
            }
        }
        .environment(\.layoutDirection, layoutDirection)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if isEnglish {
                titleBlock
                Spacer(minLength: 8)
                actionButtons
            } else {
                actionButtons
                Spacer(minLength: 8)
                titleBlock
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(cardColor)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var titleBlock: some View {
        VStack(alignment: stackAlignment, spacing: 4) {
            Text(displayName)
                .kmiFont(size: 22, weight: .heavy)
                .foregroundStyle(primaryTextColor)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(subtitle)
                .kmiFont(size: 13, weight: .semibold)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .kmiFont(size: 17, weight: .heavy)
                    .foregroundStyle(
                        isFavorite
                            ? Color.yellow
                            : secondaryTextColor
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(secondaryCardColor)
                    )
                    .overlay {
                        Circle()
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isFavorite
                    ? tr("הסר מהמועדפים", "Remove from favorites")
                    : tr("הוסף למועדפים", "Add to favorites")
            )

            Button {
                draftText = explanationText
                showEditor = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .kmiFont(size: 17, weight: .heavy)
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(secondaryCardColor)
                    )
                    .overlay {
                        Circle()
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                tr("עריכת הסבר", "Edit explanation")
            )
        }
    }

    private var explanationCard: some View {
        VStack(alignment: stackAlignment, spacing: 10) {
            Text(tr("הסבר", "Explanation"))
                .kmiFont(size: 18, weight: .heavy)
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            Text(
                explanationText.isEmpty
                    ? tr(
                        "אין כרגע הסבר לתרגיל הזה.",
                        "There is no explanation for this exercise yet."
                    )
                    : explanationText
            )
            .kmiFont(size: 16, weight: .semibold)
            .foregroundStyle(primaryTextColor.opacity(0.94))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(cardColor)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .kmiFont(size: 12, weight: .semibold)
            .foregroundStyle(KmiAppTheme.error(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    KmiAppTheme.error(for: colorScheme)
                        .opacity(0.10)
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    KmiAppTheme.error(for: colorScheme)
                        .opacity(0.28),
                    lineWidth: 1
                )
            }
    }

    private var sourceCard: some View {
        VStack(alignment: stackAlignment, spacing: 8) {
            HStack(spacing: 7) {
                if !isEnglish {
                    Spacer(minLength: 0)
                }

                Text(tr("מקור ההסבר", "Explanation source"))
                    .kmiFont(size: 12, weight: .heavy)
                    .foregroundStyle(primaryTextColor)

                Image(systemName: "checkmark.seal.fill")
                    .kmiFont(size: 15, weight: .bold)
                    .foregroundStyle(accentColor)

                if isEnglish {
                    Spacer(minLength: 0)
                }
            }

            Text(
                explanationSourceText.isEmpty
                    ? tr(
                        "ההסבר מוצג מתוך נתוני האפליקציה.",
                        "The explanation is shown from the app data."
                    )
                    : explanationSourceText
            )
            .kmiFont(size: 12, weight: .semibold)
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)

            if !branch.isEmpty || !groupKey.isEmpty {
                Text(
                    tr(
                        "פורום: \(branch) / \(groupKey)",
                        "Forum: \(branch) / \(groupKey)"
                    )
                )
                .kmiFont(size: 11, weight: .medium)
                .foregroundStyle(secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(secondaryCardColor)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(borderColor, lineWidth: 1)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Text(tr("סגור", "Close"))
                .kmiFont(size: 17, weight: .heavy)
                .foregroundStyle(
                    KmiAppTheme.onPrimary(for: colorScheme)
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .fill(accentColor)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var explanationEditor: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                VStack(alignment: stackAlignment, spacing: 14) {
                    Text(tr("עריכת הסבר", "Edit Explanation"))
                        .kmiFont(size: 22, weight: .heavy)
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    Text(displayName)
                        .kmiFont(size: 13, weight: .semibold)
                        .foregroundStyle(secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                    TextEditor(text: $draftText)
                        .kmiFont(size: 16, weight: .semibold)
                        .foregroundStyle(primaryTextColor)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 240)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .fill(cardColor)
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .stroke(borderColor, lineWidth: 1)
                        }
                        .multilineTextAlignment(textAlignment)

                    HStack(spacing: 12) {
                        Button {
                            showEditor = false
                        } label: {
                            Text(tr("בטל", "Cancel"))
                                .kmiFont(size: 16, weight: .heavy)
                                .foregroundStyle(primaryTextColor)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 46)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 15,
                                        style: .continuous
                                    )
                                    .fill(secondaryCardColor)
                                )
                                .overlay {
                                    RoundedRectangle(
                                        cornerRadius: 15,
                                        style: .continuous
                                    )
                                    .stroke(borderColor, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task {
                                await saveExplanation()
                            }
                        } label: {
                            Text(tr("שמור", "Save"))
                                .kmiFont(size: 16, weight: .heavy)
                                .foregroundStyle(
                                    KmiAppTheme.onPrimary(for: colorScheme)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 46)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 15,
                                        style: .continuous
                                    )
                                    .fill(accentColor)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            draftText
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty
                        )
                        .opacity(
                            draftText
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                                .isEmpty
                                ? 0.55
                                : 1
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, layoutDirection)
    }

    private func loadExplanation() async {
        isLoading = true
        errorText = nil
        explanationSourceText = ""

        do {
            let snapshot = try await db
                .collection("exercise_explanations")
                .document(documentId)
                .getDocument()

            let firestoreText =
                (snapshot.data()?["text"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !firestoreText.isEmpty {
                explanationText = firestoreText
                explanationSourceText = tr(
                    "Firestore",
                    "Firestore"
                )
                isLoading = false
                return
            }
        } catch {
            errorText = tr(
                "לא ניתן היה לטעון את ההסבר מהשרת. מוצג הסבר מקומי.",
                "The server explanation could not be loaded. A local explanation is shown."
            )
        }

        let localText = ExerciseExplanationProvider.get(
            belt: belt,
            item: item
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        explanationText = localText
        explanationSourceText = tr(
            "נתוני האפליקציה",
            "App data"
        )
        isLoading = false
    }

    private func saveExplanation() async {
        errorText = nil

        let cleanDraft = draftText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanDraft.isEmpty else {
            return
        }

        do {
            try await db
                .collection("exercise_explanations")
                .document(documentId)
                .setData(
                    [
                        "beltId": belt.id,
                        "beltHeb": belt.heb,
                        "topic": topic,
                        "item": item,
                        "itemNormalized": normalizedItemId,
                        "text": cleanDraft,
                        "updatedAt": FieldValue.serverTimestamp(),
                        "updatedByUid":
                            Auth.auth().currentUser?.uid ?? "",
                        "updatedByEmail":
                            Auth.auth().currentUser?.email ?? ""
                    ],
                    merge: true
                )

            explanationText = cleanDraft
            explanationSourceText = "Firestore"
            showEditor = false
        } catch {
            errorText = tr(
                "לא הצלחנו לשמור את ההסבר. נסו שוב.",
                "We could not save the explanation. Please try again."
            )
        }
    }

    private func loadFavorites() {
        let stored = UserDefaults.standard.stringArray(
            forKey: "forum_exercise_favorites"
        ) ?? []

        favorites = Set(stored)
    }

    private func toggleFavorite() {
        if favorites.contains(normalizedItemId) {
            favorites.remove(normalizedItemId)
        } else {
            favorites.insert(normalizedItemId)
        }

        UserDefaults.standard.set(
            Array(favorites),
            forKey: "forum_exercise_favorites"
        )
    }

    private func normalizeIdentifier(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "  ", with: " ")
            .lowercased()
    }

    private func tr(_ hebrew: String, _ english: String) -> String {
        isEnglish ? english : hebrew
    }
}

#Preview {
    ExerciseExplanationDialog(
        belt: .yellow,
        topic: "בעיטות",
        item: "בעיטה קדמית",
        branch: "נתניה",
        groupKey: "בוגרים",
        isEnglish: false
    )
}
