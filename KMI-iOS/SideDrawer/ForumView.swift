import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import UniformTypeIdentifiers
import AVKit

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

private enum ForumAccess {
    static func isManager(_ ud: UserDefaults) -> Bool { ud.bool(forKey: "is_manager") }
    static func isTrialActive(_ ud: UserDefaults) -> Bool { ud.bool(forKey: "is_trial_active") }
    static func hasFullAccess(_ ud: UserDefaults) -> Bool { ud.bool(forKey: "has_full_access") }
}

#if canImport(FirebaseStorage)
private struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("forum_video_\(UUID().uuidString).mov")

            try FileManager.default.copyItem(at: received.file, to: tmp)
            return .init(url: tmp)
        }
    }
}
#endif

// MARK: - View

struct ForumView: View {

    let onClose: () -> Void

    @State private var errorText: String? = nil

    @State private var canUseExtras: Bool = false
    @State private var lockText: String = ""

    @State private var branch: String = ""
    @State private var groupKey: String = ""
    @State private var fullName: String = ""
    @State private var email: String = ""

    @State private var messages: [ForumUiMessage] = []

    @State private var input: String = ""
    @State private var editingMessageId: String? = nil
    @State private var editText: String = ""

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
    }

    // MARK: - UI

    private var lockedView: some View {
        VStack(spacing: 12) {
            Text("🔒 גישה לפורום")
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.white)

            Text(lockText.isEmpty ? "מסך הפורום זמין למנויים בלבד." : lockText)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button(action: onClose) {
                Text("סגור")
                    .font(.body.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Spacer()
        }
        .padding(.top, 24)
    }

    private var missingGroupView: some View {
        VStack(spacing: 10) {
            Text("לא אותרו סניף/קבוצה במשתמש")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)

            Text("ודאו ש-\"branch\" ו-\"groupKey\" מוגדרים בפרופיל.")
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button(action: onClose) {
                Text("סגור")
                    .font(.body.weight(.bold))
                    .frame(width: 140, height: 44)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 24)
    }

    private var chatView: some View {
        VStack(spacing: 10) {

            HStack(spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("סניף: \(branch)  •  קבוצה: \(groupKey)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.30))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Divider().opacity(0.25).padding(.horizontal, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        Color.clear.frame(height: 6).id("__BOTTOM__")
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
                HStack {
                    Text(attachedMediaType == "image" ? "תמונה מצורפת לשליחה" : "סרטון מצורף לשליחה")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Button {
                        clearAttachment()
                    } label: {
                        Text("הסר")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
                .padding(.horizontal, 12)
            }
            #endif

            composer
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private func messageBubble(_ msg: ForumUiMessage) -> some View {
        let bubble = msg.isMine ? Color(red: 0.11, green: 0.65, blue: 0.91) : Color.black.opacity(0.35)

        return HStack {
            if msg.isMine { Spacer(minLength: 24) }

            VStack(alignment: .trailing, spacing: 6) {

                HStack(spacing: 8) {
                    if msg.isMine {
                        Menu {
                            Button("ערוך") {
                                editingMessageId = msg.id
                                editText = msg.text
                                input = ""
                                #if canImport(FirebaseStorage)
                                clearAttachment()
                                #endif
                            }
                            Button("מחק", role: .destructive) {
                                Task { await deleteMessage(msg) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Color.white.opacity(0.9))
                                .padding(.horizontal, 6)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(msg.authorName.isEmpty ? msg.authorEmail : msg.authorName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                        Text(formatDate(msg.createdAt))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.70))
                    }
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 290, alignment: .trailing)
                }

                if let urlStr = msg.mediaUrl, let type = msg.mediaType, let url = URL(string: urlStr) {
                    if type == "image" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().tint(.white).frame(height: 160)
                            case .success(let image):
                                image.resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: 290)
                                    .frame(height: 180)
                                    .clipped()
                            default:
                                Text("שגיאה בטעינת תמונה")
                                    .font(.footnote)
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .frame(height: 120)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if type == "video" {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "video.fill")
                                Text("פתח סרטון")
                                    .font(.body.weight(.bold))
                                Spacer()
                                Image(systemName: "chevron.left")
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: 290)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(bubble)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if !msg.isMine { Spacer(minLength: 24) }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {

            HStack(spacing: 8) {

                #if canImport(FirebaseStorage)
                VStack(spacing: 6) {
                    PhotosPicker(selection: $imagePickerItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    PhotosPicker(selection: $videoPickerItem, matching: .videos, photoLibrary: .shared()) {
                        Image(systemName: "video.fill")
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
                #endif

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.30))

                    TextEditor(text: composerBinding)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44, maxHeight: 110)
                        .multilineTextAlignment(.trailing)

                    if currentComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(editingMessageId == nil ? "כתוב הודעה..." : "עריכת הודעה...")
                            .foregroundStyle(Color.white.opacity(0.55))
                            .padding(.trailing, 14)
                            .padding(.top, 10)
                    }
                }

                Button {
                    Task { await sendOrUpdate() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.5)
            }

            if let err = errorText, !err.isEmpty {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .frame(maxWidth: .infinity, alignment: .trailing)
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

        let ud = UserDefaults.standard

        fullName = ud.string(forKey: "fullName") ?? ""
        email = ud.string(forKey: "email") ?? ""

        branch = (ud.string(forKey: "branch") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let direct = (ud.string(forKey: "groupKey") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty {
            groupKey = direct
        } else {
            let age = (ud.string(forKey: "age_group") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !age.isEmpty {
                groupKey = age
            } else {
                groupKey = (ud.string(forKey: "group") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let isManager = ForumAccess.isManager(ud)
        let isTrial = ForumAccess.isTrialActive(ud)
        let hasFull = ForumAccess.hasFullAccess(ud)

        canUseExtras = hasFull || isManager

        if !canUseExtras {
            if isTrial && !hasFull {
                lockText = "במהלך תקופת הניסיון מסך הפורום נעול.\nאחרי רכישת מנוי המסך ייפתח עבורך."
            } else {
                lockText = "מסך הפורום זמין למנויים בלבד.\nכדי להמשיך יש לרכוש מנוי פעיל."
            }
            return
        }

        Task { await ensureAnonAuth() }
        startListener()
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
                errorText = "שגיאה בטעינת הודעות: \(err.localizedDescription)"
                return
            }

            let currentUid = Auth.auth().currentUser?.uid

            let list: [ForumUiMessage] = snap?.documents.compactMap { doc in
                let data = doc.data()

                let ts = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let authorName = data["authorName"] as? String ?? ""
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

            messages = list
        }
    }

    private func ensureAnonAuth() async {
        if Auth.auth().currentUser != nil { return }
        do {
            _ = try await Auth.auth().signInAnonymously()
        } catch {
            await MainActor.run {
                errorText = "שגיאת התחברות: \(error.localizedDescription)"
            }
        }
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
                errorText = "שגיאה בשמירה: \(error.localizedDescription)"
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
                errorText = "שגיאה במחיקה: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Uploads (only when Storage exists)

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
            await MainActor.run { errorText = "שגיאה בטעינת תמונה: \(error.localizedDescription)" }
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
            await MainActor.run { errorText = "שגיאה בטעינת וידאו: \(error.localizedDescription)" }
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

    // MARK: - Utils

    private func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "he_IL")
        df.dateFormat = "dd/MM HH:mm"
        return df.string(from: d)
    }
}
