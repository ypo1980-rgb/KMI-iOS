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
    let branch: String
    let groupKey: String
    let authorName: String
    let authorEmail: String
    let authorUid: String?
    let text: String
    let createdAt: Date
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

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    @State private var errorText: String? = nil

    @State private var canUseExtras: Bool = false
    @State private var lockText: String = ""

    @State private var branch: String = ""
    @State private var groupKey: String = ""
    @State private var fullName: String = ""
    @State private var email: String = ""

    @State private var messages: [ForumUiMessage] = []
    @State private var showParticipantsSheet: Bool = false

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

    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.01, green: 0.05, blue: 0.14),
            Color(red: 0.07, green: 0.10, blue: 0.23),
            Color(red: 0.11, green: 0.33, blue: 0.80)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

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
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 68, height: 68)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.94))
                }

                Text(tr("גישה לפורום", "Forum Access"))
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text(lockText.isEmpty ? tr("מסך הפורום זמין למנויים בלבד.", "The forum is available to subscribers only.") : lockText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                Button(action: onClose) {
                    Text(tr("סגור", "Close"))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.26))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private var missingGroupView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 68, height: 68)

                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.94))
                }

                Text(tr("לא אותרו סניף או קבוצה", "Branch or group not found"))
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text(tr("ודאו שפרטי הסניף והקבוצה מוגדרים בפרופיל המשתמש.", "Please make sure your branch and group are set in your profile."))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                Button(action: onClose) {
                    Text(tr("סגור", "Close"))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.26))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private var chatView: some View {
        VStack(spacing: 10) {

            VStack(alignment: stackAlignment, spacing: 8) {
                HStack(spacing: 10) {
                    if isEnglish {
                        Button(action: onClose) {
                            forumCircleIcon(backChevronName)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: stackAlignment, spacing: 3) {
                            forumHeaderTexts
                        }

                        Spacer(minLength: 0)

                        forumCircleIcon("bubble.left.and.bubble.right.fill")
                    } else {
                        forumCircleIcon("bubble.left.and.bubble.right.fill")

                        Spacer(minLength: 0)

                        VStack(alignment: stackAlignment, spacing: 3) {
                            forumHeaderTexts
                        }

                        Button(action: onClose) {
                            forumCircleIcon(backChevronName)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 12)

            if !forumParticipants.isEmpty {
                participantsCard
                    .padding(.horizontal, 12)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
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
        Button {
            clearAttachment()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white.opacity(0.92))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)

        Spacer(minLength: 0)

        Text(
            attachedMediaType == "image"
            ? tr("תמונה מצורפת לשליחה", "Image attached")
            : tr("סרטון מצורף לשליחה", "Video attached")
        )
            .font(.footnote.weight(.bold))
            .foregroundStyle(Color.white.opacity(0.90))
            .lineLimit(1)

        Image(systemName: attachedMediaType == "image" ? "photo.fill" : "video.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.90))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.26))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
    )
    .padding(.horizontal, 12)
}
#endif

            composer
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var forumHeaderTexts: some View {
        VStack(alignment: stackAlignment, spacing: 3) {
            Text(tr("פורום הסניף", "Branch Forum"))
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .multilineTextAlignment(textAlignment)

            Text(
                isEnglish
                ? "Branch: \(branch)  •  Group: \(groupKey)"
                : "סניף: \(branch)  •  קבוצה: \(groupKey)"
            )
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .multilineTextAlignment(textAlignment)
            .lineLimit(2)
        }
    }

    private func forumCircleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
    
    private var forumParticipants: [ForumParticipantUi] {
        let grouped = Dictionary(grouping: messages) { msg in
            msg.authorUid ??
            msg.authorEmail.ifEmpty(msg.authorName)
                .ifEmpty("unknown_\(msg.id)")
        }

        var participants = grouped.compactMap { key, groupedMessages -> ForumParticipantUi? in
            guard let sample = groupedMessages.first else { return nil }

            let displayName = sample.authorName
                .ifEmpty(sample.authorEmail)
                .ifEmpty("משתתף")

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
            HStack(spacing: 10) {
                Image(systemName: forwardChevronName)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color.white.opacity(0.72))

                Spacer(minLength: 0)

                Text(isEnglish ? "Forum participants (\(forumParticipants.count))" : "משתתפים בפורום (\(forumParticipants.count))")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var participantsSheet: some View {
        NavigationStack {
            List {
                ForEach(forumParticipants) { participant in
                    HStack(spacing: 12) {
                        if participant.isMe {
                            Text(tr("אני", "Me"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.12))
                                )
                        }

                        Spacer(minLength: 0)

                        Text(participant.name)
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(textAlignment)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Circle()
                            .fill(participant.isMe ? Color.blue.opacity(0.85) : Color.gray.opacity(0.35))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: participant.isMe ? "person.fill.checkmark" : "person.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .padding(.vertical, 6)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle(isEnglish ? "Forum participants (\(forumParticipants.count))" : "משתתפים בפורום (\(forumParticipants.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("סגור", "Close")) {
                        showParticipantsSheet = false
                    }
                }
            }
        }
    }

    private func messageBubble(_ msg: ForumUiMessage) -> some View {
        let bubbleColor = msg.isMine
            ? Color(red: 0.10, green: 0.58, blue: 0.38)
            : Color.black.opacity(0.34)

        let bubbleShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        let mineAlignment: Alignment = isEnglish ? .trailing : .leading
        let otherAlignment: Alignment = isEnglish ? .leading : .trailing
        let bubbleAlignment: Alignment = msg.isMine ? mineAlignment : otherAlignment
        let innerAlignment: HorizontalAlignment = isEnglish ? .leading : .trailing
        let innerTextAlignment: TextAlignment = isEnglish ? .leading : .trailing

        return HStack(alignment: .bottom, spacing: 0) {
            if msg.isMine == isEnglish {
                Spacer(minLength: 42)
            }

            VStack(alignment: innerAlignment, spacing: 6) {

                HStack(alignment: .top, spacing: 8) {
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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: innerAlignment, spacing: 2) {
                        Text(msg.authorName.isEmpty ? msg.authorEmail : msg.authorName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: bubbleAlignment)
                            .multilineTextAlignment(innerTextAlignment)

                        Text(formatDate(msg.createdAt))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .frame(maxWidth: .infinity, alignment: bubbleAlignment)
                            .multilineTextAlignment(innerTextAlignment)
                    }
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white)
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
                                    .frame(width: 260, height: 160)

                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 260, height: 180)
                                    .clipped()

                            default:
                                Text(tr("שגיאה בטעינת תמונה", "Failed to load image"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .frame(width: 260, height: 120)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    } else if type == "video" {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 18, weight: .bold))

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(tr("סרטון מצורף", "Attached video"))
                                        .font(.system(size: 15, weight: .heavy))

                                    Text(tr("לחיצה לפתיחה בנגן", "Tap to open in player"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.white.opacity(0.72))
                                }

                                Spacer(minLength: 0)

                                Image(systemName: forwardChevronName)
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(width: 260)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.18))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(bubbleColor)
            .clipShape(bubbleShape)
            .overlay(
                bubbleShape
                    .stroke(Color.white.opacity(msg.isMine ? 0.10 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

            if msg.isMine != isEnglish {
                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity, alignment: bubbleAlignment)
    }

    private var composer: some View {
        VStack(spacing: 8) {

            HStack(alignment: .bottom, spacing: 8) {

                #if canImport(FirebaseStorage)
                HStack(spacing: 6) {
                    PhotosPicker(selection: $imagePickerItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $videoPickerItem, matching: .videos, photoLibrary: .shared()) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                }
                #endif

                ZStack(alignment: isEnglish ? .topLeading : .topTrailing) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    TextEditor(text: composerBinding)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 46, maxHeight: 112)
                        .multilineTextAlignment(textAlignment)

                    if currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(editingMessageId == nil ? tr("כתוב הודעה...", "Write a message...") : tr("עריכת הודעה...", "Editing message..."))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.52))
                            .padding(isEnglish ? .leading : .trailing, 14)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }

                Button {
                    Task { await sendOrUpdate() }
                } label: {
                    Image(systemName: editingMessageId == nil ? "paperplane.fill" : "checkmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle()
                                .fill(canSend ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(canSend ? 0.16 : 0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.55)
            }

            if editingMessageId != nil {
                HStack(spacing: 10) {
                    Button {
                        editingMessageId = nil
                        editText = ""
                    } label: {
                        Text(tr("ביטול עריכה", "Cancel edit"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(tr("מצב עריכת הודעה", "Editing message"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.76))
                }
                .padding(.horizontal, 6)
            }

            if let err = errorText, !err.isEmpty {
                Text(err)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
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
            lockText = tr("יש להתחבר לאפליקציה כדי להשתמש בפורום הסניף.", "Please sign in to use the branch forum.")
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

                canUseExtras = hasBranchAndGroup

                if !hasBranchAndGroup {
                    lockText = tr(
                        "לא אותרו סניף או קבוצה במשתמש.\nיש להשלים את פרטי הסניף והקבוצה כדי להשתמש בפורום.",
                        "No branch or group was found for this user.\nPlease complete your branch and group details to use the forum."
                    )
                    stopListener()
                    return
                }

                lockText = ""
                startListener()
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
    }

    private func startListener() {
        stopListener()

        guard !branch.isEmpty, !groupKey.isEmpty else { return }

        let query = db.collection("branches")
            .document(branch)
            .collection("messages")
            .whereField("groupKey", isEqualTo: groupKey)
            .order(by: "createdAt", descending: false)

        listener = query.addSnapshotListener { snap, err in
            if let err {
                errorText = tr("שגיאה בטעינת הודעות: \(err.localizedDescription)", "Failed to load messages: \(err.localizedDescription)")

                #if DEBUG
                print("🟣 FORUM listener error =", err.localizedDescription)
                print("🟣 FORUM branch =", branch)
                print("🟣 FORUM groupKey =", groupKey)
                #endif

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

                var msg = ForumUiMessage(
                    id: doc.documentID,
                    branch: data["branch"] as? String ?? branch,
                    groupKey: data["groupKey"] as? String ?? groupKey,
                    authorName: authorName,
                    authorEmail: authorEmail,
                    authorUid: authorUid,
                    text: txt,
                    createdAt: ts,
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

        if branch.isEmpty || groupKey.isEmpty { return }

        let uid = Auth.auth().currentUser?.uid

        do {
            var base: [String: Any] = [
                "branch": branch,
                "groupKey": groupKey,
                "authorName": fullName,
                "authorEmail": email,
                "authorUid": uid as Any,
                "text": trimmed
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

            let col = db.collection("branches").document(branch).collection("messages")

            if let editId = editingMessageId {
                base["updatedAt"] = FieldValue.serverTimestamp()
                try await col.document(editId).setData(base, merge: true)
            } else {
                base["createdAt"] = FieldValue.serverTimestamp()
                _ = try await col.addDocument(data: base)
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
                errorText = tr("שגיאה בשמירה: \(error.localizedDescription)", "Failed to save: \(error.localizedDescription)")
            }
        }
    }

    private func deleteMessage(_ msg: ForumUiMessage) async {
        guard msg.isMine else { return }
        do {
            try await db.collection("branches")
                .document(branch)
                .collection("messages")
                .document(msg.id)
                .delete()
        } catch {
            await MainActor.run {
                errorText = tr("שגיאה במחיקה: \(error.localizedDescription)", "Failed to delete: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Uploads

    #if canImport(FirebaseStorage)
    private func uploadImage(data: Data, uid: String?) async throws -> String {
        let safeUid = uid ?? "anon"
        let path = "forum_media/\(branch)/\(groupKey)/\(safeUid)/\(Int(Date().timeIntervalSince1970))_img.jpg"
        let ref = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    private func uploadVideo(fileUrl: URL, uid: String?) async throws -> String {
        let safeUid = uid ?? "anon"
        let path = "forum_media/\(branch)/\(groupKey)/\(safeUid)/\(Int(Date().timeIntervalSince1970))_vid.mov"
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
