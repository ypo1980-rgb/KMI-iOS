import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct MessageCenterItem: Identifiable, Hashable {
    let id: String
    let titleHe: String
    let titleEn: String
    let message: String
    let createdAtMillis: Int64
    let read: Bool
    let deleted: Bool
    let senderNameHe: String
    let senderNameEn: String
    let region: String
    let branch: String
    let groups: [String]
}

@MainActor
final class MessageCenterViewModel: ObservableObject {

    @Published private(set)
    var messages: [MessageCenterItem] = []

    @Published private(set)
    var unreadCount = 0

    @Published private(set)
    var isLoading = false

    /*
     * קוד שגיאה פנימי בלבד.
     * טקסט למשתמש יוצג בשפת האפליקציה במסך.
     */
    @Published private(set)
    var errorMessage: String?

    private var listenerRegistration: ListenerRegistration?
    private var listeningUid: String?
    private var listenerRequestID = UUID()

    func startListening() {
        let uid = Auth.auth().currentUser?.uid
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        guard !uid.isEmpty else {
            stopListening()
            messages = []
            unreadCount = 0
            isLoading = false
            errorMessage = "not_signed_in"
            return
        }

        if listenerRegistration != nil,
           listeningUid == uid {
            return
        }

        let userChanged = listeningUid != uid

        stopListening()

        if userChanged {
            messages = []
            unreadCount = 0
        }

        listeningUid = uid
        isLoading = true
        errorMessage = nil

        let requestID = listenerRequestID

        listenerRegistration = Firestore.firestore()
            .collectionGroup("recipients")
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                /*
                 * ממירים את מסמכי Firestore לערכי נתונים
                 * לפני העדכון בממשק.
                 */
                let items: [MessageCenterItem]? =
                    snapshot.map { snapshot in
                        snapshot.documents.compactMap { document in
                            let data = document.data()

                            if data["deleted"] as? Bool == true {
                                return nil
                            }

                            func text(_ key: String) -> String {
                                (data[key] as? String ?? "")
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                            }

                            let storedId = text("broadcastId")
                            let parentId =
                                document.reference.parent.parent?.documentID
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ) ?? ""

                            let id = storedId.isEmpty
                                ? parentId
                                : storedId

                            guard !id.isEmpty else {
                                return nil
                            }

                            let message = (
                                data["message"] as? String
                                ?? data["text"] as? String
                                ?? data["body"] as? String
                                ?? ""
                            )
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )

                            let senderHe = text("senderNameHe")
                            let senderEn = text("senderNameEn")

                            let groups = (data["groups"] as? [Any] ?? [])
                                .compactMap { value -> String? in
                                    let clean = String(describing: value)
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        )

                                    return clean.isEmpty ? nil : clean
                                }

                            return MessageCenterItem(
                                id: id,
                                titleHe: text("titleHe"),
                                titleEn: text("titleEn"),
                                message: message,
                                createdAtMillis:
                                    (data["createdAtMillis"] as? NSNumber)?
                                        .int64Value ?? 0,
                                read: data["read"] as? Bool ?? false,
                                deleted: false,
                                senderNameHe: senderHe.isEmpty
                                    ? "צוות ק.מ.י"
                                    : senderHe,
                                senderNameEn: senderEn.isEmpty
                                    ? "K.M.I Team"
                                    : senderEn,
                                region: text("region"),
                                branch: text("branch"),
                                groups: groups
                            )
                        }
                        .sorted {
                            $0.createdAtMillis > $1.createdAtMillis
                        }
                    }

                let failed = error != nil

                Task { @MainActor [weak self] in
                    guard let self,
                          self.listenerRequestID == requestID,
                          self.listeningUid == uid else {
                        return
                    }

                    self.isLoading = false

                    guard !failed,
                          let items else {
                        /*
                         * שגיאת רשת אינה מוחקת
                         * הודעות שכבר נטענו.
                         */
                        self.errorMessage = "messages_load_failed"
                        return
                    }

                    self.messages = items
                    self.unreadCount = items.filter {
                        !$0.read
                    }.count
                    self.errorMessage = nil
                }
            }
    }

    func markAsRead(_ message: MessageCenterItem) {
        guard !message.read else {
            return
        }

        updateRecipient(
            message: message,
            fields: [
                "read": true,
                "readAt": FieldValue.serverTimestamp()
            ],
            failureCode: "message_read_failed"
        )
    }

    func deleteMessage(_ message: MessageCenterItem) {
        updateRecipient(
            message: message,
            fields: [
                "deleted": true,
                "deletedAt": FieldValue.serverTimestamp()
            ],
            failureCode: "message_delete_failed"
        )
    }

    private func updateRecipient(
        message: MessageCenterItem,
        fields: [String: Any],
        failureCode: String
    ) {
        let uid = Auth.auth().currentUser?.uid
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        let broadcastId = message.id
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !uid.isEmpty,
              !broadcastId.isEmpty else {
            return
        }

        Firestore.firestore()
            .collection("coachBroadcasts")
            .document(broadcastId)
            .collection("recipients")
            .document(uid)
            .updateData(fields) { [weak self] error in
                guard error != nil else {
                    return
                }

                Task { @MainActor [weak self] in
                    guard let self,
                          Auth.auth().currentUser?.uid == uid else {
                        return
                    }

                    self.errorMessage = failureCode
                }
            }
    }

    func stopListening() {
        listenerRequestID = UUID()

        listenerRegistration?.remove()
        listenerRegistration = nil

        /*
         * שומרים את זהות בעל הנתונים בזיכרון,
         * כדי לנקות אותם אם משתמש אחר מתחבר.
         */
        isLoading = false
    }

    deinit {
        listenerRegistration?.remove()
    }
}
