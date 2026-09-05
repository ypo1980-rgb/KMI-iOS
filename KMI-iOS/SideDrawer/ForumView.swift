import SwiftUI
import FirebaseAuth
import FirebaseFirestore
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

private let forumMessageRetentionDays: Int = 90
private let forumMessageRetentionSeconds: TimeInterval = 90 * 24 * 60 * 60

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

    @Environment(\.colorScheme)
    private var colorScheme

    @ObservedObject
    private var demoPrivacy = DemoPrivacy.shared

    @State private var errorText: String? = nil
    @State private var canUseExtras: Bool = false
    @State private var lockText: String = ""
    @State private var branch: String = ""
    @State private var groupKey: String = ""
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var messages: [ForumUiMessage] = []
    @State private var isMessagesLoading: Bool = false
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
    #endif

    @State private var listener: ListenerRegistration? = nil

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

    private var isCurrentUserForumParticipant: Bool {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: "is_manager") {
            return true
        }

        let cleanUid = currentFirebaseUid.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        return participantsByUsers.contains { participant in
            if participant.isMe {
                return true
            }

            if !cleanUid.isEmpty && participant.id == cleanUid {
                return true
            }

            if !cleanEmail.isEmpty && participant.id.lowercased() == cleanEmail {
                return true
            }

            if !cleanName.isEmpty && participant.name.trimmingCharacters(in: .whitespacesAndNewlines) == cleanName {
                return true
            }

            return false
        }
    }

    private func messagePreviewText(
        text: String,
        mediaType: String?
    ) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanText.isEmpty {
            return String(cleanText.prefix(120))
        }

        if mediaType == "image" {
            return tr("תמונה חדשה", "New image")
        }

        if mediaType == "video" {
            return tr("סרטון חדש", "New video")
        }

        return tr("הודעה חדשה", "New message")
    }
    
    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            if !canUseExtras {
                lockedView
            } else if branch.isEmpty || groupKey.isEmpty {
                missingGroupView
            } else {
                chatView
            }

            if canUseExtras &&
                (!branch.isEmpty && !groupKey.isEmpty) &&
                (isMessagesLoading || isParticipantsLoading) {
                KmiLoadingOverlay()
            }

        }

        .onAppear { boot() }
        .onDisappear { stopListener() }
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
    Task { await loadPickedImage(newItem) }
}
.onChange(of: videoPickerItem) { _, newItem in
    guard let newItem else { return }
    Task { await loadPickedVideo(newItem) }
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

            Image(
                systemName:
                    "person.crop.circle.badge.exclamationmark"
            )
            .kmiFont(size: 34, weight: .heavy)
            .foregroundStyle(
                KmiAppTheme.error(for: colorScheme)
            )
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
                                emptyForumMessagesView
                                    .padding(.top, 18)
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
                .onChange(of: messages) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("__BOTTOM__", anchor: .bottom)
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
    
    private var roomLabelCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    Color(
                        red: 37.0 / 255.0,
                        green: 99.0 / 255.0,
                        blue: 235.0 / 255.0
                    )
                )

            Text(
                isEnglish
                    ? "Branch: \(branch) • Group: \(groupKey)"
                    : "סניף: \(branch) • קבוצה: \(groupKey)"
            )
            .kmiFont(
                size: 11,
                weight: .bold
            )
            .foregroundStyle(
                forumSecondaryTextColor
            )
            .multilineTextAlignment(
                textAlignment
            )
            .lineLimit(2)
            .minimumScaleFactor(0.74)
            .frame(
                maxWidth: .infinity,
                alignment: frameAlignment
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
                cornerRadius: 16,
                style: .continuous
            )
            .fill(
                KmiAppTheme.surface(for: colorScheme)
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                forumCardBorderColor,
                lineWidth: 1
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
        message.isMine || isManagerOverride
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
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(metaTextColor)
                                .frame(width: 25, height: 25)
                                .background(
                                    Circle()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
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
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 260, height: 150)

                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 260, height: 174)
                                    .clipped()

                            default:
                                Text(tr("שגיאה בטעינת תמונה", "Failed to load image"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(mainTextColor.opacity(0.85))
                                    .frame(width: 260, height: 110)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    } else if type == "video" {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 17, weight: .bold))

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
        let txt = currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(FirebaseStorage)
        return !txt.isEmpty || attachedMediaType != nil
        #else
        return !txt.isEmpty
        #endif
    }

    // MARK: - Boot / Listener

    private func boot() {
        errorText = nil
        stopListener()

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

        Task {
            await loadUserBranchAndGroup()
        }
    }

    private func loadUserBranchAndGroup() async {

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
                branch = branchVal
                groupKey = groupVal
                fullName = nameVal
                email = emailVal

                let hasBranchAndGroup = !branchVal.isEmpty && !groupVal.isEmpty

                canUseExtras = true

                if !hasBranchAndGroup {
                    lockText = tr(
                        "לא אותרו סניף או קבוצה במשתמש.\nיש להשלים את פרטי הסניף והקבוצה כדי להשתמש בפורום.",
                        "No branch or group was found for this user.\nPlease complete your branch and group details to use the forum."
                    )
                    stopListener()
                    return
                }

                UserDefaults.standard.set(
                    Date().timeIntervalSince1970 * 1000,
                    forKey: "forum_last_read_at_\(branchVal.trimmingCharacters(in: .whitespacesAndNewlines))"
                )

                lockText = ""
                startListener()

                Task {
                    await loadForumParticipantsForBranch(branchVal)
                }
            }

        } catch {
            await MainActor.run {
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
    
    private func stopListener() {
        listener?.remove()
        listener = nil
        participantsByUsers = []
        isMessagesLoading = false
        isParticipantsLoading = false

    }
    
    private func loadForumParticipantsForBranch(_ branchValue: String) async {
        let cleanBranch = branchValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            participantsByUsers = []
            isParticipantsLoading = true
        }

        guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else {
            await MainActor.run {
                participantsByUsers = []
                isParticipantsLoading = false
            }

            return
        }

        let currentUid = Auth.auth().currentUser?.uid
        let currentEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        func normalizeForumText(_ value: String) -> String {
            var output = ""
            var lastWasSpace = false

            for rawChar in value.trimmingCharacters(in: .whitespacesAndNewlines) {
                let char: Character

                switch rawChar {
                case "-", "–", "—", "־":
                    char = "-"
                default:
                    char = rawChar
                }

                if char.isWhitespace {
                    if !lastWasSpace {
                        output.append(" ")
                    }
                    lastWasSpace = true
                } else {
                    output.append(char)
                    lastWasSpace = false
                }
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func swapDash(_ value: String, to replacement: Character) -> String {
            String(
                value.map { char in
                    switch char {
                    case "-", "–", "—", "־":
                        return replacement
                    default:
                        return char
                    }
                }
            )
        }

        func splitTokens(_ raw: String?) -> [String] {
            guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return []
            }

            return raw
                .replacingOccurrences(of: " • ", with: ",")
                .replacingOccurrences(of: "|", with: ",")
                .replacingOccurrences(of: "\n", with: ",")
                .split { char in
                    char == "," || char == ";" || char == "；"
                }
                .map { normalizeForumText(String($0)) }
                .filter { !$0.isEmpty }
        }

        func userName(from data: [String: Any]) -> String? {
            let value =
                (data["fullName"] as? String) ??
                (data["name"] as? String) ??
                (data["displayName"] as? String) ??
                (data["email"] as? String)

            let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return clean.isEmpty ? nil : clean
        }

        func roleText(from data: [String: Any]) -> String {
            ((data["role"] as? String) ??
             (data["userType"] as? String) ??
             (data["type"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        }

        func isAllowedForumRole(_ data: [String: Any]) -> Bool {
            let role = roleText(from: data)

            return role.isEmpty ||
                role.contains("trainee") ||
                role.contains("coach") ||
                role.contains("trainer") ||
                role.contains("instructor") ||
                role.contains("מתאמן") ||
                role.contains("מאמן")
        }

        func branchTokens(from data: [String: Any]) -> [String] {
            var out: [String] = []

            if let branches = data["branches"] as? [String] {
                out.append(contentsOf: branches.map { normalizeForumText($0) })
            }

            out.append(contentsOf: splitTokens(data["branchesCsv"] as? String))
            out.append(contentsOf: splitTokens(data["branch"] as? String))
            out.append(contentsOf: splitTokens(data["activeBranch"] as? String))
            out.append(contentsOf: splitTokens(data["active_branch"] as? String))

            return Array(Set(out.filter { !$0.isEmpty }))
        }

        func groupTokens(from data: [String: Any]) -> [String] {
            var out: [String] = []

            if let groups = data["groups"] as? [String] {
                out.append(contentsOf: groups.map { normalizeForumText($0) })
            }

            if let groupNames = data["groupNames"] as? [String] {
                out.append(contentsOf: groupNames.map { normalizeForumText($0) })
            }

            out.append(contentsOf: splitTokens(data["groupsCsv"] as? String))
            out.append(contentsOf: splitTokens(data["group"] as? String))
            out.append(contentsOf: splitTokens(data["groupKey"] as? String))
            out.append(contentsOf: splitTokens(data["activeGroup"] as? String))
            out.append(contentsOf: splitTokens(data["active_group"] as? String))

            return Array(Set(out.filter { !$0.isEmpty }))
        }

        func matchesBranch(tokens: [String], candidates: Set<String>) -> Bool {
            guard !tokens.isEmpty, !candidates.isEmpty else { return false }

            return tokens.contains { token in
                candidates.contains(token) ||
                candidates.contains { candidate in
                    candidate.count >= 4 &&
                    token.count >= 4 &&
                    (token.contains(candidate) || candidate.contains(token))
                }
            }
        }

        func participantUniqueKey(id: String, data: [String: Any]) -> String {
            let uid =
                ((data["uid"] as? String) ??
                 (data["authUid"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let docEmail =
                ((data["email"] as? String) ??
                 (data["emailLower"] as? String) ??
                 (data["userEmail"] as? String) ??
                 (data["user_email"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let rawPhone =
                ((data["phone"] as? String) ??
                 (data["phoneNumber"] as? String) ??
                 (data["phone_number"] as? String) ??
                 (data["mobile"] as? String) ??
                 "")

            let digits = rawPhone.filter(\.isNumber)

            let normalizedPhone: String
            if digits.hasPrefix("972"), digits.count >= 11 {
                normalizedPhone = "0" + digits.dropFirst(3)
            } else if digits.hasPrefix("05") {
                normalizedPhone = digits
            } else if digits.count == 9, digits.hasPrefix("5") {
                normalizedPhone = "0\(digits)"
            } else {
                normalizedPhone = digits
            }

            let name = userName(from: data) ?? ""

            if !docEmail.isEmpty {
                return "email:\(docEmail)"
            }

            if !normalizedPhone.isEmpty {
                return "phone:\(normalizedPhone)"
            }

            if !uid.isEmpty {
                return "uid:\(uid)"
            }

            if !name.isEmpty {
                return "name:\(normalizeForumText(name).lowercased())"
            }

            return "doc:\(id)"
        }

        func fetchUsers(field: String, equals value: String) async -> [QueryDocumentSnapshot] {
            do {
                let snap = try await db.collection("users")
                    .whereField(field, isEqualTo: value)
                    .getDocuments()

                return snap.documents
            } catch {
                return []
            }
        }

        func fetchUsersArrayContains(field: String, value: String) async -> [QueryDocumentSnapshot] {
            do {
                let snap = try await db.collection("users")
                    .whereField(field, arrayContains: value)
                    .getDocuments()

                return snap.documents
            } catch {
                return []
            }
        }

        let candidates = Array(
            Set([
                cleanBranch,
                swapDash(cleanBranch, to: "-"),
                swapDash(cleanBranch, to: "–"),
                swapDash(cleanBranch, to: "—"),
                swapDash(cleanBranch, to: "־"),
                cleanBranch.replacingOccurrences(of: "  ", with: " ")
            ].map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter {
                !$0.isEmpty
            })
        )

        let normalizedGroupCandidates = Set(
            [
                cleanGroup,
                cleanGroup.replacingOccurrences(of: " + ", with: " ו"),
                cleanGroup.replacingOccurrences(of: " ו", with: " + "),
                swapDash(cleanGroup, to: "-"),
                swapDash(cleanGroup, to: "–"),
                swapDash(cleanGroup, to: "—"),
                swapDash(cleanGroup, to: "־")
            ]
            .flatMap { value in
                [value] + splitTokens(value)
            }
            .map { normalizeForumText($0) }
            .filter { !$0.isEmpty }
        )

        func matchesGroup(tokens: [String]) -> Bool {
            guard !normalizedGroupCandidates.isEmpty else {
                return true
            }

            guard !tokens.isEmpty else {
                return false
            }

            return tokens.contains { token in
                normalizedGroupCandidates.contains(
                    normalizeForumText(token)
                )
            }
        }

        var docsById: [String: QueryDocumentSnapshot] = [:]

        for candidate in candidates {
            for doc in await fetchUsersArrayContains(field: "branches", value: candidate) {
                docsById[doc.documentID] = doc
            }

            for field in ["branchesCsv", "branch", "activeBranch", "active_branch"] {
                for doc in await fetchUsers(field: field, equals: candidate) {
                    docsById[doc.documentID] = doc
                }
            }
        }

        if docsById.isEmpty {
            do {
                let snap = try await db.collection("users").limit(to: 5000).getDocuments()
                let normalizedCandidates = Set(candidates.map { normalizeForumText($0) })

                for doc in snap.documents {
                    let data = doc.data()
                    if matchesBranch(tokens: branchTokens(from: data), candidates: normalizedCandidates) {
                        docsById[doc.documentID] = doc
                    }
                }
            } catch {
                docsById = [:]
            }
        }

        var grouped: [String: QueryDocumentSnapshot] = [:]

        for doc in docsById.values {
            let data = doc.data()

            guard isAllowedForumRole(data),
                  userName(from: data) != nil,
                  matchesGroup(tokens: groupTokens(from: data)) else {
                continue
            }

            let key = participantUniqueKey(
                id: doc.documentID,
                data: data
            )

            grouped[key] = doc
        }

        let participants = grouped.values.compactMap { doc -> ForumParticipantUi? in
            let data = doc.data()
            guard let name = userName(from: data) else { return nil }

            let docEmail =
                ((data["email"] as? String) ??
                 (data["emailLower"] as? String) ??
                 (data["userEmail"] as? String) ??
                 (data["user_email"] as? String) ??
                 "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let docUid =
                ((data["uid"] as? String) ??
                 (data["authUid"] as? String) ??
                 doc.documentID)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return ForumParticipantUi(
                id: docUid.isEmpty ? doc.documentID : docUid,
                name: name,
                isMe: (
                    (currentUid != nil && docUid == currentUid) ||
                    (!currentEmail.isEmpty && docEmail == currentEmail) ||
                    (
                        !currentName.isEmpty &&
                        name.trimmingCharacters(in: .whitespacesAndNewlines)
                            .caseInsensitiveCompare(currentName) == .orderedSame
                    )
                )
            )
        }
        .reduce(into: [String: ForumParticipantUi]()) { result, participant in
            let key = normalizeForumText(participant.name).lowercased()
            result[key] = participant
        }
        .values
        .sorted {
            if $0.isMe != $1.isMe {
                return $0.isMe && !$1.isMe
            }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }

        await MainActor.run {
            participantsByUsers = participants
            isParticipantsLoading = false
        }
    }
    
    private func startListener() {

        stopListener()

        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else {

            messages = []

            isMessagesLoading = false

            return

        }

        isMessagesLoading = true

        UserDefaults.standard.set(
            Date().timeIntervalSince1970 * 1000,
            forKey: "forum_last_read_at_\(cleanBranch)_\(cleanGroup)"
        )

        let query = db.collection("branches")
            .document(cleanBranch)
            .collection("forumRooms")
            .document(forumRoomDocumentId(branch: cleanBranch, groupKey: cleanGroup))
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: 200)

        listener = query.addSnapshotListener { snap, err in

            if err != nil {

                isMessagesLoading = false

                errorText = tr(

                    "לא הצלחנו לטעון את הודעות הפורום. נסו שוב מאוחר יותר.",

                    "We could not load the forum messages. Please try again later."

                )

                return

            }

            let currentUid = Auth.auth().currentUser?.uid

            let list: [ForumUiMessage] = snap?.documents.compactMap { doc in
                let data = doc.data()

                guard let ts = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    return nil
                }

                let authorName =
                    (data["authorName"] as? String) ??
                    (data["fullName"] as? String) ??
                    (data["name"] as? String) ??
                    (data["displayName"] as? String) ??
                    ""

                let authorEmail = data["authorEmail"] as? String ?? ""
                let authorUid = data["authorUid"] as? String
                let txt = data["text"] as? String ?? ""
                let mediaUrl = data["mediaUrl"] as? String
                let mediaType = data["mediaType"] as? String

                let createdAtMillis: Int64

                if let millis = data["createdAtMillis"] as? Int64 {
                    createdAtMillis = millis
                } else if let millis = data["createdAtMillis"] as? Int {
                    createdAtMillis = Int64(millis)
                } else if let millis = data["createdAtMillis"] as? Double {
                    createdAtMillis = Int64(millis)
                } else {
                    createdAtMillis = Int64(ts.timeIntervalSince1970 * 1000)
                }

                let updatedAtMillis: Int64?

                if let millis = data["updatedAtMillis"] as? Int64 {
                    updatedAtMillis = millis
                } else if let millis = data["updatedAtMillis"] as? Int {
                    updatedAtMillis = Int64(millis)
                } else if let millis = data["updatedAtMillis"] as? Double {
                    updatedAtMillis = Int64(millis)
                } else {
                    updatedAtMillis = nil
                }

                var msg = ForumUiMessage(
                    id: doc.documentID,
                    messageId: data["messageId"] as? String ?? doc.documentID,
                    branch: data["branch"] as? String ?? cleanBranch,
                    groupKey: data["groupKey"] as? String ?? cleanGroup,
                    authorName: authorName,
                    authorEmail: authorEmail,
                    authorUid: authorUid,
                    text: txt,
                    createdAt: ts,
                    createdAtMillis: createdAtMillis,
                    updatedAtMillis: updatedAtMillis,
                    mediaUrl: mediaUrl,
                    mediaType: mediaType
                )
                msg.isMine = (authorUid != nil && authorUid == currentUid)
                return msg
            } ?? []

            messages = list.sorted { $0.createdAt < $1.createdAt }

            isMessagesLoading = false

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

    private func sendOrUpdate() async {
        errorText = nil

        let trimmed = currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            #if canImport(FirebaseStorage)
            if attachedMediaType == nil { return }
            #else
            return
            #endif
        }

        if branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            groupKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        let currentUser = Auth.auth().currentUser
        let uid = currentUser?.uid

        guard currentUser != nil, !(uid ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                errorText = tr(
                    "לא ניתן לשלוח הודעה לפני התחברות משתמש.",
                    "You must be signed in before sending a message."
                )
            }
            return
        }

        guard isCurrentUserForumParticipant else {

            await MainActor.run {

                errorText = tr(

                    "אין הרשאה לשלוח הודעות בחדר הקבוצה הזה.",

                    "You do not have permission to send messages in this group room."

                )

            }

            return

        }

        do {

            if let editId = editingMessageId {

                guard
                    let messageBeingEdited =
                        messages.first(
                            where: { $0.id == editId }
                        ),
                    canModifyMessage(messageBeingEdited)
                else {

                    await MainActor.run {

                        errorText = tr(

                            "אין הרשאה לערוך הודעה זו.",

                            "You do not have permission to edit this message."

                        )

                    }

                    return

                }

            }

            let safeAuthorName = fullName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .ifEmpty(
                    UserDefaults.standard.string(
                        forKey: "displayName"
                    ) ?? ""
                )
                .ifEmpty(
                    UserDefaults.standard.string(
                        forKey: "name"
                    ) ?? ""
                )
                .ifEmpty(email)
                .ifEmpty(
                    tr(
                        "משתתף",
                        "Participant"
                    )
                )

            let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let roomId = forumRoomDocumentId(
                branch: cleanBranch,
                groupKey: cleanGroup
            )

            let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
            let expiresAtDate = Date().addingTimeInterval(forumMessageRetentionSeconds)

            var base: [String: Any] = [

                "roomId": roomId,

                "branch": cleanBranch,

                "groupKey": cleanGroup,

                "authorName": safeAuthorName,

                "authorEmail": email,

                "authorUid": uid ?? "",

                "authorIsManager": isManagerOverride,

                "text": trimmed,

                "createdAtMillis": nowMillis,

                "expiresAt": Timestamp(date: expiresAtDate),

                "retentionDays": forumMessageRetentionDays,

                "isPinned": false,

                "pushStatus": "pending",

                "pushCreatedBy": "ios_forum",

                "source": "ios_forum"

            ]

            #if canImport(FirebaseStorage)
            var mediaUrl: String? = nil
            var mediaType: String? = nil

            if attachedMediaType == "image", let data = attachedImageData {
                mediaType = "image"
                mediaUrl = try await uploadImage(data: data, uid: uid)
            } else if attachedMediaType == "video", let url = attachedVideoUrl {
                mediaType = "video"
                mediaUrl = try await uploadVideo(fileUrl: url, uid: uid)
            }

            if let mediaUrl, let mediaType {
                base["mediaUrl"] = mediaUrl
                base["mediaType"] = mediaType
            }
            #endif

            let roomRef = db.collection("branches")
                .document(cleanBranch)
                .collection("forumRooms")
                .document(roomId)

            let messagePreview = messagePreviewText(

                text: trimmed,

                mediaType: base["mediaType"] as? String

            )

            base["messagePreview"] = messagePreview

            base["hasMedia"] =
                base["mediaUrl"] != nil

            try? await roomRef.setData(
                [
                    "roomId": roomId,
                    "branch": cleanBranch,
                    "groupKey": cleanGroup,
                    "participantCount": participantsByUsers.count,
                    "participantIds": Array(participantsByUsers.map { $0.id }.prefix(200)),
                    "participantNames": Array(participantsByUsers.map { $0.name }.prefix(200)),
                    "participantSource": "users_by_branch_and_group",
                    "pushEnabled": true,
                    "pushTarget": "forum_room_participants",
                    "updatedAt": FieldValue.serverTimestamp(),
                    "updatedAtMillis": nowMillis,
                    "lastMessagePreview": messagePreview,

                    "lastMessageSenderName": safeAuthorName,

                    "lastMessageSenderUid": uid ?? "",

                    "lastMessageAuthorName": safeAuthorName,

                    "lastMessageAuthorUid": uid ?? "",

                    "lastMessageHasMedia":
                        base["mediaUrl"] != nil,

                    "lastMessageMediaType":
                        base["mediaType"] as? String ?? "",

                    "source": "ios_forum"

                    ],

                    merge: true
            )

            let col = roomRef.collection("messages")

            if let editId = editingMessageId {

                base.removeValue(
                    forKey: "createdAtMillis"
                )

                base.removeValue(
                    forKey: "expiresAt"
                )

                base.removeValue(
                    forKey: "retentionDays"
                )

                base.removeValue(
                    forKey: "isPinned"
                )

                if let originalMessage =
                    messages.first(
                        where: { $0.id == editId }
                    ) {

                    base["messageId"] =
                        originalMessage.messageId

                }

                base["updatedAt"] =
                    FieldValue.serverTimestamp()

                base["updatedAtMillis"] =
                    nowMillis

                base["edited"] = true

                try await col
                    .document(editId)
                    .setData(
                        base,
                        merge: true
                    )
            } else {

                let newDoc = col.document()

                base["messageId"] =
                    newDoc.documentID

                base["createdAt"] =
                    FieldValue.serverTimestamp()

                base["updatedAtMillis"] =
                    nowMillis

                try await newDoc.setData(
                    base,
                    merge: true
                )

                try? await roomRef.setData(

                    [

                        "lastMessageId":
                            newDoc.documentID,

                        "lastMessagePreview":
                            messagePreview,

                        "lastMessageAuthorUid":
                            uid ?? "",

                        "lastMessageAuthorName":
                            safeAuthorName,

                        "lastMessageAt":
                            FieldValue.serverTimestamp(),

                        "lastMessageAtMillis":
                            nowMillis,

                        "lastMessageHasMedia":
                            base["mediaUrl"] != nil,

                        "lastMessageMediaType":
                            base["mediaType"] as? String ?? "",

                        "pendingPushMessageId":
                            newDoc.documentID,

                        "pendingPushAuthorUid":
                            uid ?? "",

                        "pendingPushPreview":
                            messagePreview,

                        "pendingPushAt":
                            FieldValue.serverTimestamp(),

                        "pendingPushAtMillis":
                            nowMillis,

                        "updatedAt":
                            FieldValue.serverTimestamp(),

                        "updatedAtMillis":
                            nowMillis

                    ],

                    merge: true

                )

            }

            await MainActor.run {
                input = ""
                editText = ""
                editingMessageId = nil
                isComposerFocused = false
                errorText = nil

                #if canImport(FirebaseStorage)
                clearAttachment()
                #endif
            }
            
        } catch {
            await MainActor.run {
                errorText = tr(
                    "לא הצלחנו לשמור את ההודעה. נסו שוב.",
                    "We could not save the message. Please try again."
                )
            }
        }
    }

    private func deleteMessage(_ msg: ForumUiMessage) async {
        guard canModifyMessage(msg) else {

            await MainActor.run {

                errorText = tr(
                    "אין הרשאה למחוק הודעה זו.",
                    "You do not have permission to delete this message."
                )

            }

            return

        }

        let messageBranch = msg.branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageGroup = msg.groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !messageBranch.isEmpty, !messageGroup.isEmpty else {
            await MainActor.run {
                errorText = tr(
                    "שגיאה במחיקה: לא נמצא סניף או קבוצה להודעה.",
                    "Delete failed: message branch or group was not found."
                )
            }
            return
        }

        do {
            try await db.collection("branches")
                .document(messageBranch)
                .collection("forumRooms")
                .document(forumRoomDocumentId(branch: messageBranch, groupKey: messageGroup))
                .collection("messages")
                .document(msg.id)
                .delete()
        } catch {
            await MainActor.run {
                errorText = tr(
                    "לא הצלחנו למחוק את ההודעה. נסו שוב.",
                    "We could not delete the message. Please try again."
                )
            }
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

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    attachedImageData = data
                    attachedVideoUrl = nil
                    attachedMediaType = "image"
                }
            }
        } catch {
            await MainActor.run {
                errorText = tr(
                    "לא הצלחנו לטעון את התמונה.",
                    "We could not load the image."
                )
            }
        }
    }

    private func loadPickedVideo(_ item: PhotosPickerItem) async {
        do {
            if let movie = try await item.loadTransferable(type: MovieFile.self) {
                await MainActor.run {
                    attachedVideoUrl = movie.url
                    attachedImageData = nil
                    attachedMediaType = "video"
                }
            }
        } catch {
            await MainActor.run {
                errorText = tr(
                    "לא הצלחנו לטעון את הסרטון.",
                    "We could not load the video."
                )
            }
        }
    }

    private func clearAttachment() {
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
