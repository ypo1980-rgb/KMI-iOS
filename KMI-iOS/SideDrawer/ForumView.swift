import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import Shared

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// MARK: - Model

private struct ForumUiMessage: Identifiable, Hashable {
    let id: String
    let messageId: String
    let branch: String
    let groupKey: String
    let authorName: String
    let authorEmail: String
    let authorUid: String?
    let text: String
    let createdAt: Date
    let createdAtMillis: Int64
    let updatedAtMillis: Int64?
    let mediaUrl: String?
    let mediaType: String? // "image" / "video" / nil

    var isMine: Bool = false
}

private struct ForumParticipantUi: Identifiable, Hashable {
    let id: String
    let name: String
    let isMe: Bool
}

private struct ForumExerciseHit: Identifiable, Hashable {
    let belt: Belt
    let topic: String
    let item: String

    var id: String {
        "\(belt.id)|\(topic)|\(item)"
    }

    var displayName: String {
        item
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty("Exercise")
    }
}

#if canImport(FirebaseStorage)
private struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("forum_video_\(UUID().uuidString).mov")

            if FileManager.default.fileExists(atPath: tmp.path) {
                try? FileManager.default.removeItem(at: tmp)
            }

            try FileManager.default.copyItem(at: received.file, to: tmp)
            return .init(url: tmp)
        }
    }
}
#endif

// MARK: - View

struct ForumView: View {

    let onClose: () -> Void
    let onOpenSubscription: () -> Void

    init(
        onClose: @escaping () -> Void,
        onOpenSubscription: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        self.onOpenSubscription = onOpenSubscription
    }

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code")
    private var initialLanguageCode: String = "HEBREW"

    @AppStorage("is_manager")
    private var isManagerOverride: Bool = false

    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var nav: AppNavModel

    @State private var isForumVisible = false
    @State private var hasForumLoadingRequest = false

    @Environment(\.colorScheme)
    private var colorScheme

    @ObservedObject
    private var demoPrivacy = DemoPrivacy.shared

    @State private var errorText: String? = nil
    @State private var canUseExtras: Bool = false
    @State private var lockText: String = ""
    @State private var branch: String = ""
    @State private var groupKey: String = ""
    @State private var legacyForumBranch = ""
    @State private var legacyForumGroup = ""
    @State private var isSendingForumMessage = false
    @State private var isDeletingForumMessage = false
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var messages: [ForumUiMessage] = []
    @State private var pendingForumMessageID: String?
    @State private var isMessagesLoading: Bool = false
    @State private var didFailLoadingMessages = false
    @State private var showParticipantsSheet: Bool = false

    // רשימת משתתפים אמיתיים לפי users בסניף — כמו באנדרואיד.
    // אם לא נמצאו משתמשים, forumParticipants ייפול לשמות מתוך ההודעות.
    @State private var participantsByUsers: [ForumParticipantUi] = []
    @State private var isParticipantsLoading: Bool = false
    @State private var isForumControlsCollapsed: Bool = true
    @State private var showRoomDetails: Bool = false
    @State private var input: String = ""
    @State private var editingMessageId: String? = nil
    @State private var editText: String = ""
    @FocusState private var isComposerFocused: Bool
    @State private var pickedSearchHit: ForumExerciseHit? = nil
    @State private var showForumShareSheet: Bool = false
    @State private var forumShareItems: [Any] = []

    #if canImport(FirebaseStorage)
    @State private var attachedImageData: Data? = nil
    @State private var attachedVideoUrl: URL? = nil
    @State private var attachedMediaType: String? = nil  // "image"/"video"/nil

    @State private var imagePickerItem: PhotosPickerItem? = nil
    @State private var videoPickerItem: PhotosPickerItem? = nil
    @State private var attachmentLoadID = UUID()
    #endif

    @State private var forumLoadID = UUID()
    @State private var messageRequestID = UUID()

    private var db: Firestore {
        Firestore.firestore()
    }

    #if canImport(FirebaseStorage)
    private var storage: Storage {
        Storage.storage()
    }
    
    #endif

    private var isDarkMode: Bool {
        colorScheme == .dark

    }

    private var gradient: LinearGradient {
        LinearGradient(

            colors:
                KmiAppTheme.screenBackgroundColors(
                    for: colorScheme
                ),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var forumCardColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
    }

private var forumCardBorderColor: Color {
    KmiAppTheme.outlineVariant(
        for: colorScheme
    )
}

private var forumPrimaryTextColor: Color {
    KmiAppTheme.onSurface(
        for: colorScheme
    )
}

private var forumSecondaryTextColor: Color {
    KmiAppTheme.onSurfaceVariant(
        for: colorScheme
    )
}

private var forumPlaceholderTextColor: Color {
    KmiAppTheme.onSurfaceVariant(
        for: colorScheme
    )
    .opacity(0.78)
}

private var forumComposerColor: Color {
    KmiAppTheme.surface(
        for: colorScheme
    )
}

    private var forumMyBubbleColor: Color {
        KmiAppTheme.primaryContainer(
            for: colorScheme
        )
    }

    private var forumOtherBubbleColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
        .opacity(0.96)
    }

    private var forumMyBubbleTextColor: Color {
        KmiAppTheme.onPrimaryContainer(
            for: colorScheme
        )
    }

    private var forumOtherBubbleTextColor: Color {
        KmiAppTheme.onSurface(
            for: colorScheme
        )
    }

    private var forumSuccessGreen: Color {
        Color(red: 0.145, green: 0.827, blue: 0.400) // #25D366
    }

    private var forumMutedActionColor: Color {
        KmiAppTheme.surfaceVariant(
            for: colorScheme
        )
    }

    private var forumDangerTextColor: Color {
        KmiAppTheme.error(
            for: colorScheme
        )
    }

private var forumStatusIconBackground: Color {
    KmiAppTheme.surfaceVariant(
        for: colorScheme
    )
}

private var forumStatusIconColor: Color {
    KmiAppTheme.onSurface(
        for: colorScheme
    )
}

private var forumStatusBackButtonColor: Color {
    KmiAppTheme.surfaceVariant(
        for: colorScheme
    )
}

    private var forumLockCardColor: Color {
        KmiAppTheme.surface(
            for: colorScheme
        )
        .opacity(0.96)
    }

    private var forumLockBorderColor: Color {
        KmiAppTheme.outlineVariant(
            for: colorScheme
        )
    }

    private var forumLockIconBackground: Color {
        KmiAppTheme.surfaceVariant(
            for: colorScheme
        )
    }

    private var forumLockAccentColor: Color {
        isDarkMode
            ? Color(
                red: 191.0 / 255.0,
                green: 219.0 / 255.0,
                blue: 254.0 / 255.0
            )
            : Color(
                red: 37.0 / 255.0,
                green: 99.0 / 255.0,
                blue: 235.0 / 255.0
            )
    }

    private var forumLockTitleColor: Color {
        isDarkMode
            ? forumLockAccentColor
            : Color(
                red: 30.0 / 255.0,
                green: 58.0 / 255.0,
                blue: 138.0 / 255.0
            )
    }

    private var forumLockBodyColor: Color {
        isDarkMode
            ? Color(
                red: 229.0 / 255.0,
                green: 231.0 / 255.0,
                blue: 235.0 / 255.0
            )
            : Color(
                red: 51.0 / 255.0,
                green: 65.0 / 255.0,
                blue: 85.0 / 255.0
            )
    }

    private var forumLockCaptionColor: Color {
        isDarkMode
            ? Color(
                red: 156.0 / 255.0,
                green: 163.0 / 255.0,
                blue: 175.0 / 255.0
            )
            : Color(
                red: 100.0 / 255.0,
                green: 116.0 / 255.0,
                blue: 139.0 / 255.0
            )
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode,
            selectedLanguageCode,
            appLanguageRaw,
            initialLanguageCode
        ]
        .map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
        }

        for value in values {
            if value == "he" ||
                value == "heb" ||
                value == "hebrew" ||
                value == "עברית" ||
                value.contains("hebrew") {
                return false
            }

            if value == "en" ||
                value == "eng" ||
                value == "english" ||
                value.contains("english") {
                return true
            }
        }

        return false
    }
    
    private var layoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private var backChevronName: String {
        isEnglish ? "chevron.left" : "chevron.right"
    }

    private var forwardChevronName: String {
        isEnglish ? "chevron.right" : "chevron.left"
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    private func boolFromDefaults(_ defaults: UserDefaults, keys: [String]) -> Bool {
        keys.contains { defaults.bool(forKey: $0) }
    }

    private func hasActiveSubscriptionAccess(_ defaults: UserDefaults = .standard) -> Bool {
        let now = Date().timeIntervalSince1970 * 1000
        let accessUntil = defaults.double(forKey: "sub_access_until")
        let verifiedAndValid =
            defaults.bool(forKey: "google_subscription_verified") &&
            accessUntil > now

        return verifiedAndValid ||
            boolFromDefaults(
                defaults,
                keys: [
                    "has_full_access",
                    "full_access",
                    "subscription_active",
                    "is_subscribed"
                ]
            )
    }

    private func isTrialActive(_ defaults: UserDefaults = .standard) -> Bool {
        let trialStart = defaults.double(forKey: "trial_start_millis")
        guard trialStart > 0 else { return false }

        let now = Date().timeIntervalSince1970 * 1000
        let threeDaysMillis: Double = 3 * 24 * 60 * 60 * 1000

        return now - trialStart < threeDaysMillis
    }

    private func canUseForumFromSubscription(_ defaults: UserDefaults = .standard) -> Bool {
        let isManager = defaults.bool(forKey: "is_manager")
        return isManager || hasActiveSubscriptionAccess(defaults)
    }

    private func forumSafeDocumentId(_ raw: String) -> String {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9א-ת_\\-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return clean.isEmpty ? "default" : clean
    }

    private func forumRoomDocumentId(
        branch: String,
        groupKey: String
    ) -> String {
        "room_\(forumSafeDocumentId(branch))_\(forumSafeDocumentId(groupKey))"
    }

    private var currentForumRoomId: String {
        forumRoomDocumentId(
            branch: branch,
            groupKey: groupKey
        )
    }

    private var currentFirebaseUid: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var needsForumLoading: Bool {
        canUseExtras &&
            !branch.isEmpty &&
            !groupKey.isEmpty &&
            (isMessagesLoading || isParticipantsLoading ||
                isSendingForumMessage || isDeletingForumMessage)
    }

    private func syncForumLoading() {
        let shouldRequestLoading = isForumVisible && needsForumLoading
        guard shouldRequestLoading != hasForumLoadingRequest else { return }

        hasForumLoadingRequest = shouldRequestLoading

        if shouldRequestLoading {
            nav.beginLoading()
        } else {
            nav.endLoading()
        }
    }

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            if !canUseExtras {
                lockedView
            } else if forumBranchOptions.isEmpty {
                missingGroupView
            } else {
                VStack(spacing: 0) {
                    forumSectionHeader

                    if branch.isEmpty || groupKey.isEmpty {
                        roomLabelCard
                            .padding(12)

                        Spacer(minLength: 0)
                    } else {
                        chatView
                    }
                }
            }
        }

        .onAppear {
            isForumVisible = true
            boot()
            syncForumLoading()
        }
        .onChange(of: needsForumLoading) { _, _ in
            syncForumLoading()
        }
        .onDisappear {
            isForumVisible = false
            syncForumLoading()
            forumLoadID = UUID()
            stopListener()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_FORUM_PUSH_OPEN_REQUEST")
            )
        ) { _ in
            _ = openPendingForumRoom()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_GLOBAL_SEARCH_PICK")
            )
        ) { output in
            guard let key = output.object as? String else { return }
            guard let parsed = parseSearchKey(key) else { return }
            pickedSearchHit = parsed
        }

        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "KMI_GLOBAL_SHARE_REQUEST"
                )
            )
        ) { notification in

            guard
                canUseExtras,
                !branch.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty,
                !groupKey.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            else {
                return
            }

            if let request =
                notification.object as? NSMutableDictionary {
                request["handled"] = true
            }

            do {
                let pdfUrl = try createForumPdf()
                forumShareItems = [pdfUrl]
                showForumShareSheet = true
            } catch {
                errorText = tr(
                    "לא הצלחנו ליצור את דוח הפורום.",
                    "We could not create the forum report."
                )
            }
        }

        .sheet(item: $pickedSearchHit) { hit in
            ExerciseExplanationDialog(
                belt: hit.belt,
                topic: hit.topic,
                item: hit.item,
                branch: branch,
                groupKey: groupKey,
                isEnglish: isEnglish
            )
        }
        .sheet(isPresented: $showParticipantsSheet) {
            participantsSheet
        }

        .sheet(isPresented: $showForumShareSheet) {

            KmiShareSheet(
                items: forumShareItems
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(.visible)

        }

        #if canImport(FirebaseStorage)
        .onChange(of: imagePickerItem) { _, newItem in
            guard let newItem else { return }

            let requestID = UUID()
            let roomLoadID = forumLoadID
            attachmentLoadID = requestID

            Task {
                await loadPickedImage(newItem, requestID: requestID, roomLoadID: roomLoadID)
            }
        }
        .onChange(of: videoPickerItem) { _, newItem in
            guard let newItem else { return }

            let requestID = UUID()
            let roomLoadID = forumLoadID
            attachmentLoadID = requestID

            Task {
                await loadPickedVideo(newItem, requestID: requestID, roomLoadID: roomLoadID)
            }
        }
#endif
.environment(\.layoutDirection, layoutDirection)
}

    // MARK: - UI

    private var lockedView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 24)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(forumLockIconBackground)

                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        isDarkMode
                            ? Color.white.opacity(0.12)
                            : forumLockBorderColor,
                        lineWidth: 1
                    )

                    Image(systemName: "lock.fill")
                        .font(
                            .system(
                                size: 30,
                                weight: .heavy
                            )
                        )
                        .foregroundStyle(
                            forumLockAccentColor
                        )
                }
                .frame(width: 64, height: 64)

                Spacer()
                    .frame(height: 14)

                Text(
                    tr(
                        "גישה לפורום",
                        "Forum Access"
                    )
                )
                .kmiFont(
                    size: 22,
                    weight: .heavy
                )
                .foregroundStyle(
                    forumLockTitleColor
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                Spacer()
                    .frame(height: 12)

                Text(
                    lockText.isEmpty
                        ? tr(
                            "מסך הפורום זמין למנויים בלבד.",
                            "The forum is available to subscribers only."
                        )
                        : lockText
                )
                .kmiFont(
                    size: 15,
                    weight: .semibold
                )
                .foregroundStyle(
                    forumLockBodyColor
                )
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)

                Spacer()
                    .frame(height: 18)

                Button {
                    onOpenSubscription()
                } label: {
                    Text(
                        tr(
                            "עבור למסך המנוי",
                            "Go to Subscription"
                        )
                    )
                    .kmiFont(
                        size: 16,
                        weight: .heavy
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                Color(
                                    red: 37.0 / 255.0,
                                    green: 99.0 / 255.0,
                                    blue: 235.0 / 255.0
                                )
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer()
                    .frame(height: 12)

                Text(
                    tr(
                        "ניתן לחזור תמיד למסך זה לאחר רכישת מנוי.",
                        "You can always return to this screen after purchasing a subscription."
                    )
                )
                .kmiFont(
                    size: 12,
                    weight: .semibold
                )
                .foregroundStyle(
                    forumLockCaptionColor
                )
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: .infinity)

                Spacer()
                    .frame(height: 12)

                Button {
                    onClose()
                } label: {
                    Text(
                        tr(
                            "חזרה",
                            "Back"
                        )
                    )
                    .kmiFont(
                        size: 14,
                        weight: .bold
                    )
                    .foregroundStyle(
                        forumLockCaptionColor
                    )
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .fill(forumLockCardColor)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 20,
                    style: .continuous
                )
                .stroke(
                    forumLockBorderColor,
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.22 : 0.10
                ),
                radius: 8,
                x: 0,
                y: 4
            )
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
    }

    private var missingGroupView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 44)

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .kmiIconSize(34)
                .foregroundStyle(KmiAppTheme.error(for: colorScheme))
                .accessibilityHidden(true)
            .frame(width: 68, height: 68)
            .background(
                Circle()
                    .fill(
                        KmiAppTheme.surfaceVariant(for: colorScheme)
                    )
            )
            .overlay {
                Circle()
                    .stroke(
                        KmiAppTheme.outlineVariant(for: colorScheme),
                        lineWidth: 1
                    )
            }

            Text(
                tr(
                    "לא אותרו סניף או קבוצה",
                    "Branch or group not found"
                )
            )
            .kmiFont(
                size: 20,
                weight: .heavy
            )
            .foregroundStyle(
                Color(
                    red: 1.0,
                    green: 107.0 / 255.0,
                    blue: 107.0 / 255.0
                )
            )
            .multilineTextAlignment(.center)

            Text(
                tr(
                    "לא אותרו סניף או קבוצה בפרופיל המשתמש.\nודאו שפרטי הסניף והקבוצה מעודכנים.",
                    "No branch or group was found for this user.\nPlease make sure the branch and group are set in the profile."
                )
            )
            .kmiFont(
                size: 15,
                weight: .semibold
            )
            .foregroundStyle(
                forumSecondaryTextColor
            )
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)

            Button {
                onClose()
            } label: {
                Text(
                    tr(
                        "חזרה",
                        "Back"
                    )
                )
                .kmiFont(
                    size: 16,
                    weight: .bold
                )
                .foregroundStyle(
                    KmiAppTheme.onPrimary(for: colorScheme)
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            KmiAppTheme.primary(for: colorScheme)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer(minLength: 44)
        }
        .padding(.horizontal, 18)
    }

    private var forumSectionHeader: some View {
        Text(
            tr(
                "שיח, עדכונים ושיתוף\nבקבוצת האימון",
                "Discussion, updates and sharing\nin the training group"
            )
        )
        .kmiTypography(.secondary)
        .fontWeight(.black)
        .foregroundStyle(KmiAppTheme.sectionHeaderContentColor)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(KmiAppTheme.sectionHeaderBrush)
        .accessibilityAddTraits(.isHeader)
    }

    private var chatView: some View {
        VStack(spacing: 8) {

            if isForumControlsCollapsed {
                forumControlsMiniHandle
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            } else {
                forumControlsExpandedCard
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if messages.isEmpty {
                            if !isMessagesLoading {
                                if didFailLoadingMessages {
                                    Button {
                                        let loadID = forumLoadID
                                        Task {
                                            await refreshForumMessages(loadID: loadID)
                                        }
                                    } label: {
                                        Label(
                                            tr("טען הודעות מחדש", "Reload messages"),
                                            systemImage: "arrow.clockwise"
                                        )
                                        .kmiTypography(.secondary)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(KmiAppTheme.primary(for: colorScheme))
                                    .padding(.top, 18)
                                } else {
                                    emptyForumMessagesView
                                        .padding(.top, 18)
                                }
                            }
                        } else {
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }

                        Color.clear
                            .frame(height: 6)
                            .id("__BOTTOM__")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .refreshable {
                    let loadID = forumLoadID
                    await refreshForumMessages(loadID: loadID)

                    if forumLoadID == loadID, !isParticipantsLoading {
                        await loadForumParticipantsForBranch(branch, loadID: loadID)
                    }
                }
                .onChange(of: messages) { previous, updated in
                    let pendingID = pendingForumMessageID
                    let target = pendingID.flatMap { id in
                        updated.first { $0.id == id || $0.messageId == id }
                    }

                    let scrollID: String
                    let anchor: UnitPoint

                    if let target {
                        scrollID = target.id
                        anchor = .center
                    } else {
                        guard let last = updated.last,
                              previous.last?.id != last.id else { return }

                        scrollID = "__BOTTOM__"
                        anchor = .bottom
                    }

                    let loadID = forumLoadID

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        guard forumLoadID == loadID,
                              pendingForumMessageID == pendingID else { return }

                        if target != nil {
                            guard messages.contains(where: { $0.id == scrollID }) else {
                                return
                            }
                        }

                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(scrollID, anchor: anchor)
                        }

                        if target != nil {
                            pendingForumMessageID = nil
                        }
                    }
                }
            }

#if canImport(FirebaseStorage)
if let attachedMediaType {
    HStack(spacing: 10) {
        Image(
            systemName:
                attachedMediaType == "image"
                ? "photo.fill"
                : attachedMediaType == "video"
                ? "video.fill"
                : "paperclip"
        )
        .kmiFont(size: 15, weight: .bold)
        .foregroundStyle(
            KmiAppTheme.secondary(for: colorScheme)
        )
        .frame(width: 30, height: 30)
        .background(
            Circle()
                .fill(
                    KmiAppTheme.surfaceVariant(for: colorScheme)
                )
        )
        .overlay {
            Circle()
                .stroke(
                    KmiAppTheme.outlineVariant(for: colorScheme),
                    lineWidth: 1
                )
        }

        Text(
            attachedMediaType == "image"
                ? tr(
                    "תמונה מצורפת לשליחה",
                    "Image attached"
                )
                : attachedMediaType == "video"
                ? tr(
                    "סרטון מצורף לשליחה",
                    "Video attached"
                )
                : tr(
                    "קובץ מצורף",
                    "Attachment"
                )
        )
        .kmiFont(
            size: 13,
            weight: .semibold
        )
        .foregroundStyle(
            forumSecondaryTextColor
        )
        .lineLimit(1)
        .minimumScaleFactor(0.76)
        .frame(
            maxWidth: .infinity,
            alignment: frameAlignment
        )
        .multilineTextAlignment(
            textAlignment
        )

        Button {
            clearAttachment()
        } label: {
            Image(systemName: "xmark")
                .font(
                    .system(
                        size: 12,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    forumDangerTextColor
                )
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(
                            forumDangerTextColor.opacity(
                                isDarkMode ? 0.16 : 0.09
                            )
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            tr(
                "הסר קובץ מצורף",
                "Remove attachment"
            )
        )
    }
    .environment(
        \.layoutDirection,
        isEnglish
            ? .leftToRight
            : .rightToLeft
    )
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
        RoundedRectangle(
            cornerRadius: 18,
            style: .continuous
        )
        .fill(forumCardColor)
    )
    .overlay {
        RoundedRectangle(
            cornerRadius: 18,
            style: .continuous
        )
        .stroke(
            forumCardBorderColor,
            lineWidth: 1
        )
    }
    .shadow(
        color: Color.black.opacity(
            isDarkMode ? 0.14 : 0.06
        ),
        radius: 3,
        x: 0,
        y: 2
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 6)
    .transition(
        .opacity.combined(
            with: .move(edge: .bottom)
        )
    )
}
#endif

            composer
                .disabled(isSendingForumMessage || isDeletingForumMessage)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var forumControlsMiniHandle: some View {
        let selectedRoomText =
            branch.isEmpty && groupKey.isEmpty
            ? tr(
                "לחץ לבחירת חדר הפורום ומשתתפים",
                "Tap to choose forum room and participants"
            )
            : "\(branch.ifEmpty("—")) • \(groupKey.ifEmpty("—"))"

        return Button {
            withAnimation(
                .easeOut(duration: 0.18)
            ) {
                isForumControlsCollapsed = false
                showRoomDetails = true
            }
        } label: {
            HStack(spacing: 9) {
                if isEnglish {
                    forumHandleLines
                }

                VStack(
                    alignment: stackAlignment,
                    spacing: 1
                ) {
                    Text(
                        tr(
                            "חדר הפורום",
                            "Forum room"
                        )
                    )
                    .kmiFont(
                        size: 10,
                        weight: .black
                    )
                    .foregroundStyle(
                        forumPrimaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )

                    Text(selectedRoomText)
                        .kmiFont(
                            size: 11,
                            weight: .bold
                        )
                        .foregroundStyle(
                            forumSecondaryTextColor
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )
                }
                .multilineTextAlignment(
                    textAlignment
                )

                Image(systemName: "chevron.down")
                    .font(
                        .system(
                            size: 11,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        forumSuccessGreen
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                        .fill(
                            forumSuccessGreen.opacity(
                                isDarkMode ? 0.14 : 0.10
                            )
                        )
                    )

                if !isEnglish {
                    forumHandleLines
                }
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(
                Capsule(style: .continuous)
                    .fill(forumCardColor)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        forumCardBorderColor,
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.10 : 0.10
                ),
                radius: 5,
                x: 0,
                y: 2
            )
            .contentShape(
                Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var forumControlsExpandedCard: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(
                    .easeOut(duration: 0.18)
                ) {
                    showRoomDetails.toggle()
                }
            } label: {
                forumControlRow(
                    icon: "house.fill",
                    title: tr(
                        "בחירת חדר פורום",
                        "Forum room"
                    ),
                    subtitle:
                        "\(branch.ifEmpty("—")) • \(groupKey.ifEmpty("—"))",
                    isExpanded: showRoomDetails,
                    accent: Color(
                        red: 37.0 / 255.0,
                        green: 99.0 / 255.0,
                        blue: 235.0 / 255.0
                    )
                )
            }
            .buttonStyle(.plain)

            if showRoomDetails {
                roomLabelCard
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .top)
                        )
                    )
            }

            Divider()
                .overlay(
                    forumCardBorderColor
                )
                .opacity(
                    isDarkMode ? 0.65 : 0.80
                )
                .padding(.horizontal, 2)

            Button {
                guard
                    !isParticipantsLoading,
                    !forumParticipants.isEmpty
                else {
                    return
                }

                showParticipantsSheet = true
            } label: {
                forumControlRow(
                    icon: "person.2.fill",
                    title:
                        isParticipantsLoading
                        ? tr(
                            "טוען משתתפים...",
                            "Loading participants..."
                        )
                        : (
                            forumParticipants.isEmpty
                            ? tr(
                                "משתתפים בפורום",
                                "Forum participants"
                            )
                            : tr(
                                "משתתפים בפורום (\(forumParticipants.count))",
                                "Forum participants (\(forumParticipants.count))"
                            )
                        ),
                    subtitle:
                        isParticipantsLoading
                        ? tr(
                            "בודק מי רשום לחדר הזה",
                            "Checking who belongs to this room"
                        )
                        : (
                            forumParticipants.isEmpty
                            ? tr(
                                "אין משתתפים רשומים בקבוצה הזו עדיין",
                                "No registered participants in this group yet"
                            )
                            : tr(
                                "לחץ להצגת הרשימה",
                                "Tap to show the list"
                            )
                        ),
                    isExpanded: showParticipantsSheet,
                    accent: Color(
                        red: 124.0 / 255.0,
                        green: 58.0 / 255.0,
                        blue: 237.0 / 255.0
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(
                isParticipantsLoading ||
                forumParticipants.isEmpty
            )
            .opacity(
                isParticipantsLoading ||
                forumParticipants.isEmpty
                    ? 0.62
                    : 1.0
            )

            Button {
                withAnimation(
                    .easeOut(duration: 0.18)
                ) {
                    showRoomDetails = false
                    isForumControlsCollapsed = true
                }
            } label: {
                forumCollapseHandle
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(forumCardColor)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                forumCardBorderColor,
                lineWidth: 1
            )
        }
        .shadow(
            color: Color.black.opacity(
                isDarkMode ? 0.12 : 0.12
            ),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private func forumControlRow(
        icon: String,
        title: String,
        subtitle: String,
        isExpanded: Bool,
        accent: Color
    ) -> some View {
        HStack(spacing: 9) {
            if isEnglish {
                forumControlIcon(
                    icon: icon,
                    accent: accent
                )
            }

            VStack(
                alignment: stackAlignment,
                spacing: 4
            ) {
                Text(title)
                    .kmiFont(
                        size: 12,
                        weight: .black
                    )
                    .foregroundStyle(
                        forumPrimaryTextColor
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .kmiFont(
                            size: 9.5,
                            weight: .bold
                        )
                        .foregroundStyle(
                            forumSecondaryTextColor
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(
                                style: .continuous
                            )
                            .fill(
                                accent.opacity(
                                    isDarkMode ? 0.15 : 0.09
                                )
                            )
                        )
                        .overlay {
                            Capsule(
                                style: .continuous
                            )
                            .stroke(
                                accent.opacity(
                                    isDarkMode ? 0.28 : 0.18
                                ),
                                lineWidth: 1
                            )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: frameAlignment
                        )
                }
            }

            Image(
                systemName:
                    isExpanded
                    ? "chevron.up"
                    : "chevron.down"
            )
            .font(
                .system(
                    size: 12,
                    weight: .black
                )
            )
            .foregroundStyle(accent)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .fill(
                    accent.opacity(
                        isDarkMode ? 0.16 : 0.10
                    )
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                )
                .stroke(
                    accent.opacity(
                        isDarkMode ? 0.24 : 0.14
                    ),
                    lineWidth: 1
                )
            }

            if !isEnglish {
                forumControlIcon(
                    icon: icon,
                    accent: accent
                )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private func forumControlIcon(
        icon: String,
        accent: Color
    ) -> some View {
        Image(systemName: icon)
            .font(
                .system(
                    size: 14,
                    weight: .black
                )
            )
            .foregroundStyle(accent)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(
                    accent.opacity(
                        isDarkMode ? 0.17 : 0.11
                    )
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    accent.opacity(
                        isDarkMode ? 0.30 : 0.22
                    ),
                    lineWidth: 1
                )
            }
    }

    private var forumCollapseHandle: some View {
        VStack(spacing: 2) {
            ForEach(
                0..<3,
                id: \.self
            ) { _ in
                Capsule()
                    .fill(
                        forumSuccessGreen.opacity(0.78)
                    )
                    .frame(width: 36, height: 2)
            }
        }
        .frame(width: 88, height: 24)
        .background(
            Capsule(style: .continuous)
                .fill(
                    KmiAppTheme.surfaceVariant(for: colorScheme)
                )
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    forumCardBorderColor.opacity(0.90),
                    lineWidth: 1
                )
        }
        .contentShape(
            Capsule(style: .continuous)
        )
    }

    private var forumHandleLines: some View {
        VStack(spacing: 2) {
            ForEach(
                0..<3,
                id: \.self
            ) { _ in
                Capsule()
                    .fill(
                        forumSuccessGreen.opacity(0.78)
                    )
                    .frame(width: 30, height: 2)
            }
        }
        .frame(width: 34, height: 24)
    }

    private var emptyForumMessagesView: some View {
        VStack(spacing: 10) {
            Image(
                systemName:
                    "bubble.left.and.bubble.right"
            )
            .font(
                .system(
                    size: 28,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                forumPlaceholderTextColor
            )

            Text(
                tr(
                    "עדיין אין הודעות בפורום",
                    "No forum messages yet"
                )
            )
            .kmiFont(
                size: 15,
                weight: .heavy
            )
            .foregroundStyle(
                forumPrimaryTextColor
            )
            .multilineTextAlignment(.center)

            Text(
                tr(
                    "אפשר לכתוב את ההודעה הראשונה לסניף.",
                    "You can write the first message for the branch."
                )
            )
            .kmiFont(
                size: 13,
                weight: .semibold
            )
            .foregroundStyle(
                forumSecondaryTextColor
            )
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(forumCardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(forumCardBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.10 : 0.06), radius: 3, x: 0, y: 2)
    }
    
    private var forumGroupsByBranch: [String: [String]] {
        var result: [String: [String]] = [:]

        for assignment in auth.userBranchAssignments {
            let assignedBranch = assignment.branch
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !assignedBranch.isEmpty else { continue }

            for value in assignment.groups {
                let assignedGroup = value
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !assignedGroup.isEmpty,
                   !result[assignedBranch, default: []].contains(assignedGroup) {
                    result[assignedBranch, default: []].append(assignedGroup)
                }
            }
        }

        if auth.userBranchAssignments.isEmpty,
           !legacyForumBranch.isEmpty, !legacyForumGroup.isEmpty {
            result[legacyForumBranch] = [legacyForumGroup]
        }

        return result
    }

    private var forumBranchOptions: [String] {
        forumGroupsByBranch.keys.sorted()
    }

    private var roomLabelCard: some View {
        let groups = forumGroupsByBranch[branch] ?? []

        return VStack(spacing: 8) {
            KmiPremiumDropdown(
                title: tr("סניף", "Branch"),
                options: forumBranchOptions,
                selectedValue: Binding(
                    get: { branch },
                    set: { value in
                        guard forumBranchOptions.contains(value),
                              value != branch else { return }

                        selectForumRoom(branch: value, group: "")
                    }
                ),
                placeholder: tr("בחר סניף", "Select branch"),
                isEnglish: isEnglish,
                isEnabled: !isSendingForumMessage && !forumBranchOptions.isEmpty,
                labelForOption: {
                    TrainingCatalogIOS.displayBranch($0, isEnglish: isEnglish)
                },
                titleInsideField: true
            )

            KmiPremiumDropdown(
                title: tr("קבוצה", "Group"),
                options: groups,
                selectedValue: Binding(
                    get: { groupKey },
                    set: { value in
                        guard groups.contains(value), value != groupKey else { return }

                        selectForumRoom(branch: branch, group: value)
                    }
                ),
                placeholder: tr("בחר קבוצה", "Select group"),
                isEnglish: isEnglish,
                isEnabled: !isSendingForumMessage && !groups.isEmpty,
                labelForOption: {
                    TrainingCatalogIOS.displayGroup($0, isEnglish: isEnglish)
                },
                titleInsideField: true
            )
        }
    }

    
private func forumDisplayPersonName(
    realName: String?,
    stableKey: String?,
    demoIndex: Int?
) -> String {
    TraineeDisplayNameMapper.displayName(
        realName: realName ?? "",
        stableKey: stableKey ?? "",
        demoIndex: demoIndex,
        isEnglish: isEnglish
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .ifEmpty(tr("משתתף", "Participant"))
}

private func participantIndex(
    for message: ForumUiMessage
) -> Int? {
    let cleanAuthorUid = message.authorUid?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let cleanAuthorEmail = message.authorEmail
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let cleanAuthorName = message.authorName
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let index = forumParticipants.firstIndex { participant in
        let participantId = participant.id
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let participantName = participant.name
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanAuthorUid.isEmpty,
           participantId == cleanAuthorUid {
            return true
        }

        if !cleanAuthorEmail.isEmpty,
           participantId.caseInsensitiveCompare(
               cleanAuthorEmail
           ) == .orderedSame {
            return true
        }

        if !cleanAuthorName.isEmpty,
           participantName.caseInsensitiveCompare(
               cleanAuthorName
           ) == .orderedSame {
            return true
        }

        return false
    }

    return index
}

private func displayedAuthorName(
    for message: ForumUiMessage
) -> String {
    let index = participantIndex(for: message)

    let participantName = index.flatMap { participantIndex in
        forumParticipants.indices.contains(participantIndex)
            ? forumParticipants[participantIndex].name
            : nil
    } ?? ""

    let realName = message.authorName
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .ifEmpty(participantName)
        .ifEmpty(message.authorEmail)

    let stableKey = message.authorUid?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .ifEmpty(message.authorEmail)
        .ifEmpty(message.id)
        ?? message.authorEmail.ifEmpty(message.id)

    return forumDisplayPersonName(
        realName: realName,
        stableKey: stableKey,
        demoIndex: index
    )
}

    private var forumParticipants: [ForumParticipantUi] {
        if !participantsByUsers.isEmpty {
            return participantsByUsers
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted {
                    if $0.isMe != $1.isMe {
                        return $0.isMe && !$1.isMe
                    }
                    return $0.name.localizedCompare($1.name) == .orderedAscending
                }
        }

        let grouped = Dictionary(grouping: messages) { msg in
            msg.authorUid ??
            msg.authorEmail.ifEmpty(msg.authorName)
                .ifEmpty("unknown_\(msg.id)")
        }

        var participants = grouped.compactMap { key, groupedMessages -> ForumParticipantUi? in
            guard let sample = groupedMessages.first else { return nil }

            let displayName = sample.authorName
                .ifEmpty(sample.authorEmail)
                .ifEmpty(tr("משתתף", "Participant"))

            return ForumParticipantUi(
                id: key,
                name: displayName,
                isMe: sample.isMine
            )
        }

        if let currentUid = Auth.auth().currentUser?.uid,
           !participants.contains(where: { $0.id == currentUid }) {
            let currentName = fullName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .ifEmpty(email)
                .ifEmpty(tr("אני", "Me"))

            participants.append(
                ForumParticipantUi(
                    id: currentUid,
                    name: currentName,
                    isMe: true
                )
            )
        }

        return participants
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.isMe != $1.isMe {
                    return $0.isMe && !$1.isMe
                }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    private var participantsSheet: some View {
        NavigationStack {
            ZStack {
                gradient
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(
                            Array(
                                forumParticipants.enumerated()
                            ),
                            id: \.element.id
                        ) { index, participant in
                            let participantDisplayName =
                                forumDisplayPersonName(
                                    realName: participant.name,
                                    stableKey: participant.id,
                                    demoIndex: index
                                )
                            HStack(spacing: 12) {
                                if isEnglish {
                                    participantAvatar(
                                        participant,
                                        index: index
                                    )
                                }

                                VStack(
                                    alignment: stackAlignment,
                                    spacing: 2
                                ) {
                                    Text(participantDisplayName)
                                        .kmiFont(
                                            size: 15,
                                            weight:
                                                participant.isMe
                                                ? .black
                                                : .semibold
                                        )
                                        .foregroundStyle(
                                            forumPrimaryTextColor
                                        )
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.76)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: frameAlignment
                                        )

                                    if participant.isMe {
                                        Text(
                                            tr(
                                                "המשתמש שלי",
                                                "My account"
                                            )
                                        )
                                        .kmiFont(
                                            size: 11,
                                            weight: .bold
                                        )
                                        .foregroundStyle(
                                            forumSuccessGreen
                                        )
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: frameAlignment
                                        )
                                    }
                                }
                                .multilineTextAlignment(
                                    textAlignment
                                )

                                if !isEnglish {
                                    participantAvatar(
                                        participant,
                                        index: index
                                    )
                                }
                            }
                            .environment(
                                \.layoutDirection,
                                .leftToRight
                            )
                            .padding(.horizontal, 14)
                            .frame(minHeight: 58)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .fill(forumCardColor)
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 16,
                                    style: .continuous
                                )
                                .stroke(
                                    participant.isMe
                                        ? forumSuccessGreen.opacity(0.40)
                                        : forumCardBorderColor,
                                    lineWidth: 1
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(
                isEnglish
                    ? "Forum participants (\(forumParticipants.count))"
                    : "משתתפים בפורום (\(forumParticipants.count))"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement:
                        isEnglish
                        ? .topBarTrailing
                        : .topBarLeading
                ) {
                    Button {
                        showParticipantsSheet = false
                    } label: {
                        Text(
                            tr(
                                "סגור",
                                "Close"
                            )
                        )
                        .kmiFont(
                            size: 14,
                            weight: .bold
                        )
                    }
                }
            }
        }
        .environment(
            \.layoutDirection,
            layoutDirection
        )
        .presentationDetents([
            .medium,
            .large
        ])
    }

private func participantAvatar(
    _ participant: ForumParticipantUi,
    index: Int
) -> some View {
    let cleanName =
        forumDisplayPersonName(
            realName: participant.name,
            stableKey: participant.id,
            demoIndex: index
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let initial =
            cleanName.first.map {
                String($0)
            } ?? "?"

        let colors: [Color] = [
            Color(
                red: 37.0 / 255.0,
                green: 99.0 / 255.0,
                blue: 235.0 / 255.0
            ),
            Color(
                red: 124.0 / 255.0,
                green: 58.0 / 255.0,
                blue: 237.0 / 255.0
            ),
            forumSuccessGreen,
            Color(
                red: 234.0 / 255.0,
                green: 88.0 / 255.0,
                blue: 12.0 / 255.0
            )
        ]

        let avatarColor =
            participant.isMe
            ? forumSuccessGreen
            : colors[index % colors.count]

        return Text(initial)
            .kmiFont(
                size: 16,
                weight: .black
            )
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(avatarColor)
            )
            .overlay {
                Circle()
                    .stroke(
                        Color.white.opacity(0.22),
                        lineWidth: 1
                    )
            }
    }

    private func canModifyMessage(
        _ message: ForumUiMessage
    ) -> Bool {
        guard canUseExtras,
              let uid = Auth.auth().currentUser?.uid,
              !uid.isEmpty,
              message.branch == branch,
              message.groupKey == groupKey else {
            return false
        }

        return message.authorUid == uid || isManagerOverride
    }

    private func messageAuthorLabel(
        _ message: ForumUiMessage,
        authorName: String
    ) -> String {
        guard message.isMine else {
            return authorName
        }

        return tr(
            "\(authorName) • אני",
            "\(authorName) • me"
        )
    }
    
    private func messageBubble(_ msg: ForumUiMessage) -> some View {
        let bubbleColor = msg.isMine
            ? forumMyBubbleColor
            : forumOtherBubbleColor

        let mainTextColor = msg.isMine
            ? forumMyBubbleTextColor
            : forumOtherBubbleTextColor

        let metaTextColor =
            KmiAppTheme.onSurfaceVariant(
                for: colorScheme
            )
            .opacity(0.78)

        let authorTextColor =
            KmiAppTheme.onSurface(
                for: colorScheme
            )
            .opacity(0.88)

        let bubbleShape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: msg.isMine ? 18 : 6,
            bottomTrailingRadius: msg.isMine ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )

        let mineAlignment: Alignment = isEnglish ? .trailing : .leading
        let otherAlignment: Alignment = isEnglish ? .leading : .trailing
        let bubbleAlignment: Alignment = msg.isMine ? mineAlignment : otherAlignment
        let innerAlignment: HorizontalAlignment = isEnglish ? .leading : .trailing
        let innerTextAlignment: TextAlignment = isEnglish ? .leading : .trailing

        let messageAuthorName =
            displayedAuthorName(for: msg)

        let displayedAuthorName =
            messageAuthorLabel(
                msg,
                authorName: messageAuthorName
            )

        let canModify =
            canModifyMessage(msg)

        return HStack(alignment: .bottom, spacing: 0) {
            if msg.isMine == isEnglish {
                Spacer(minLength: 42)
            }

            VStack(alignment: innerAlignment, spacing: 4) {

                HStack(alignment: .top, spacing: 6) {
                    if canModify {

                        Menu {

                            Button {

                                editingMessageId = msg.id
                                editText = msg.text
                                input = ""

                                #if canImport(FirebaseStorage)
                                clearAttachment()
                                #endif
                            } label: {
                                Label(tr("ערוך", "Edit"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                Task { await deleteMessage(msg) }
                            } label: {
                                Label(tr("מחק", "Delete"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .kmiIconSize(15)
                                .foregroundStyle(metaTextColor)
                                .accessibilityLabel(tr("פעולות הודעה", "Message actions"))
                                .frame(width: 25, height: 25)
                                .background(
                                    Circle()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSendingForumMessage || isDeletingForumMessage)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: innerAlignment, spacing: 1) {
                        Text(displayedAuthorName)
                            .kmiFont(
                                size: 11,
                                weight: .black
                            )
                            .foregroundStyle(
                                authorTextColor
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .frame(
                                maxWidth: .infinity,
                                alignment: bubbleAlignment
                            )
                            .multilineTextAlignment(
                                innerTextAlignment
                            )

                        Text(
                            formatDate(msg.createdAt)
                        )
                        .kmiFont(
                            size: 9.5,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            metaTextColor
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: bubbleAlignment
                        )
                        .multilineTextAlignment(
                            innerTextAlignment
                        )
                    }
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .kmiFont(
                            size: 13,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            mainTextColor
                        )
                        .multilineTextAlignment(
                            innerTextAlignment
                        )
                        .lineSpacing(2)
                        .frame(
                            maxWidth: 272,
                            alignment: bubbleAlignment
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                
                if let urlStr = msg.mediaUrl,
                   let type = msg.mediaType,
                   let url = URL(string: urlStr) {

                    if type == "image" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                KmiAppTheme.surfaceVariant(for: colorScheme)
                                    .frame(width: 260, height: 174)
                                    .accessibilityLabel(tr("טוען תמונה", "Loading image"))

                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 260, height: 174)
                                    .clipped()

                            default:
                                Text(tr("שגיאה בטעינת תמונה", "Failed to load image"))
                                    .kmiTypography(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(mainTextColor.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .frame(width: 260, height: 174)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    } else if type == "video" {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .kmiIconSize(17)
                                    .accessibilityHidden(true)

                                VStack(alignment: isEnglish ? .leading : .trailing, spacing: 1) {
                                    Text(
                                        tr(
                                            "סרטון מצורף",
                                            "Attached video"
                                        )
                                    )
                                    .kmiFont(
                                        size: 14,
                                        weight: .heavy
                                    )

                                    Text(
                                        tr(
                                            "לחיצה לפתיחה בנגן",
                                            "Tap to open in player"
                                        )
                                    )
                                    .kmiFont(
                                        size: 11,
                                        weight: .semibold
                                    )
                                    .foregroundStyle(
                                        metaTextColor
                                    )
                                }

                                Spacer(minLength: 0)

                                Image(systemName: forwardChevronName)
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(mainTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .frame(width: 260)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isDarkMode ? Color.black.opacity(0.18) : Color.black.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bubbleColor)
            .clipShape(bubbleShape)
            .overlay(
                bubbleShape
                    .stroke(Color.white.opacity(msg.isMine ? 0.10 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)

            if msg.isMine != isEnglish {
                Spacer(minLength: 42)
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: bubbleAlignment)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(
                alignment: .bottom,
                spacing: 8
            ) {
                HStack(
                    alignment: .bottom,
                    spacing: 4
                ) {
                    #if canImport(FirebaseStorage)
                    PhotosPicker(
                        selection: $imagePickerItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "plus")
                            .font(
                                .system(
                                    size: 16,
                                    weight: .heavy
                                )
                            )
                            .foregroundStyle(
                                forumPlaceholderTextColor
                            )
                            .frame(
                                width: 36,
                                height: 42
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr(
                            "צרף תמונה",
                            "Attach image"
                        )
                    )
                    #endif

                    ZStack(
                        alignment:
                            isEnglish
                            ? .topLeading
                            : .topTrailing
                    ) {
                        if currentComposerText
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty {
                            Text(
                                editingMessageId == nil
                                    ? tr(
                                        "הודעה",
                                        "Message"
                                    )
                                    : tr(
                                        "עריכת הודעה...",
                                        "Editing message..."
                                    )
                            )
                            .kmiFont(
                                size: 15,
                                weight: .semibold
                            )
                            .foregroundStyle(
                                forumPlaceholderTextColor
                            )
                            .frame(
                                maxWidth: .infinity,
                                alignment: frameAlignment
                            )
                            .multilineTextAlignment(
                                textAlignment
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                        }

                        TextField(
                            "",
                            text: composerBinding,
                            axis: .vertical
                        )
                        .textFieldStyle(.plain)
                        .focused($isComposerFocused)
                        .kmiFont(
                            size: 15,
                            weight: .semibold
                        )
                        .foregroundStyle(
                            forumPrimaryTextColor
                        )
                        .multilineTextAlignment(
                            textAlignment
                        )
                        .lineLimit(4)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .submitLabel(.send)
                        .onSubmit {
                            guard canSend else {
                                return
                            }

                            Task {
                                await sendOrUpdate()
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 9)
                        .frame(
                            minHeight: 42,
                            alignment:
                                isEnglish
                                ? .leading
                                : .trailing
                        )
                    }
                    .frame(maxWidth: .infinity)

                    #if canImport(FirebaseStorage)
                    PhotosPicker(
                        selection: $videoPickerItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Image(
                            systemName:
                                "video.fill"
                        )
                        .font(
                            .system(
                                size: 15,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            forumPlaceholderTextColor
                        )
                        .frame(
                            width: 36,
                            height: 42
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        tr(
                            "צרף סרטון",
                            "Attach video"
                        )
                    )
                    #endif
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 52
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 25,
                        style: .continuous
                    )
                    .fill(forumComposerColor)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 25,
                        style: .continuous
                    )
                    .stroke(
                        isComposerFocused
                            ? forumSuccessGreen.opacity(0.52)
                            : forumCardBorderColor,
                        lineWidth:
                            isComposerFocused
                            ? 1.4
                            : 1
                    )
                }
                .shadow(
                    color: Color.black.opacity(
                        isDarkMode ? 0.18 : 0.10
                    ),
                    radius: 4,
                    x: 0,
                    y: 2
                )
                .animation(
                    .easeInOut(duration: 0.18),
                    value: isComposerFocused
                )

                Button {
                    guard canSend else {
                        isComposerFocused = true
                        return
                    }

                    Task {
                        await sendOrUpdate()
                    }
                } label: {
                    Image(
                        systemName:
                            canSend
                            ? (
                                editingMessageId == nil
                                ? "paperplane.fill"
                                : "checkmark"
                            )
                            : "mic.fill"
                    )
                    .font(
                        .system(
                            size: 18,
                            weight: .heavy
                        )
                    )
                    .foregroundStyle(
                        canSend
                            ? Color.white
                            : (
                                isDarkMode
                                ? Color.white.opacity(0.92)
                                : Color(
                                    red: 0.110,
                                    green: 0.300,
                                    blue: 0.240
                                )
                            )
                    )
                    .frame(
                        width: 48,
                        height: 48
                    )
                    .background(
                        Circle()
                            .fill(
                                canSend
                                    ? forumSuccessGreen
                                    : forumMutedActionColor
                            )
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                canSend
                                    ? Color.clear
                                    : forumCardBorderColor,
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(
                            isDarkMode ? 0.18 : 0.10
                        ),
                        radius: 3,
                        x: 0,
                        y: 2
                    )
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    canSend
                        ? (
                            editingMessageId == nil
                            ? tr(
                                "שלח הודעה",
                                "Send message"
                            )
                            : tr(
                                "שמור עריכה",
                                "Save edit"
                            )
                        )
                        : tr(
                            "הקלד הודעה",
                            "Type a message"
                        )
                )
            }
            .environment(
                \.layoutDirection,
                .leftToRight
            )
            .animation(
                .easeInOut(duration: 0.18),
                value: currentComposerText
            )

            if editingMessageId != nil {
                HStack(spacing: 10) {
                    if isEnglish {
                        Image(systemName: "pencil")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(
                                forumSuccessGreen
                            )
                    }

                    Text(
                        tr(
                            "מצב עריכת הודעה",
                            "Editing message"
                        )
                    )
                    .kmiFont(
                        size: 12,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        forumSecondaryTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )

                    Button {
                        editingMessageId = nil
                        editText = ""
                        isComposerFocused = false
                    } label: {
                        Text(
                            tr(
                                "ביטול עריכה",
                                "Cancel edit"
                            )
                        )
                        .kmiFont(
                            size: 12,
                            weight: .bold
                        )
                        .foregroundStyle(
                            forumDangerTextColor
                        )
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(
                            Capsule(
                                style: .continuous
                            )
                            .fill(
                                forumDangerTextColor.opacity(
                                    isDarkMode ? 0.16 : 0.09
                                )
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    if !isEnglish {
                        Image(systemName: "pencil")
                            .font(
                                .system(
                                    size: 13,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(
                                forumSuccessGreen
                            )
                    }
                }
                .environment(
                    \.layoutDirection,
                    .leftToRight
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(forumCardColor)
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .stroke(
                        forumSuccessGreen.opacity(0.32),
                        lineWidth: 1
                    )
                }
            }

            if let err = errorText,
               !err.isEmpty {
                Text(err)
                    .kmiFont(
                        size: 12,
                        weight: .semibold
                    )
                    .foregroundStyle(
                        forumDangerTextColor
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: frameAlignment
                    )
                    .multilineTextAlignment(
                        textAlignment
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .fill(
                            forumDangerTextColor.opacity(
                                isDarkMode ? 0.14 : 0.08
                            )
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            forumDangerTextColor.opacity(0.24),
                            lineWidth: 1
                        )
                    }
            }
        }
    }

    private var currentComposerText: String {
        editingMessageId == nil ? input : editText
    }

    private var composerBinding: Binding<String> {
        Binding(
            get: { editingMessageId == nil ? input : editText },
            set: { newVal in
                if editingMessageId == nil { input = newVal } else { editText = newVal }
            }
        )
    }

    private var canSend: Bool {
        guard canUseExtras,
              !isSendingForumMessage,
              !isDeletingForumMessage else { return false }

        let text = currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return true }

        #if canImport(FirebaseStorage)
        if attachedMediaType != nil { return true }
        #endif

        guard let editID = editingMessageId else { return false }

        return messages.contains { message in
            message.id == editID &&
                canModifyMessage(message) &&
                message.mediaUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    // MARK: - Boot / Listener

    private func boot() {
        forumLoadID = UUID()
        errorText = nil
        stopListener()
        messages = []

        canUseExtras = false
        lockText = ""

        let ud = UserDefaults.standard

        fullName =
            ud.string(forKey: "fullName") ??
            ud.string(forKey: "full_name") ??
            ud.string(forKey: "name") ??
            ud.string(forKey: "displayName") ??
            ""

        email = ud.string(forKey: "email") ?? ""

        guard Auth.auth().currentUser != nil else {
            lockText = tr(
                "יש להתחבר לאפליקציה כדי להשתמש בפורום הסניף.",
                "Please sign in to use the branch forum."
            )
            return
        }

        guard canUseForumFromSubscription(ud) else {
            if isTrialActive(ud) {
                lockText = tr(
                    "במהלך תקופת הניסיון מסך הפורום נעול.\nאחרי רכישת מנוי המסך ייפתח עבורך.",
                    "During the trial period, the forum is locked.\nAfter purchasing a subscription, this screen will be available."
                )
            } else {
                lockText = tr(
                    "מסך הפורום זמין למנויים בלבד.\nכדי להמשיך יש לרכוש מנוי פעיל.",
                    "The forum is available to subscribers only.\nTo continue, please purchase an active subscription."
                )
            }

            return
        }

        let loadID = forumLoadID

        Task {
            await loadUserBranchAndGroup(loadID: loadID)
        }
    }

    @MainActor
    private func loadUserBranchAndGroup(loadID: UUID) async {
        guard forumLoadID == loadID else { return }

        guard let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                canUseExtras = false
                lockText = tr("יש להתחבר לאפליקציה כדי להשתמש בפורום הסניף.", "Please sign in to use the branch forum.")
            }
            return
        }

        let defaults = UserDefaults.standard

        let localBranch =
            (
                defaults.string(forKey: "active_branch") ??
                defaults.string(forKey: "branch") ??
                defaults.string(forKey: "kmi.user.branch") ??
                ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let localGroup =
            (
                defaults.string(forKey: "active_group") ??
                defaults.string(forKey: "group") ??
                defaults.string(forKey: "kmi.user.group") ??
                ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let snap = try await db.collection("users")
                .document(uid)
                .getDocument()

            let data = snap.data() ?? [:]

            let branchesArray =
                (data["branches"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let firestoreBranch =
                branchesArray.first ??
                ((data["branch"] as? String) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

            let branchVal = firestoreBranch.isEmpty ? localBranch : firestoreBranch

            let groupsArray =
                (data["groups"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let firestoreGroup =
                ((data["groupKey"] as? String) ??
                 (data["age_group"] as? String) ??
                 (data["ageGroup"] as? String) ??
                 (data["group"] as? String) ??
                 groupsArray.first ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let groupVal = firestoreGroup.isEmpty ? localGroup : firestoreGroup

            let nameVal =
                ((data["fullName"] as? String) ??
                 (data["full_name"] as? String) ??
                 (data["name"] as? String) ??
                 (data["displayName"] as? String) ??
                 fullName)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let emailVal =
                ((data["email"] as? String) ??
                 Auth.auth().currentUser?.email ??
                 email)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run {
                guard forumLoadID == loadID,
                      Auth.auth().currentUser?.uid == uid else { return }

                legacyForumBranch = branchVal
                legacyForumGroup = groupVal
                fullName = nameVal
                email = emailVal
                canUseExtras = true
                lockText = ""

                guard let firstBranch = forumBranchOptions.first else {
                    branch = ""
                    groupKey = ""
                    stopListener()
                    return
                }

                let initialBranch = forumBranchOptions.contains(branchVal)
                    ? branchVal
                    : firstBranch

                let groups = forumGroupsByBranch[initialBranch] ?? []
                let initialGroup = groups.contains(groupVal)
                    ? groupVal
                    : (groups.first ?? "")

                if !openPendingForumRoom() {
                    selectForumRoom(branch: initialBranch, group: initialGroup)
                }
            }

        } catch {
            await MainActor.run {
                guard forumLoadID == loadID,
                      Auth.auth().currentUser?.uid == uid else { return }

                canUseExtras = false
                lockText = tr("שגיאה בטעינת פרטי המשתמש.", "Failed to load user details.")
                errorText = tr(
                    "לא הצלחנו לטעון את פרטי המשתמש. נסו שוב מאוחר יותר.",
                    "We could not load your user details. Please try again later."
                )
                stopListener()
            }
        }
    }
    
    @MainActor
    private func openPendingForumRoom() -> Bool {
        guard canUseExtras, !isSendingForumMessage else { return false }

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "forum_open_from_push") else { return false }

        func value(_ key: String) -> String {
            (defaults.string(forKey: key) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let targetBranch = value("forum_push_branch_id")
        let targetGroup = value("forum_push_group_key")
        let targetRoomID = value("forum_push_room_id")
        let targetMessageID = value("forum_push_message_id")

        defaults.set(false, forKey: "forum_open_from_push")

        if !targetBranch.isEmpty,
           !targetGroup.isEmpty,
           (forumGroupsByBranch[targetBranch] ?? []).contains(targetGroup),
           targetRoomID.isEmpty ||
               forumRoomDocumentId(branch: targetBranch, groupKey: targetGroup) == targetRoomID {
            selectForumRoom(branch: targetBranch, group: targetGroup)
            pendingForumMessageID = targetMessageID.isEmpty ? nil : targetMessageID
            return true
        }

        guard !targetRoomID.isEmpty else { return false }

        let matches = forumGroupsByBranch.flatMap { entry in
            entry.value.compactMap { group -> (branch: String, group: String)? in
                guard forumRoomDocumentId(branch: entry.key, groupKey: group) == targetRoomID else {
                    return nil
                }
                return (entry.key, group)
            }
        }

        guard matches.count == 1, let room = matches.first else { return false }

        selectForumRoom(branch: room.branch, group: room.group)
        pendingForumMessageID = targetMessageID.isEmpty ? nil : targetMessageID
        return true
    }

    @MainActor
    private func selectForumRoom(branch nextBranch: String, group nextGroup: String) {
        guard canUseExtras, !isSendingForumMessage,
              forumBranchOptions.contains(nextBranch),
              nextGroup.isEmpty ||
                (forumGroupsByBranch[nextBranch] ?? []).contains(nextGroup) else {
            return
        }

        forumLoadID = UUID()
        stopListener()

        messages = []
        pendingForumMessageID = nil
        errorText = nil
        editingMessageId = nil
        editText = ""
        input = ""
        isComposerFocused = false
        showParticipantsSheet = false

        #if canImport(FirebaseStorage)
        clearAttachment()
        #endif

        branch = nextBranch
        groupKey = nextGroup

        guard !nextGroup.isEmpty else { return }

        showRoomDetails = false
        isForumControlsCollapsed = true

        let loadID = forumLoadID

        Task {
            await refreshForumMessages(loadID: loadID)
        }

        Task {
            await loadForumParticipantsForBranch(nextBranch, loadID: loadID)
        }
    }

    private func stopListener() {
        messageRequestID = UUID()
        participantsByUsers = []
        isMessagesLoading = false
        didFailLoadingMessages = false
        isParticipantsLoading = false
    }
    
    @MainActor
    private func loadForumParticipantsForBranch(
        _ branchValue: String,
        loadID: UUID
    ) async {
        let roomBranch = branchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let roomGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard canUseExtras,
              forumLoadID == loadID,
              branch == roomBranch,
              !roomBranch.isEmpty,
              !roomGroup.isEmpty,
              let uid = Auth.auth().currentUser?.uid,
              !uid.isEmpty else { return }

        isParticipantsLoading = true
        defer {
            if forumLoadID == loadID {
                isParticipantsLoading = false
            }
        }

        do {
            let items = try await loadForumItems(
                "loadSecureForumParticipants",
                branch: roomBranch,
                group: roomGroup
            )

            guard !Task.isCancelled,
                  forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            var seenUIDs = Set<String>()

            participantsByUsers = items.compactMap { item -> ForumParticipantUi? in
                let participantUID = forumItemString(item, key: "uid")
                let name = forumItemString(item, key: "name")
                    .split(whereSeparator: \.isWhitespace)
                    .joined(separator: " ")

                guard !participantUID.isEmpty,
                      !name.isEmpty,
                      seenUIDs.insert(participantUID).inserted else { return nil }

                return ForumParticipantUi(
                    id: participantUID,
                    name: name,
                    isMe: participantUID == uid
                )
            }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame
                    ? $0.id < $1.id
                    : order == .orderedAscending
            }
        } catch {
            guard !Task.isCancelled,
                  forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            errorText = tr(
                "לא הצלחנו לטעון את משתתפי החדר.",
                "We could not load the room participants."
            )
        }
    }

    
    private enum ForumLoadError: Error {
        case invalidResponse
    }

    @MainActor
    private func loadForumItems(
        _ functionName: String,
        branch: String,
        group: String
    ) async throws -> [[String: Any]] {
        let result = try await Functions.functions()
            .httpsCallable(functionName)
            .call([
                "branch": branch,
                "group": group
            ])

        guard let payload = result.data as? [String: Any],
              let items = payload["items"] as? [[String: Any]] else {
            throw ForumLoadError.invalidResponse
        }

        return items
    }

    private func forumItemString(_ item: [String: Any], key: String) -> String {
        (item[key] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func refreshForumMessages(loadID: UUID) async {
        let roomBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let roomGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard canUseExtras,
              forumLoadID == loadID,
              !roomBranch.isEmpty,
              !roomGroup.isEmpty,
              let uid = Auth.auth().currentUser?.uid,
              !uid.isEmpty else { return }

        let requestID = UUID()
        messageRequestID = requestID
        isMessagesLoading = true
        didFailLoadingMessages = false

        defer {
            if forumLoadID == loadID, messageRequestID == requestID {
                isMessagesLoading = false
            }
        }

        do {
            let items = try await loadForumItems(
                "loadSecureForumMessages",
                branch: roomBranch,
                group: roomGroup
            )

            guard !Task.isCancelled,
                  forumLoadID == loadID,
                  messageRequestID == requestID,
                  Auth.auth().currentUser?.uid == uid else { return }

            var seenIDs = Set<String>()

            messages = items.compactMap { item -> ForumUiMessage? in
                let id = forumItemString(item, key: "id")
                let messageID = forumItemString(item, key: "messageId")
                let authorUID = forumItemString(item, key: "authorUid")
                let created = (item["createdAtMillis"] as? NSNumber)?.int64Value ?? 0

                guard !id.isEmpty,
                      !messageID.isEmpty,
                      !authorUID.isEmpty,
                      created > 0,
                      seenIDs.insert(id).inserted else { return nil }

                let updated = (item["updatedAtMillis"] as? NSNumber)?.int64Value ?? 0
                let mediaURL = forumItemString(item, key: "mediaUrl")
                let mediaType = forumItemString(item, key: "mediaType")

                return ForumUiMessage(
                    id: id,
                    messageId: messageID,
                    branch: roomBranch,
                    groupKey: roomGroup,
                    authorName: forumItemString(item, key: "authorName"),
                    authorEmail: "",
                    authorUid: authorUID,
                    text: item["text"] as? String ?? "",
                    createdAt: Date(timeIntervalSince1970: TimeInterval(created) / 1_000),
                    createdAtMillis: created,
                    updatedAtMillis: updated > 0 ? updated : nil,
                    mediaUrl: mediaURL.isEmpty ? nil : mediaURL,
                    mediaType: mediaType.isEmpty ? nil : mediaType,
                    isMine: authorUID == uid
                )
            }
            .sorted {
                $0.createdAtMillis == $1.createdAtMillis
                    ? $0.id < $1.id
                    : $0.createdAtMillis < $1.createdAtMillis
            }

            UserDefaults.standard.set(
                Date().timeIntervalSince1970 * 1_000,
                forKey: "forum_last_read_at_\(roomBranch)_\(roomGroup)"
            )
        } catch {
            guard !Task.isCancelled,
                  forumLoadID == loadID,
                  messageRequestID == requestID,
                  Auth.auth().currentUser?.uid == uid else { return }

            didFailLoadingMessages = true
            errorText = tr(
                "לא הצלחנו לטעון את הודעות הפורום. אפשר למשוך מטה כדי לנסות שוב.",
                "We could not load the forum messages. Pull down to try again."
            )
        }
    }

    // MARK: - Forum PDF

    private func createForumPdf() throws -> URL {

        let pageRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        )

        let renderer = UIGraphicsPDFRenderer(
            bounds: pageRect
        )

        let cleanBranch = branch
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup = groupKey
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let filename = isEnglish
            ? "forum_report.pdf"
            : "דוח_פורום.pdf"

        let outputUrl =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(filename)

        if FileManager.default.fileExists(
            atPath: outputUrl.path
        ) {

            try FileManager.default.removeItem(
                at: outputUrl
            )

        }

        try renderer.writePDF(
            to: outputUrl
        ) { rendererContext in

            let contentLeft: CGFloat = 36

            let contentRight =
                pageRect.width - 36

            let contentWidth =
                contentRight - contentLeft

            let contentBottom =
                pageRect.height -
                KmiPdfFooter.CONTENT_BOTTOM_PADDING

            let authorFont =
                UIFont.systemFont(
                    ofSize: 11.5,
                    weight: .bold
                )

            let messageFont =
                UIFont.systemFont(
                    ofSize: 10.5,
                    weight: .regular
                )

            let dateFont =
                UIFont.systemFont(
                    ofSize: 8.5,
                    weight: .regular
                )

            let authorColor = UIColor(
                red: 15.0 / 255.0,
                green: 23.0 / 255.0,
                blue: 42.0 / 255.0,
                alpha: 1
            )

            let secondaryColor = UIColor(
                red: 71.0 / 255.0,
                green: 85.0 / 255.0,
                blue: 105.0 / 255.0,
                alpha: 1
            )

            let rowColor = UIColor(
                red: 248.0 / 255.0,
                green: 250.0 / 255.0,
                blue: 252.0 / 255.0,
                alpha: 1
            )

            let borderColor = UIColor(
                red: 203.0 / 255.0,
                green: 213.0 / 255.0,
                blue: 225.0 / 255.0,
                alpha: 1
            )

            let dateFormatter = DateFormatter()

            dateFormatter.locale = Locale(
                identifier: isEnglish
                    ? "en_US_POSIX"
                    : "he_IL"
            )

            dateFormatter.calendar =
                Calendar(identifier: .gregorian)

            dateFormatter.dateFormat =
                "dd/MM/yyyy HH:mm"

            var pageNumber = 0

            var currentY =
                KmiPdfHeader.CONTENT_TOP

            func startPage() {

                rendererContext.beginPage()

                pageNumber += 1

                KmiPdfHeader.draw(
                    context:
                        rendererContext.cgContext,
                    pageWidth:
                        pageRect.width,
                    isEnglish:
                        isEnglish,
                    titleHebrew:
                        "דו״ח פורום הסניף",
                    titleEnglish:
                        "Branch Forum Report",
                    subtitleHebrew:
                        [cleanBranch, cleanGroup]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "),
                    subtitleEnglish:
                        [cleanBranch, cleanGroup]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · ")
                )

                currentY =
                    KmiPdfHeader.CONTENT_TOP

            }

            func finishPage() {

                KmiPdfFooter.draw(
                    context:
                        rendererContext.cgContext,
                    pageWidth:
                        pageRect.width,
                    pageHeight:
                        pageRect.height,
                    pageNumber:
                        pageNumber,
                    totalPages:
                        nil,
                    isEnglish:
                        isEnglish
                )

            }

            func paragraphStyle(
                alignment: NSTextAlignment
            ) -> NSParagraphStyle {

                let style = NSMutableParagraphStyle()

                style.baseWritingDirection =
                    KmiPdfDirection.textDirection(
                        isEnglish: isEnglish
                    )

                style.alignment = alignment

                style.lineBreakMode =
                    .byWordWrapping

                return style

            }

            func textHeight(
                _ value: String,
                font: UIFont,
                width: CGFloat
            ) -> CGFloat {

                let attributes:
                    [NSAttributedString.Key: Any] = [

                        .font: font,

                        .paragraphStyle:
                            paragraphStyle(
                                alignment:
                                    KmiPdfDirection.textAlign(
                                        isEnglish:
                                            isEnglish
                                    )
                            )

                    ]

                return ceil(
                    (value as NSString)
                        .boundingRect(
                            with: CGSize(
                                width: width,
                                height:
                                    .greatestFiniteMagnitude
                            ),
                            options: [
                                .usesLineFragmentOrigin,
                                .usesFontLeading
                            ],
                            attributes: attributes,
                            context: nil
                        )
                        .height
                )

            }

            func drawText(
                _ value: String,
                rect: CGRect,
                font: UIFont,
                color: UIColor,
                alignment: NSTextAlignment
            ) {

                let attributes:
                    [NSAttributedString.Key: Any] = [

                        .font: font,

                        .foregroundColor: color,

                        .paragraphStyle:
                            paragraphStyle(
                                alignment: alignment
                            )

                    ]

                (value as NSString).draw(
                    with: rect,
                    options: [
                        .usesLineFragmentOrigin,
                        .usesFontLeading
                    ],
                    attributes: attributes,
                    context: nil
                )

            }

            startPage()

            if messages.isEmpty {

                drawText(
                    tr(
                        "אין הודעות בחדר הפורום שנבחר.",
                        "There are no messages in this forum room."
                    ),
                    rect: CGRect(
                        x: contentLeft,
                        y: currentY + 30,
                        width: contentWidth,
                        height: 40
                    ),
                    font: authorFont,
                    color: secondaryColor,
                    alignment: .center
                )

            } else {

                for message in messages.sorted(
                    by: {
                        $0.createdAtMillis <
                        $1.createdAtMillis
                    }
                ) {

                    let author =
                        displayedAuthorName(
                            for: message
                        )

                    let cleanMessage = message.text
                        .replacingOccurrences(
                            of: "\r",
                            with: " "
                        )
                        .replacingOccurrences(
                            of: "\n",
                            with: " "
                        )
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                    let displayedMessage: String

                    if !cleanMessage.isEmpty {

                        displayedMessage =
                            cleanMessage

                    } else if message.mediaType == "image" {

                        displayedMessage = tr(
                            "תמונה מצורפת",
                            "Attached image"
                        )

                    } else if message.mediaType == "video" {

                        displayedMessage = tr(
                            "סרטון מצורף",
                            "Attached video"
                        )

                    } else {

                        displayedMessage = tr(
                            "הודעה ללא טקסט",
                            "Message without text"
                        )

                    }

                    let innerWidth = contentWidth - 24

                    let authorHeight =
                        textHeight(
                            author,
                            font: authorFont,
                            width: innerWidth
                        )

                    let messageHeight =
                        textHeight(
                            displayedMessage,
                            font: messageFont,
                            width: innerWidth
                        )

                    let availablePageHeight =
                        contentBottom -
                        KmiPdfHeader.CONTENT_TOP

                    let requestedRowHeight = max(
                        58,
                        12 +
                        authorHeight +
                        5 +
                        messageHeight +
                        17
                    )

                    let rowHeight = min(
                        requestedRowHeight,
                        availablePageHeight
                    )

                    if currentY + rowHeight > contentBottom {
                        finishPage()
                        startPage()
                    }

                    let rowRect = CGRect(
                        x: contentLeft,
                        y: currentY,
                        width: contentWidth,
                        height: rowHeight
                    )

                    let rowPath = UIBezierPath(
                        roundedRect: rowRect,
                        cornerRadius: 10
                    )

                    rowColor.setFill()

                    rowPath.fill()

                    borderColor.setStroke()

                    rowPath.lineWidth = 1

                    rowPath.stroke()

                    let textX =
                        contentLeft + 12

                    drawText(
                        author,
                        rect: CGRect(
                            x: textX,
                            y: currentY + 8,
                            width: innerWidth,
                            height: authorHeight + 2
                        ),
                        font: authorFont,
                        color: authorColor,
                        alignment:
                            KmiPdfDirection.textAlign(
                                isEnglish: isEnglish
                            )
                    )

                    drawText(
                        displayedMessage,
                        rect: CGRect(
                            x: textX,
                            y:
                                currentY +
                                11 +
                                authorHeight,
                            width: innerWidth,
                            height: messageHeight + 3
                        ),
                        font: messageFont,
                        color: authorColor,
                        alignment:
                            KmiPdfDirection.textAlign(
                                isEnglish: isEnglish
                            )
                    )

                    drawText(
                        dateFormatter.string(
                            from: message.createdAt
                        ),
                        rect: CGRect(
                            x: textX,
                            y: currentY + rowHeight - 15,
                            width: innerWidth,
                            height: 11
                        ),
                        font: dateFont,
                        color: secondaryColor,
                        alignment:
                            KmiPdfDirection.endTextAlign(
                                isEnglish: isEnglish
                            )
                    )

                    currentY += rowHeight + 8

                }

            }

            finishPage()

        }

        return outputUrl

    }
    
    // MARK: - Send / Update / Delete

    @MainActor
    private func sendOrUpdate() async {
        guard canSend else { return }

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            errorText = tr(
                "לא ניתן לשלוח הודעה לפני התחברות משתמש.",
                "You must be signed in before sending a message."
            )
            return
        }

        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else { return }

        let loadID = forumLoadID
        let editID = editingMessageId
        let text = currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editID {
            guard let original = messages.first(where: { $0.id == editID }),
                  canModifyMessage(original) else {
                errorText = tr(
                    "אין הרשאה לערוך הודעה זו.",
                    "You do not have permission to edit this message."
                )
                return
            }
        }

        #if canImport(FirebaseStorage)
        let pickedImage = attachedImageData
        let pickedVideo = attachedVideoUrl
        let pickedMediaType = attachedMediaType
        #endif

        isSendingForumMessage = true
        errorText = nil
        defer { isSendingForumMessage = false }

        do {
            var payload: [String: Any] = [
                "branch": cleanBranch,
                "group": cleanGroup,
                "text": text,
                "messageId": editID ?? ""
            ]

            #if canImport(FirebaseStorage)
            if pickedMediaType == "image", let pickedImage {
                payload["mediaUrl"] = try await uploadImage(data: pickedImage, uid: uid)
                payload["mediaType"] = "image"
            } else if pickedMediaType == "video", let pickedVideo {
                payload["mediaUrl"] = try await uploadVideo(fileUrl: pickedVideo, uid: uid)
                payload["mediaType"] = "video"
            }
            #endif

            guard !Task.isCancelled,
                  forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            guard editID != nil || !text.isEmpty || payload["mediaUrl"] != nil else {
                return
            }

            _ = try await Functions.functions()
                .httpsCallable("saveSecureForumMessage")
                .call(payload)

            guard forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            input = ""
            editText = ""
            editingMessageId = nil
            isComposerFocused = false

            #if canImport(FirebaseStorage)
            clearAttachment()
            #endif

            await refreshForumMessages(loadID: loadID)
        } catch {
            guard forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            errorText = tr(
                "לא ניתן לאשר את שמירת ההודעה. בדוק אם היא מופיעה בחדר לפני ניסיון חוזר.",
                "Could not confirm that the message was saved. Check the room before trying again."
            )
        }
    }


    @MainActor
    private func deleteMessage(_ msg: ForumUiMessage) async {
        guard !isSendingForumMessage, !isDeletingForumMessage else { return }

        guard canModifyMessage(msg),
              let uid = Auth.auth().currentUser?.uid else {
            errorText = tr(
                "אין הרשאה למחוק הודעה זו.",
                "You do not have permission to delete this message."
            )
            return
        }

        let loadID = forumLoadID
        isDeletingForumMessage = true
        defer { isDeletingForumMessage = false }

        do {
            _ = try await Functions.functions()
                .httpsCallable("deleteSecureForumMessage")
                .call([
                    "branch": msg.branch,
                    "group": msg.groupKey,
                    "messageId": msg.id
                ])

            guard forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            if editingMessageId == msg.id {
                editingMessageId = nil
                editText = ""
            }

            await refreshForumMessages(loadID: loadID)
        } catch {
            guard forumLoadID == loadID,
                  Auth.auth().currentUser?.uid == uid else { return }

            errorText = tr(
                "לא ניתן למחוק את ההודעה כרגע.",
                "The message cannot be deleted right now."
            )
        }
    }

    // MARK: - Uploads

    #if canImport(FirebaseStorage)
    private func uploadImage(data: Data, uid: String?) async throws -> String {
        let safeUid = forumSafeDocumentId(uid ?? "anon")
        let safeBranch = forumSafeDocumentId(branch)
        let safeGroup = forumSafeDocumentId(groupKey)
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let path = "forum_media/\(safeBranch)/\(safeGroup)/\(safeUid)/\(millis).jpg"
        let ref = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    private func uploadVideo(fileUrl: URL, uid: String?) async throws -> String {
        let safeUid = forumSafeDocumentId(uid ?? "anon")
        let safeBranch = forumSafeDocumentId(branch)
        let safeGroup = forumSafeDocumentId(groupKey)
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let path = "forum_media/\(safeBranch)/\(safeGroup)/\(safeUid)/\(millis).mov"
        let ref = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = "video/quicktime"

        _ = try await ref.putFileAsync(from: fileUrl, metadata: meta)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    @MainActor
    private func loadPickedImage(
        _ item: PhotosPickerItem,
        requestID: UUID,
        roomLoadID: UUID
    ) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  attachmentLoadID == requestID,
                  forumLoadID == roomLoadID,
                  !isSendingForumMessage else { return }

            attachedImageData = data
            attachedVideoUrl = nil
            attachedMediaType = "image"
        } catch {
            guard attachmentLoadID == requestID,
                  forumLoadID == roomLoadID else { return }

            errorText = tr(
                "לא הצלחנו לטעון את התמונה.",
                "We could not load the image."
            )
        }
    }

    @MainActor
    private func loadPickedVideo(
        _ item: PhotosPickerItem,
        requestID: UUID,
        roomLoadID: UUID
    ) async {
        do {
            guard let movie = try await item.loadTransferable(type: MovieFile.self) else {
                return
            }

            guard attachmentLoadID == requestID,
                  forumLoadID == roomLoadID,
                  !isSendingForumMessage else {
                try? FileManager.default.removeItem(at: movie.url)
                return
            }

            attachedVideoUrl = movie.url
            attachedImageData = nil
            attachedMediaType = "video"
        } catch {
            guard attachmentLoadID == requestID,
                  forumLoadID == roomLoadID else { return }

            errorText = tr(
                "לא הצלחנו לטעון את הסרטון.",
                "We could not load the video."
            )
        }
    }

    private func clearAttachment() {
        attachmentLoadID = UUID()
        attachedImageData = nil
        attachedVideoUrl = nil
        attachedMediaType = nil
        imagePickerItem = nil
        videoPickerItem = nil
    }
    #endif

    // MARK: - Search Helpers

    private func parseSearchKey(_ key: String) -> ForumExerciseHit? {
        func beltFromId(_ raw: String) -> Belt? {
            switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "white": return .white
            case "yellow": return .yellow
            case "orange": return .orange
            case "green": return .green
            case "blue": return .blue
            case "brown": return .brown
            case "black": return .black
            default: return nil
            }
        }

        let parts = key.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return nil }
        guard let belt = beltFromId(parts[0]) else { return nil }

        let topic = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let item = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !item.isEmpty else { return nil }

        return ForumExerciseHit(
            belt: belt,
            topic: topic,
            item: item
        )
    }

    // MARK: - Utils

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: isEnglish ? "en_US_POSIX" : "he_IL")
        df.dateFormat = isEnglish ? "MM/dd HH:mm" : "dd/MM HH:mm"
        return df.string(from: d)
    }
}

// MARK: - Helpers

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        self.isEmpty ? fallback : self
    }
}
