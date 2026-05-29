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
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    @Environment(\.colorScheme) private var colorScheme

    @State private var errorText: String? = nil

    @State private var canUseExtras: Bool = false
    @State private var lockText: String = ""

    @State private var branch: String = ""
    @State private var groupKey: String = ""
    @State private var fullName: String = ""
    @State private var email: String = ""

    @State private var messages: [ForumUiMessage] = []
    @State private var showParticipantsSheet: Bool = false

    // רשימת משתתפים אמיתיים לפי users בסניף — כמו באנדרואיד.
    // אם לא נמצאו משתמשים, forumParticipants ייפול לשמות מתוך ההודעות.
    @State private var participantsByUsers: [ForumParticipantUi] = []

    @State private var input: String = ""
    @State private var editingMessageId: String? = nil
    @State private var editText: String = ""

    @State private var pickedSearchHit: ForumExerciseHit? = nil

    #if canImport(FirebaseStorage)
    @State private var attachedImageData: Data? = nil
    @State private var attachedVideoUrl: URL? = nil
    @State private var attachedMediaType: String? = nil  // "image"/"video"/nil

    @State private var imagePickerItem: PhotosPickerItem? = nil
    @State private var videoPickerItem: PhotosPickerItem? = nil
    #endif

    @State private var listener: ListenerRegistration? = nil

    private let db = Firestore.firestore()

    #if canImport(FirebaseStorage)
    private let storage = Storage.storage()
    #endif

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var isCoachProfile: Bool {
        let defaults = UserDefaults.standard

        let role = (
            defaults.string(forKey: "user_role") ??
            defaults.string(forKey: "role") ??
            defaults.string(forKey: "userType") ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        return role.contains("coach") ||
            role.contains("trainer") ||
            role.contains("instructor") ||
            role.contains("מאמן")
    }

    private var gradient: LinearGradient {
        if isDarkMode {
            return LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.078, blue: 0.102), // #0B141A
                    Color(red: 0.059, green: 0.106, blue: 0.133), // #0F1B22
                    Color(red: 0.067, green: 0.106, blue: 0.129)  // #111B21
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        if isCoachProfile {
            return LinearGradient(
                colors: [
                    Color(red: 0.973, green: 0.961, blue: 1.000), // #F8F5FF
                    Color(red: 0.941, green: 0.914, blue: 1.000), // #F0E9FF
                    Color(red: 0.918, green: 0.965, blue: 1.000)  // #EAF6FF
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.965, green: 0.984, blue: 1.000), // #F6FBFF
                Color(red: 0.918, green: 0.969, blue: 1.000), // #EAF7FF
                Color(red: 0.918, green: 0.984, blue: 0.965)  // #EAFBF6
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var forumCardColor: Color {
        isDarkMode ? Color(red: 0.125, green: 0.173, blue: 0.200) : Color.white.opacity(0.92)
    }

    private var forumCardBorderColor: Color {
        isDarkMode ? Color(red: 0.133, green: 0.188, blue: 0.227) : Color(red: 0.839, green: 0.894, blue: 0.957)
    }

    private var forumPrimaryTextColor: Color {
        isDarkMode ? Color(red: 0.914, green: 0.929, blue: 0.937) : Color(red: 0.122, green: 0.161, blue: 0.216)
    }

    private var forumSecondaryTextColor: Color {
        isDarkMode ? Color(red: 0.749, green: 0.784, blue: 0.804) : Color(red: 0.200, green: 0.255, blue: 0.333)
    }

    private var forumPlaceholderTextColor: Color {
        isDarkMode ? Color(red: 0.525, green: 0.588, blue: 0.627) : Color(red: 0.392, green: 0.455, blue: 0.545)
    }

    private var forumComposerColor: Color {
        isDarkMode ? Color(red: 0.125, green: 0.173, blue: 0.200) : Color.white
    }

    private var forumMyBubbleColor: Color {
        isDarkMode ? Color(red: 0.078, green: 0.302, blue: 0.216) : Color(red: 0.867, green: 0.984, blue: 0.918)
    }

    private var forumOtherBubbleColor: Color {
        isDarkMode ? Color(red: 0.125, green: 0.173, blue: 0.200) : Color.white.opacity(0.96)
    }

    private var forumMyBubbleTextColor: Color {
        isDarkMode ? Color.white : Color(red: 0.024, green: 0.306, blue: 0.231)
    }

    private var forumOtherBubbleTextColor: Color {
        isDarkMode ? Color(red: 0.914, green: 0.929, blue: 0.937) : Color(red: 0.067, green: 0.094, blue: 0.153)
    }

    private var forumSuccessGreen: Color {
        Color(red: 0.145, green: 0.827, blue: 0.400) // #25D366
    }

    private var forumMutedActionColor: Color {
        isDarkMode
        ? Color(red: 0.120, green: 0.240, blue: 0.200)
        : Color(red: 0.850, green: 0.930, blue: 0.900)
    }

    private var forumDangerTextColor: Color {
        isDarkMode
        ? Color(red: 1.000, green: 0.450, blue: 0.450)
        : Color(red: 0.740, green: 0.100, blue: 0.100)
    }

    private var forumStatusIconBackground: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.05)
    }

    private var forumStatusIconColor: Color {
        isDarkMode ? Color.white.opacity(0.94) : Color(red: 0.122, green: 0.161, blue: 0.216)
    }

    private var forumStatusBackButtonColor: Color {
        isDarkMode ? Color.white.opacity(0.16) : Color.black.opacity(0.06)
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
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
        }
        .onAppear { boot() }
        .onDisappear { stopListener() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KMI_GLOBAL_SEARCH_PICK"))) { output in
            guard let key = output.object as? String else { return }
            guard let parsed = parseSearchKey(key) else { return }
            pickedSearchHit = parsed
        }
        .sheet(item: $pickedSearchHit) { hit in
            ForumExerciseExplanationSheet(
                hit: hit,
                branch: branch,
                groupKey: groupKey,
                isEnglish: isEnglish
            )
        }
        .sheet(isPresented: $showParticipantsSheet) {
            participantsSheet
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
        forumStatusView(
            icon: "lock.fill",
            title: tr("גישה לפורום", "Forum Access"),
            message: lockText.isEmpty
            ? tr("מסך הפורום זמין למנויים בלבד.", "The forum is available to subscribers only.")
            : lockText,
            primaryTitle: tr("עבור למסך המנוי", "Go to Subscription"),
            primaryAction: onOpenSubscription,
            showsPrimaryAction: true
        )
    }

    private var missingGroupView: some View {
        forumStatusView(
            icon: "person.crop.circle.badge.exclamationmark",
            title: tr("לא אותרו סניף או קבוצה", "Branch or group not found"),
            message: tr(
                "ודאו שפרטי הסניף והקבוצה מוגדרים בפרופיל המשתמש.",
                "Please make sure your branch and group are set in your profile."
            ),
            primaryTitle: "",
            primaryAction: {},
            showsPrimaryAction: false
        )
    }

    private func forumStatusView(
        icon: String,
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        showsPrimaryAction: Bool
    ) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 44)

            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(forumStatusIconColor)
                    .frame(width: 68, height: 68)
                    .background(
                        Circle()
                            .fill(forumStatusIconBackground)
                    )
                    .overlay(
                        Circle()
                            .stroke(forumCardBorderColor, lineWidth: 1)
                    )

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(forumPrimaryTextColor)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(forumSecondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 6)

                if showsPrimaryAction {
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(forumSuccessGreen)
                            )
                            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Button(action: onClose) {
                    Text(tr("חזרה", "Back"))
                        .font(.system(size: showsPrimaryAction ? 14 : 16, weight: .bold))
                        .foregroundStyle(showsPrimaryAction ? forumSecondaryTextColor : .white)
                        .frame(maxWidth: showsPrimaryAction ? nil : .infinity)
                        .frame(height: showsPrimaryAction ? nil : 46)
                        .padding(.horizontal, showsPrimaryAction ? 0 : 12)
                        .background(
                            Group {
                                if showsPrimaryAction {
                                    Color.clear
                                } else {
                                    Capsule(style: .continuous)
                                        .fill(forumStatusBackButtonColor)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(forumCardColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(forumCardBorderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.16 : 0.08), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 18)

            Spacer(minLength: 44)
        }
    }

    private var chatView: some View {
        VStack(spacing: 10) {

            roomLabelCard
                .padding(.horizontal, 12)

            if !forumParticipants.isEmpty {
                participantsCard
                    .padding(.horizontal, 12)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if messages.isEmpty {
                            emptyForumMessagesView
                                .padding(.top, 18)
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
if attachedMediaType != nil {
    HStack(spacing: 10) {
        Text(
            attachedMediaType == "image"
            ? tr("תמונה מצורפת לשליחה", "Image attached")
            : attachedMediaType == "video"
            ? tr("סרטון מצורף לשליחה", "Video attached")
            : tr("קובץ מצורף", "Attachment")
        )
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(forumSecondaryTextColor)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .multilineTextAlignment(textAlignment)

        Button {
            clearAttachment()
        } label: {
            Text(tr("הסר", "Remove"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(forumPrimaryTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(forumCardColor)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(forumCardBorderColor, lineWidth: 1)
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 6)
}
#endif

            composer
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var emptyForumMessagesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(forumPlaceholderTextColor)

            Text(tr("עדיין אין הודעות בפורום", "No forum messages yet"))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(forumPrimaryTextColor)
                .multilineTextAlignment(.center)

            Text(tr("אפשר לכתוב את ההודעה הראשונה לסניף.", "You can write the first message for the branch."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(forumSecondaryTextColor)
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
        Text(
            isEnglish
            ? "Branch: \(branch)  •  Group: \(groupKey)"
            : "סניף: \(branch)  •  קבוצה: \(groupKey)"
        )
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(forumSecondaryTextColor)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(forumCardColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(forumCardBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isDarkMode ? 0.10 : 0.06), radius: 3, x: 0, y: 2)
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

    private var participantsCard: some View {
        Button {
            showParticipantsSheet = true
        } label: {
            Text(isEnglish ? "Forum participants (\(forumParticipants.count))" : "משתתפים בפורום (\(forumParticipants.count))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(forumSecondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(forumCardColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(forumCardBorderColor, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDarkMode ? 0.10 : 0.06), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var participantsSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: stackAlignment, spacing: 8) {
                    ForEach(forumParticipants) { participant in
                        Text(
                            participant.isMe
                            ? tr("\(participant.name) (אני)", "\(participant.name) (me)")
                            : participant.name
                        )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .navigationTitle(isEnglish ? "Forum participants (\(forumParticipants.count))" : "משתתפים בפורום (\(forumParticipants.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: isEnglish ? .topBarTrailing : .topBarLeading) {
                    Button(tr("סגור", "Close")) {
                        showParticipantsSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func messageBubble(_ msg: ForumUiMessage) -> some View {
        let bubbleColor = msg.isMine
            ? forumMyBubbleColor
            : forumOtherBubbleColor

        let mainTextColor = msg.isMine
            ? forumMyBubbleTextColor
            : forumOtherBubbleTextColor

        let metaTextColor = isDarkMode
            ? Color.white.opacity(0.62)
            : Color(red: 0.392, green: 0.455, blue: 0.545)

        let authorTextColor = isDarkMode
            ? Color.white.opacity(0.78)
            : Color(red: 0.200, green: 0.255, blue: 0.333)

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

        let participantNameByUid = msg.authorUid.flatMap { uid in
            participantsByUsers.first(where: { $0.id == uid })?.name
        } ?? ""

        let messageAuthorName = msg.authorName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(participantNameByUid)
            .ifEmpty(msg.authorEmail)
            .ifEmpty(tr("משתתף", "Participant"))

        let displayedAuthorName = msg.isMine
            ? tr("\(messageAuthorName) • אני", "\(messageAuthorName) • me")
            : messageAuthorName

        return HStack(alignment: .bottom, spacing: 0) {
            if msg.isMine == isEnglish {
                Spacer(minLength: 42)
            }

            VStack(alignment: innerAlignment, spacing: 4) {

                HStack(alignment: .top, spacing: 6) {
                    if msg.isMine {
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
                            .font(.caption.weight(.black))
                            .foregroundStyle(authorTextColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: bubbleAlignment)
                            .multilineTextAlignment(innerTextAlignment)

                        Text(formatDate(msg.createdAt))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(metaTextColor)
                            .frame(maxWidth: .infinity, alignment: bubbleAlignment)
                            .multilineTextAlignment(innerTextAlignment)
                    }
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(mainTextColor)
                        .multilineTextAlignment(innerTextAlignment)
                        .frame(maxWidth: 260, alignment: bubbleAlignment)
                        .fixedSize(horizontal: false, vertical: true)
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
                                    Text(tr("סרטון מצורף", "Attached video"))
                                        .font(.system(size: 14, weight: .heavy))

                                    Text(tr("לחיצה לפתיחה בנגן", "Tap to open in player"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(metaTextColor)
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
            .padding(.vertical, 7)
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

            HStack(alignment: .center, spacing: 8) {

                HStack(spacing: 6) {
                    #if canImport(FirebaseStorage)
                    PhotosPicker(selection: $imagePickerItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(forumPlaceholderTextColor)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    #endif

                    ZStack(alignment: isEnglish ? .leading : .trailing) {
                        if currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(editingMessageId == nil ? tr("הודעה", "Message") : tr("עריכת הודעה.", "Editing message."))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(forumPlaceholderTextColor)
                                .frame(maxWidth: .infinity, alignment: frameAlignment)
                                .multilineTextAlignment(textAlignment)
                                .padding(.horizontal, 8)
                                .allowsHitTesting(false)
                        }

                        TextField("", text: composerBinding, axis: .horizontal)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(forumPrimaryTextColor)
                            .multilineTextAlignment(textAlignment)
                            .lineLimit(1)
                            .submitLabel(.send)
                            .onSubmit {
                                if canSend {
                                    Task { await sendOrUpdate() }
                                }
                            }
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)

                    #if canImport(FirebaseStorage)
                    PhotosPicker(selection: $videoPickerItem, matching: .videos, photoLibrary: .shared()) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(forumPlaceholderTextColor)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(forumComposerColor)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(forumCardBorderColor, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                Button {
                    if canSend {
                        Task { await sendOrUpdate() }
                    }
                } label: {
                    Image(systemName: canSend ? (editingMessageId == nil ? "paperplane.fill" : "checkmark") : "mic.fill")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(canSend ? .white : (isDarkMode ? Color.white.opacity(0.92) : Color(red: 0.110, green: 0.300, blue: 0.240)))
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(canSend ? forumSuccessGreen : forumMutedActionColor)
                        )
                        .overlay(
                            Circle()
                                .stroke(canSend ? Color.clear : forumCardBorderColor, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(isDarkMode ? 0.16 : 0.08), radius: 3, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.96)
            }
            .frame(height: 60)

            if editingMessageId != nil {
                HStack(spacing: 10) {
                    Button {
                        editingMessageId = nil
                        editText = ""
                    } label: {
                        Text(tr("ביטול עריכה", "Cancel edit"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(forumPrimaryTextColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(tr("מצב עריכת הודעה", "Editing message"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(forumSecondaryTextColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(forumCardColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(forumCardBorderColor, lineWidth: 1)
                )
            }

            if let err = errorText, !err.isEmpty {
                Text(err)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(forumDangerTextColor)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(forumDangerTextColor.opacity(isDarkMode ? 0.14 : 0.08))
                    )
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
                errorText = tr("שגיאה בטעינת פרטי משתמש: \(error.localizedDescription)", "Failed to load user details: \(error.localizedDescription)")
                stopListener()
            }
        }
    }
    
    private func stopListener() {
        listener?.remove()
        listener = nil
        participantsByUsers = []
    }

    private func loadForumParticipantsForBranch(_ branchValue: String) async {
        let cleanBranch = branchValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanBranch.isEmpty else {
            await MainActor.run {
                participantsByUsers = []
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
                ((data["email"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let phone =
                ((data["phone"] as? String) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let name = userName(from: data) ?? ""

            if !uid.isEmpty {
                return "uid:\(uid)"
            }

            if !docEmail.isEmpty {
                return "email:\(docEmail)"
            }

            if !phone.isEmpty {
                return "phone:\(phone)"
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
                #if DEBUG
                print("🟣 FORUM users query failed field=\(field) value=\(value) error=\(error.localizedDescription)")
                #endif
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
                #if DEBUG
                print("🟣 FORUM users array query failed field=\(field) value=\(value) error=\(error.localizedDescription)")
                #endif
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

                #if DEBUG
                print("🟣 FORUM users fallback matched=\(docsById.count) branch=\(cleanBranch)")
                #endif
            } catch {
                #if DEBUG
                print("🟣 FORUM users fallback failed error=\(error.localizedDescription)")
                #endif
            }
        }

        var grouped: [String: QueryDocumentSnapshot] = [:]

        for doc in docsById.values {
            let data = doc.data()

            guard isAllowedForumRole(data),
                  userName(from: data) != nil else {
                continue
            }

            let key = participantUniqueKey(id: doc.documentID, data: data)
            grouped[key] = doc
        }

        let participants = grouped.values.compactMap { doc -> ForumParticipantUi? in
            let data = doc.data()
            guard let name = userName(from: data) else { return nil }

            let docEmail =
                ((data["email"] as? String) ?? "")
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
                    (!currentName.isEmpty && name.trimmingCharacters(in: .whitespacesAndNewlines) == currentName)
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

            #if DEBUG
            print("🟣 FORUM participants loaded from users count=\(participants.count) branch=\(cleanBranch) names=\(participants.map { $0.name })")
            #endif
        }
    }
    
    private func startListener() {
        stopListener()

        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanBranch.isEmpty, !cleanGroup.isEmpty else {
            messages = []
            return
        }

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
            if let err {
                errorText = tr(
                    "שגיאה בטעינת הודעות: \(err.localizedDescription)",
                    "Failed to load messages: \(err.localizedDescription)"
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
        }
    }

    private func ensureAnonAuth() async {
        // הפורום עובד רק עם משתמש מחובר אמיתי
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
            let safeAuthorName = fullName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .ifEmpty(UserDefaults.standard.string(forKey: "displayName") ?? "")
                .ifEmpty(UserDefaults.standard.string(forKey: "name") ?? "")
                .ifEmpty(email)
                .ifEmpty(tr("משתתף", "Participant"))

            let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanGroup = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let roomId = forumRoomDocumentId(
                branch: cleanBranch,
                groupKey: cleanGroup
            )

            let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
            let expiresAtDate = Date().addingTimeInterval(forumMessageRetentionSeconds)

            var base: [String: Any] = [
                "branch": cleanBranch,
                "groupKey": cleanGroup,
                "authorName": safeAuthorName,
                "authorEmail": email,
                "authorUid": uid ?? "",
                "text": trimmed,
                "createdAtMillis": nowMillis,
                "expiresAt": Timestamp(date: expiresAtDate),
                "retentionDays": forumMessageRetentionDays,
                "isPinned": false
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
                    "lastMessageSenderUid": uid ?? ""
                ],
                merge: true
            )

            let col = roomRef.collection("messages")

            if let editId = editingMessageId {
                base.removeValue(forKey: "createdAtMillis")
                base.removeValue(forKey: "expiresAt")
                base.removeValue(forKey: "retentionDays")
                base.removeValue(forKey: "isPinned")
                base["updatedAt"] = FieldValue.serverTimestamp()
                base["updatedAtMillis"] = nowMillis

                try await col.document(editId).setData(base, merge: true)
            } else {
                let newDoc = col.document()
                base["messageId"] = newDoc.documentID
                base["createdAt"] = FieldValue.serverTimestamp()

                try await newDoc.setData(base, merge: true)
            }

            await MainActor.run {
                input = ""
                editText = ""
                editingMessageId = nil

                #if canImport(FirebaseStorage)
                clearAttachment()
                #endif
            }

        } catch {
            await MainActor.run {
                errorText = tr(
                    "שגיאה בשמירת ההודעה: \(error.localizedDescription)",
                    "Error saving message: \(error.localizedDescription)"
                )
            }
        }
    }

    private func deleteMessage(_ msg: ForumUiMessage) async {
        guard msg.isMine else { return }

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
                    "שגיאה במחיקת ההודעה: \(error.localizedDescription)",
                    "Error deleting message: \(error.localizedDescription)"
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
                    "שגיאה בטעינת תמונה: \(error.localizedDescription)",
                    "Failed to load image: \(error.localizedDescription)"
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
                    "שגיאה בטעינת וידאו: \(error.localizedDescription)",
                    "Failed to load video: \(error.localizedDescription)"
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

// MARK: - Explanation Sheet

private struct ForumExerciseExplanationSheet: View {

    let hit: ForumExerciseHit
    let branch: String
    let groupKey: String
    let isEnglish: Bool

    private var textAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var frameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var stackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    @Environment(\.dismiss) private var dismiss

    @State private var explanationText: String = ""
    @State private var explanationSourceText: String = ""
    @State private var isLoading = true
    @State private var errorText: String? = nil

    @State private var showEditor = false
    @State private var draftText: String = ""

    @State private var favorites: Set<String> = []

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.00),
                        Color(red: 0.91, green: 0.95, blue: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    header

                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(tr("טוען הסבר...", "Loading explanation..."))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(alignment: stackAlignment, spacing: 14) {
                                VStack(alignment: stackAlignment, spacing: 10) {
                                    Text(tr("הסבר", "Explanation"))
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundStyle(Color.black.opacity(0.82))
                                        .frame(maxWidth: .infinity, alignment: frameAlignment)

                                    Text(explanationText.isEmpty ? tr("אין כרגע הסבר לתרגיל הזה.", "There is no explanation for this exercise yet.") : explanationText)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.78))
                                        .frame(maxWidth: .infinity, alignment: frameAlignment)
                                        .multilineTextAlignment(textAlignment)
                                        .lineSpacing(5)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color.white.opacity(0.94))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )

                                if let errorText, !errorText.isEmpty {
                                    Text(errorText)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(textAlignment)
                                }

                                infoCard
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(tr("סגור", "Close"))
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.blue.opacity(0.86))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditor) {
                explanationEditorSheet
            }
            .task {
                loadFavorites()
                await loadExplanation()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.gray.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.95))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    draftText = explanationText
                    showEditor = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Color.blue)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.95))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            VStack(alignment: stackAlignment, spacing: 4) {
                Text(hit.displayName)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)

                Text("\(isEnglish ? hit.belt.id.capitalized : hit.belt.heb)\(hit.topic.isEmpty ? "" : " · \(hit.topic)")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var infoCard: some View {
        VStack(alignment: stackAlignment, spacing: 8) {
            HStack(spacing: 8) {
                if !isEnglish {
                    Spacer(minLength: 0)
                }

                Text(tr("מסך אמת", "Live Screen"))
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Color.black.opacity(0.76))

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.green.opacity(0.85))

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
                : (
                    isEnglish
                    ? "Explanation source: \(explanationSourceText)"
                    : "מקור ההסבר: \(explanationSourceText)"
                )
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)

            if !branch.isEmpty || !groupKey.isEmpty {
                Text(
                    isEnglish
                    ? "Forum: \(branch) / \(groupKey)"
                    : "פורום: \(branch) / \(groupKey)"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.46))
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var explanationEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 8) {
                    Text(tr("עריכת הסבר", "Edit Explanation"))
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(hit.displayName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                TextEditor(text: $draftText)
                    .padding(12)
                    .frame(minHeight: 280)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .multilineTextAlignment(.trailing)

                if let errorText, !errorText.isEmpty {
                    Text(errorText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(textAlignment)
                }

                HStack(spacing: 12) {
                    Button {
                        showEditor = false
                    } label: {
                        Text(tr("בטל", "Cancel"))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await saveExplanation() }
                    } label: {
                        Text(tr("שמור", "Save"))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(Color.blue.opacity(0.86))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isFavorite: Bool {
        favorites.contains(normalizedFavoriteId(hit.item))
    }

    private func loadExplanation() async {
        isLoading = true
        errorText = nil
        explanationSourceText = ""

        do {
            let snap = try await db.collection("exercise_explanations")
                .document(documentId)
                .getDocument()

            let firestoreText = (snap.data()?["text"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !firestoreText.isEmpty {
                explanationText = cleanExplanationText(firestoreText)
                explanationSourceText = "Firestore"
                isLoading = false
                return
            }

            let sharedText = findExplanationForHit(
                belt: hit.belt,
                rawItem: hit.item,
                topic: hit.topic
            )

            explanationText = sharedText
            explanationSourceText = "Shared Explanations"

        } catch {
            let sharedText = findExplanationForHit(
                belt: hit.belt,
                rawItem: hit.item,
                topic: hit.topic
            )

            explanationText = sharedText
            explanationSourceText = "Shared Explanations"
            errorText = tr(
                "Firestore לא החזיר הסבר, מוצג הסבר מקומי מהאפליקציה.",
                "Firestore did not return an explanation, showing a local app explanation."
            )
        }

        isLoading = false
    }

    private func findExplanationForHit(
        belt: Belt,
        rawItem: String,
        topic: String
    ) -> String {
        let explanations = Explanations()

        let raw = rawItem.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = hit.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanDisplay = cleanExplanationKey(display)
        let cleanRaw = cleanExplanationKey(raw)

        let beforeParentheses = cleanDisplay
            .components(separatedBy: "(")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? cleanDisplay

        let afterDoubleColon = raw
            .components(separatedBy: "::")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? raw

        let afterColon = raw
            .components(separatedBy: ":")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? raw

        let candidates = [
            raw,
            display,
            cleanRaw,
            cleanDisplay,
            beforeParentheses,
            afterDoubleColon,
            afterColon,
            topic.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .reduce(into: [String]()) { result, item in
            if !result.contains(item) {
                result.append(item)
            }
        }

        for candidate in candidates {
            let value = explanations.get(belt: belt, item: candidate)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if isRealExplanation(value) {
                return cleanExplanationText(value)
            }
        }

        return tr("אין כרגע הסבר לתרגיל הזה.", "There is no explanation for this exercise yet.")
    }

    private func cleanExplanationKey(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanExplanationText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("::") {
            return trimmed
                .components(separatedBy: "::")
                .dropFirst()
                .joined(separator: "::")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private func isRealExplanation(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty { return false }
        if trimmed.hasPrefix("הסבר מפורט על") { return false }
        if trimmed.hasPrefix("אין כרגע") { return false }

        return true
    }

    private func saveExplanation() async {
        errorText = nil

        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await db.collection("exercise_explanations")
                .document(documentId)
                .setData([
                    "beltId": hit.belt.id,
                    "beltHeb": hit.belt.heb,
                    "topic": hit.topic,
                    "item": hit.item,
                    "itemNormalized": normalizedFavoriteId(hit.item),
                    "text": trimmed,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "updatedByUid": Auth.auth().currentUser?.uid as Any,
                    "updatedByEmail": Auth.auth().currentUser?.email as Any
                ], merge: true)

            explanationText = trimmed
            showEditor = false
        } catch {
            errorText = tr(
                "שגיאה בשמירת הסבר: \(error.localizedDescription)",
                "Failed to save explanation: \(error.localizedDescription)"
            )
        }
    }

    private func loadFavorites() {
        let stored = UserDefaults.standard.stringArray(forKey: "forum_exercise_favorites") ?? []
        favorites = Set(stored)
    }

    private func toggleFavorite() {
        let key = normalizedFavoriteId(hit.item)
        if favorites.contains(key) {
            favorites.remove(key)
        } else {
            favorites.insert(key)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "forum_exercise_favorites")
    }

    private var documentId: String {
        "\(hit.belt.id)__\(normalizedFavoriteId(hit.item))"
    }

    private func normalizedFavoriteId(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "  ", with: " ")
            .lowercased()
    }
}

// MARK: - Helpers

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        self.isEmpty ? fallback : self
    }
}
