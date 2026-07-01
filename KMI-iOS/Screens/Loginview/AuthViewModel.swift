import Foundation
import Combine
import Shared
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var isSignedIn: Bool = false
    @Published var errorText: String? = nil
    @Published var issuedCoachCode: String? = nil

    // ✅ role (trainee / coach) לצביעת UI והרשאות
    @Published var userRole: String = "trainee"

    // ✅ נתוני שיוך למסך הבית
    @Published var userFullName: String = ""
    @Published var userRegion: String = ""
    @Published var userBranch: String = ""
    @Published var userGroup: String = ""

    // ✅ cache מקומי ל-UI מהיר (לא מקור אמת)
    private let roleDefaultsKey = "kmi.user.role"

    // ✅ חגורה שנרשמה + חגורה הבאה
    @Published var registeredBelt: Belt? = nil
    @Published var nextBelt: Belt = BeltFlow.defaultBelt

    #if canImport(FirebaseAuth)
    private var handle: AuthStateDidChangeListenerHandle?
    #endif

    init() {
        // לא מתחילים עם loading שחוסם את המסך הראשון.
        // ה־UI עולה מיד, והפרופיל נטען ברקע אחרי בדיקת Auth.
        isLoading = false
        isSignedIn = false

        // ✅ UI מהיר עד שנמשוך מהשרת
        self.userRole = UserDefaults.standard.string(forKey: roleDefaultsKey) ?? "trainee"
    }
    
    func forceSignOutForFreshLogin() {
        isSignedIn = false
        registeredBelt = nil
        nextBelt = BeltFlow.defaultBelt
        userRole = "trainee"
        userFullName = ""
        userRegion = ""
        userBranch = ""
        userGroup = ""

        let ud = UserDefaults.standard

        ud.removeObject(forKey: "kmi.device.authorized.uid")
        ud.removeObject(forKey: "is_logged_in")
        ud.removeObject(forKey: "forum_open_from_push")
        ud.removeObject(forKey: "forum_push_message_id")
        ud.removeObject(forKey: "forum_push_room_id")
        ud.removeObject(forKey: "forum_push_room_name")
        ud.removeObject(forKey: "forum_push_branch_id")
        ud.removeObject(forKey: "forum_push_group_key")
        ud.removeObject(forKey: "forum_push_sender_id")
        ud.removeObject(forKey: "forum_push_received_at")
        ud.removeObject(forKey: "coach_code")

        ud.set("trainee", forKey: roleDefaultsKey)
        ud.set("trainee", forKey: "user_role")
        ud.set("trainee", forKey: "role")
        ud.set("trainee", forKey: "userRole")
        ud.set("trainee", forKey: "profile_role")

        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch { }
        #endif
    }

    // MARK: - Lifecycle (called from AuthGateView)
    func start() {
        #if canImport(FirebaseAuth)
        guard handle == nil else { return }

        // לא חוסמים את מסך הפתיחה בזמן בדיקת Firebase/Auth.
        isLoading = false

        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            Task { @MainActor in
                self.isSignedIn = (user != nil)

                if let user {
                    // מציגים את האפליקציה מיד.
                    // פרופיל, חגורה, תפקיד ושיוך נטענים ברקע ומעדכנים את ה־UI כשהם מגיעים.
                    self.isLoading = false

                    Task { @MainActor in
                        await self.loadUserProfile(uid: user.uid)
                        self.isLoading = false
                    }

                } else {
                    self.registeredBelt = nil
                    self.nextBelt = BeltFlow.defaultBelt
                    self.userRole = "trainee"
                    self.userFullName = ""
                    self.userRegion = ""
                    self.userBranch = ""
                    self.userGroup = ""

                    let ud = UserDefaults.standard
                    ud.set("trainee", forKey: self.roleDefaultsKey)
                    ud.removeObject(forKey: "kmi.user.region")
                    ud.removeObject(forKey: "kmi.user.branch")
                    ud.removeObject(forKey: "kmi.user.group")
                    ud.removeObject(forKey: "coach_code")

                    self.isLoading = false
                }
            }
        }
        #else
        isSignedIn = false
        isLoading = false
        #endif
    }
    
    func stop() {
        #if canImport(FirebaseAuth)
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
            self.handle = nil
        }
        #endif
    }

    private func nextDeveloperCoachCode(for email: String) -> String? {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedEmail == "ypo1980@gmail.com" else { return nil }

        let defaults = UserDefaults.standard
        let key = "kmi.dev.coach.reset.toggle"

        let nextCode = (defaults.bool(forKey: key) ? "123456" : "654321")
        defaults.set(!defaults.bool(forKey: key), forKey: key)

        return nextCode
    }

    private func isDeveloperDualRoleUser(email: String, uid: String) -> Bool {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let normalizedUid = uid
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizedEmail == "ypo1980@gmail.com"
            || normalizedUid == "DBoyoVVpsrVUX0ukhKwNyQlKUKY2"
    }

    private func persistTrainingAssignmentToDefaults(
        region: String,
        branch: String,
        group: String
    ) {
        let ud = UserDefaults.standard

        let cleanRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)

        ud.set(cleanRegion, forKey: "kmi.user.region")
        ud.set(cleanBranch, forKey: "kmi.user.branch")
        ud.set(cleanGroup, forKey: "kmi.user.group")

        ud.set(cleanRegion, forKey: "region")

        ud.set(cleanBranch, forKey: "branch")
        ud.set(cleanBranch, forKey: "activeBranch")
        ud.set(cleanBranch, forKey: "active_branch")
        ud.set(cleanBranch, forKey: "selected_branch")
        ud.set(cleanBranch, forKey: "current_branch")
        ud.set(cleanBranch, forKey: "branchesCsv")

        ud.set(cleanGroup, forKey: "group")
        ud.set(cleanGroup, forKey: "groupKey")
        ud.set(cleanGroup, forKey: "group_key")
        ud.set(cleanGroup, forKey: "activeGroup")
        ud.set(cleanGroup, forKey: "active_group")
        ud.set(cleanGroup, forKey: "primaryGroup")
        ud.set(cleanGroup, forKey: "age_group")
        ud.set(cleanGroup, forKey: "ageGroup")
        ud.set(cleanGroup, forKey: "age_groups")
        ud.set(cleanGroup, forKey: "current_groupKey")
        ud.set(cleanGroup, forKey: "selected_groupKey")
    }

#if canImport(FirebaseFirestore)
    
private func ensureUserProfileDocumentExists(
    uid: String,
    existingData: [String: Any]
) async throws -> [String: Any] {
    let ud = UserDefaults.standard

    let existingBranches =
        (existingData["branches"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

    let existingGroups =
        (existingData["groups"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

    let existingSingleBranch =
        (existingData["branch"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let existingSingleGroup =
        ((existingData["group"] as? String) ??
         (existingData["age_group"] as? String) ??
         (existingData["ageGroup"] as? String) ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let fullName =
        ((existingData["fullName"] as? String) ??
         ud.string(forKey: "fullName") ??
         ud.string(forKey: "full_name") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let email =
        ((existingData["email"] as? String) ??
         Auth.auth().currentUser?.email ??
         ud.string(forKey: "email") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    let phone =
        ((existingData["phone"] as? String) ??
         ud.string(forKey: "phone") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let region =
        ((existingData["region"] as? String) ??
         ud.string(forKey: "kmi.user.region") ??
         ud.string(forKey: "region") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let branchFromDefaults =
        (ud.string(forKey: "kmi.user.branch") ??
         ud.string(forKey: "branch") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let groupFromDefaults =
        (ud.string(forKey: "kmi.user.group") ??
         ud.string(forKey: "group") ??
         ud.string(forKey: "age_group") ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let resolvedBranch = existingBranches.first ?? (existingSingleBranch.isEmpty ? branchFromDefaults : existingSingleBranch)
    let resolvedGroup = existingGroups.first ?? (existingSingleGroup.isEmpty ? groupFromDefaults : existingSingleGroup)
    
    let role =
        ((existingData["role"] as? String) ??
         ud.string(forKey: "user_role") ??
         self.userRole)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    let shouldRepair =
        existingData.isEmpty ||
        existingBranches.isEmpty ||
        existingGroups.isEmpty ||
        (existingData["fullName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false

    if !shouldRepair {
        return existingData
    }

    var repairedData = existingData

    repairedData["uid"] = uid
    repairedData["fullName"] = fullName
    repairedData["email"] = email
    repairedData["emailLower"] = email
    repairedData["phone"] = phone
    repairedData["region"] = region
    repairedData["role"] = role
    repairedData["updatedAt"] = FieldValue.serverTimestamp()

    if !resolvedBranch.isEmpty {
        repairedData["branch"] = resolvedBranch
        repairedData["branches"] = [resolvedBranch]
    }

    if !resolvedGroup.isEmpty {
        repairedData["group"] = resolvedGroup
        repairedData["groups"] = [resolvedGroup]
        repairedData["age_group"] = resolvedGroup
    }

    if existingData["createdAt"] == nil {
        repairedData["createdAt"] = FieldValue.serverTimestamp()
    }

    let db = Firestore.firestore()
    try await db.collection("users")
        .document(uid)
        .setData(repairedData, merge: true)

    return repairedData
}
#endif

    // MARK: - Helpers
    func refreshCurrentUser() {
        #if canImport(FirebaseAuth)
        isLoading = true
        Auth.auth().currentUser?.reload(completion: { [weak self] err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err {
                    self?.errorText = err.localizedDescription
                }
            }
        })
        #endif
    }

    func reloadProfileIfSignedIn() {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }

        Task { @MainActor in
            await self.loadUserProfile(uid: uid)
            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()
        }
        #endif
    }

    func saveTrainingAssignment(branch: String, group: String) {
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)

        self.userBranch = cleanBranch
        self.userGroup = cleanGroup

        self.persistTrainingAssignmentToDefaults(
            region: self.userRegion,
            branch: cleanBranch,
            group: cleanGroup
        )

        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task { @MainActor in
            #if canImport(FirebaseFirestore)
            do {
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .setData([
                        "branch": cleanBranch,
                        "activeBranch": cleanBranch,
                        "active_branch": cleanBranch,
                        "branchesCsv": cleanBranch,
                        "branches": cleanBranch.isEmpty ? [] : [cleanBranch],
                        "group": cleanGroup,
                        "groupKey": cleanGroup,
                        "group_key": cleanGroup,
                        "activeGroup": cleanGroup,
                        "active_group": cleanGroup,
                        "primaryGroup": cleanGroup,
                        "groups": cleanGroup.isEmpty ? [] : [cleanGroup],
                        "age_group": cleanGroup,
                        "ageGroup": cleanGroup,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], merge: true)

                KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
                KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

            } catch {
                self.errorText = error.localizedDescription
            }
            #endif
        }
        #endif
    }

    // MARK: - Actions
    func signIn(
        email: String,
        password: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        errorText = nil

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty, !p.isEmpty else {
            errorText = "נא למלא אימייל וסיסמה"
            completion?(false)
            return
        }

        isLoading = true

        #if canImport(FirebaseAuth)
        Auth.auth().signIn(withEmail: e, password: p) { [weak self] result, err in
            guard let self else {
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }

            if let err {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorText = err.localizedDescription
                    completion?(false)
                }
                return
            }

            guard let uid = result?.user.uid else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorText = "לא התקבל מזהה משתמש"
                    completion?(false)
                }
                return
            }

            Task { @MainActor in
                let defaults = UserDefaults.standard
                defaults.set(e, forKey: "remember_username")
                defaults.set(e, forKey: "email")
                defaults.set(true, forKey: "is_logged_in")

                await self.loadUserProfile(uid: uid)

                KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
                KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

                self.errorText = nil
                self.isSignedIn = true
                self.isLoading = false
                completion?(true)
            }
        }
        #else
        isLoading = false
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        completion?(false)
        #endif
    }

    func signInWithUsernameOrEmail(
        identifier: String,
        password: String,
        expectedRole: String,
        coachCode: String?
    ) async -> Bool {
        errorText = nil

        let rawId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedRole = expectedRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !rawId.isEmpty, !rawPassword.isEmpty else {
            errorText = "נא למלא מייל וסיסמה"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseAuth)
        #if canImport(FirebaseFirestore)
        do {
            let loginEmail: String

            let normalizedIdentifier = rawId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let isEmail =
                normalizedIdentifier.contains("@") &&
                normalizedIdentifier.contains(".") &&
                !normalizedIdentifier.contains(" ")

            if isEmail {
                loginEmail = normalizedIdentifier
            } else {
                let db = Firestore.firestore()
                let snap = try await db.collection("users")
                    .whereField("usernameLower", isEqualTo: normalizedIdentifier)
                    .limit(to: 1)
                    .getDocuments()

                guard let data = snap.documents.first?.data(),
                      let resolvedEmail = (data["emailLower"] as? String) ?? (data["email"] as? String),
                      !resolvedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    errorText = "המייל לא נמצא"
                    return false
                }

                loginEmail = resolvedEmail
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthDataResult, Error>) in
                Auth.auth().signIn(withEmail: loginEmail, password: rawPassword) { res, err in
                    if let err {
                        cont.resume(throwing: err)
                    } else if let res {
                        cont.resume(returning: res)
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "Auth",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing auth result"]
                        ))
                    }
                }
            }

            let uid = result.user.uid
            let db = Firestore.firestore()
            let userSnap = try await db.collection("users").document(uid).getDocument()
            let data = userSnap.data() ?? [:]

            let serverRole = ((data["role"] as? String) ?? "trainee").lowercased()
            let loginEmailNormalized = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let serverPhoneRaw =
                (data["phone"] as? String) ??
                (data["phoneNumber"] as? String) ??
                (data["mobile"] as? String) ??
                ""

            let serverPhoneNormalized = serverPhoneRaw.filter { $0.isNumber }

            let isCoachAccount =
                serverRole == "coach" ||
                serverRole == "trainer" ||
                (data["coachApproved"] as? Bool ?? false)

            let isDeveloperDualRole = isDeveloperDualRoleUser(
                email: loginEmailNormalized,
                uid: uid
            )

            if wantedRole == "coach" {
                let approved = data["coachApproved"] as? Bool ?? false
                let whitelistedCoach = CoachWhitelist.isWhitelisted(
                    phone: serverPhoneNormalized,
                    email: loginEmailNormalized
                )

                if !approved && !whitelistedCoach {
                    errorText = "המשתמש אינו מוגדר כמאמן"
                    try? Auth.auth().signOut()
                    return false
                }
            } else if wantedRole == "trainee" {
                if isCoachAccount && !isDeveloperDualRole {
                    errorText = "החשבון הזה מוגדר כחשבון מאמן. יש להיכנס דרך טאב מאמן ולהזין את קוד המאמן שקיבלת."
                    try? Auth.auth().signOut()
                    return false
                }

                if serverRole != "trainee" && !isCoachAccount {
                    errorText = "המשתמש אינו מוגדר כמתאמן"
                    try? Auth.auth().signOut()
                    return false
                }
            }

            if wantedRole == "coach" {
                let typedCoachCode = (coachCode ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let specialCoachCode: String? = {
                    if loginEmailNormalized == "ypo1980@gmail.com" {
                        return "123456"
                    }
                    return nil
                }()

                let storedCoachCode = (
                    specialCoachCode ??
                    ((data["coachCode"] as? String) ?? "")
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                if typedCoachCode.isEmpty {
                    errorText = "יש להזין קוד מאמן"
                    try? Auth.auth().signOut()
                    return false
                }

                if typedCoachCode != storedCoachCode {
                    errorText = "קוד מאמן שגוי"
                    try? Auth.auth().signOut()
                    return false
                }
            }
            
            let defaults = UserDefaults.standard
            defaults.set(rawId, forKey: "remember_username")
            defaults.set(rawPassword, forKey: "remember_password")
            defaults.set(true, forKey: "is_logged_in")
            defaults.set(wantedRole, forKey: "user_role")

            if wantedRole == "coach", let coachCode {
                defaults.set(coachCode.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "coach_code")
            } else {
                defaults.removeObject(forKey: "coach_code")
            }

            await loadUserProfile(uid: uid)
            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

            isSignedIn = true
            errorText = nil
            return true

        } catch {

            if let nsError = error as NSError? {

                switch nsError.code {

                case AuthErrorCode.userNotFound.rawValue:
                    errorText = "המשתמש לא נמצא במערכת"

                case AuthErrorCode.wrongPassword.rawValue:
                    errorText = "סיסמה שגויה"

                case AuthErrorCode.invalidEmail.rawValue:
                    errorText = "כתובת האימייל אינה תקינה"

                case AuthErrorCode.invalidCredential.rawValue:
                    errorText = "מייל או סיסמה שגויים"

                default:
                    errorText = nsError.localizedDescription
                }

            } else {
                errorText = error.localizedDescription
            }

            return false
        }
#else
        errorText = "FirebaseFirestore לא מותקן בפרויקט"
        return false
        #endif
        #else
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        return false
        #endif
    }

    func signInWithGoogle(
        expectedRole: String,
        coachCode: String?
    ) async -> Bool {
        errorText = nil

        let wantedRole = expectedRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseAuth)
        #if canImport(FirebaseFirestore)
        #if canImport(GoogleSignIn)

        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                errorText = "חסר clientID בקובץ GoogleService-Info.plist"
                return false
            }

            guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController
            else {
                errorText = "לא נמצא מסך פעיל להצגת התחברות Google"
                return false
            }

            var presentingViewController = rootViewController
            while let presented = presentingViewController.presentedViewController {
                presentingViewController = presented
            }

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            let googleResult = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )

            guard let idToken = googleResult.user.idToken?.tokenString else {
                errorText = "לא התקבל Google ID Token"
                return false
            }

            let accessToken = googleResult.user.accessToken.tokenString

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )

            let authResult = try await Auth.auth().signIn(with: credential)

            let uid = authResult.user.uid
            let loginEmail = (authResult.user.email ?? googleResult.user.profile?.email ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let db = Firestore.firestore()
            let userSnap = try await db.collection("users")
                .document(uid)
                .getDocument()

            let rawData = userSnap.data() ?? [:]

            let data = try await ensureUserProfileDocumentExists(
                uid: uid,
                existingData: rawData
            )

            let serverRole = ((data["role"] as? String) ?? "trainee")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let serverPhoneRaw =
                (data["phone"] as? String) ??
                (data["phoneNumber"] as? String) ??
                (data["mobile"] as? String) ??
                ""

            let serverPhoneNormalized = serverPhoneRaw.filter { $0.isNumber }

            let isCoachAccount =
                serverRole == "coach" ||
                serverRole == "trainer" ||
                (data["coachApproved"] as? Bool ?? false)

            let isDeveloperDualRole = isDeveloperDualRoleUser(
                email: loginEmail,
                uid: uid
            )

            if wantedRole == "coach" {
                let approved = data["coachApproved"] as? Bool ?? false
                let whitelistedCoach = CoachWhitelist.isWhitelisted(
                    phone: serverPhoneNormalized,
                    email: loginEmail
                )

                if !approved && !whitelistedCoach {
                    errorText = "המשתמש אינו מוגדר כמאמן"
                    try? Auth.auth().signOut()
                    return false
                }

                let typedCoachCode = (coachCode ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let specialCoachCode: String? = {
                    if loginEmail == "ypo1980@gmail.com" {
                        return "123456"
                    }
                    return nil
                }()

                let storedCoachCode = (
                    specialCoachCode ??
                    ((data["coachCode"] as? String) ?? "")
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

                if typedCoachCode.isEmpty {
                    errorText = "יש להזין קוד מאמן"
                    try? Auth.auth().signOut()
                    return false
                }

                if typedCoachCode != storedCoachCode {
                    errorText = "קוד מאמן שגוי"
                    try? Auth.auth().signOut()
                    return false
                }

            } else if wantedRole == "trainee" {
                if isCoachAccount && !isDeveloperDualRole {
                    errorText = "החשבון הזה מוגדר כחשבון מאמן. יש להיכנס דרך טאב מאמן ולהזין את קוד המאמן שקיבלת."
                    try? Auth.auth().signOut()
                    return false
                }

                if serverRole != "trainee" && !isCoachAccount {
                    errorText = "המשתמש אינו מוגדר כמתאמן"
                    try? Auth.auth().signOut()
                    return false
                }
            }

            let defaults = UserDefaults.standard
            defaults.set(loginEmail, forKey: "remember_username")
            defaults.set(loginEmail, forKey: "email")
            defaults.set(true, forKey: "is_logged_in")
            defaults.set(wantedRole, forKey: "user_role")

            if wantedRole == "coach", let coachCode {
                defaults.set(coachCode.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "coach_code")
            } else {
                defaults.removeObject(forKey: "coach_code")
            }

            await loadUserProfile(uid: uid)
            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

            isSignedIn = true
            errorText = nil

            return true

        } catch {
            if let nsError = error as NSError? {
                switch nsError.code {
                case AuthErrorCode.invalidCredential.rawValue:
                    errorText = "התחברות Google נכשלה"

                case AuthErrorCode.userDisabled.rawValue:
                    errorText = "המשתמש חסום במערכת"

                case AuthErrorCode.networkError.rawValue:
                    errorText = "יש בעיית רשת. בדוק חיבור לאינטרנט ונסה שוב"

                default:
                    errorText = nsError.localizedDescription
                }
            } else {
                errorText = error.localizedDescription
            }

            return false
        }

        #else
        errorText = "GoogleSignIn לא מותקן בפרויקט"
        return false
        #endif
        #else
        errorText = "FirebaseFirestore לא מותקן בפרויקט"
        return false
        #endif
        #else
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        return false
        #endif
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        errorText = nil

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty, e.contains("@"), e.contains(".") else {
            let msg = "נא להזין כתובת אימייל תקינה"
            errorText = msg
            completion(false, msg)
            return
        }

        isLoading = true

#if canImport(FirebaseAuth)
Auth.auth().sendPasswordReset(withEmail: e) { [weak self] err in
    DispatchQueue.main.async {
        self?.isLoading = false

        if let err {
            let nsError = err as NSError

            let message: String
            switch nsError.code {
            case AuthErrorCode.userNotFound.rawValue:
                message = "לא נמצא משתמש עם כתובת המייל הזאת"

            case AuthErrorCode.invalidEmail.rawValue:
                message = "כתובת האימייל אינה תקינה"

            case AuthErrorCode.invalidRecipientEmail.rawValue:
                message = "כתובת המייל לא תקינה לשליחת איפוס סיסמה"

            default:
                message = err.localizedDescription
            }

            self?.errorText = message
            completion(false, message)
        } else {
            self?.errorText = nil
            completion(true, nil)
        }
    }
}
#else
        isLoading = false
        let msg = "FirebaseAuth לא מותקן בפרויקט"
        errorText = msg
        completion(false, msg)
        #endif
    }

    func signUp(email: String, password: String) {
        errorText = nil
        
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty, !p.isEmpty else {
            errorText = "נא למלא אימייל וסיסמה"
            return
        }

        isLoading = true

        #if canImport(FirebaseAuth)
        Auth.auth().createUser(withEmail: e, password: p) { [weak self] _, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err {
                    self?.errorText = err.localizedDescription
                }
            }
        }
        #else
        isLoading = false
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        #endif
    }

    func signInAnonymously() {
        errorText = nil
        isLoading = true

        #if canImport(FirebaseAuth)
        Auth.auth().signInAnonymously { [weak self] _, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err {
                    self?.errorText = err.localizedDescription
                }
            }
        }
        #else
        isLoading = false
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        #endif
    }

    func signOut() {
        errorText = nil

        let ud = UserDefaults.standard

        ud.removeObject(forKey: "kmi.device.authorized.uid")
        ud.removeObject(forKey: "is_logged_in")
        ud.removeObject(forKey: "forum_open_from_push")
        ud.removeObject(forKey: "forum_push_message_id")
        ud.removeObject(forKey: "forum_push_room_id")
        ud.removeObject(forKey: "forum_push_room_name")
        ud.removeObject(forKey: "forum_push_branch_id")
        ud.removeObject(forKey: "forum_push_group_key")
        ud.removeObject(forKey: "forum_push_sender_id")
        ud.removeObject(forKey: "forum_push_received_at")

        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            self.isSignedIn = false
            self.registeredBelt = nil
            self.nextBelt = BeltFlow.defaultBelt
            self.userRole = "trainee"
            self.userFullName = ""
            self.userRegion = ""
            self.userBranch = ""
            self.userGroup = ""
        } catch {
            errorText = error.localizedDescription
        }
        #else
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        #endif
    }

    // MARK: - Coach Code Reset

    func regenerateCoachCode(
        identifier: String,
        password: String
    ) async -> String? {

        let rawId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawId.isEmpty else {
            errorText = "יש להזין מייל"
            return nil
        }

        guard !rawPassword.isEmpty else {
            errorText = "יש להזין סיסמה כדי להפיק קוד מאמן חדש"
            return nil
        }

        errorText = nil

        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseAuth)

        do {

            let db = Firestore.firestore()

            // נזהה אימייל או username
            let loginEmail: String

            let normalizedIdentifier = rawId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let isEmail =
                normalizedIdentifier.contains("@") &&
                normalizedIdentifier.contains(".") &&
                !normalizedIdentifier.contains(" ")

            if isEmail {

                loginEmail = normalizedIdentifier

            } else {

                let snap = try await db.collection("users")
                    .whereField("usernameLower", isEqualTo: normalizedIdentifier)
                    .limit(to: 1)
                    .getDocuments()

                guard let data = snap.documents.first?.data(),
                      let email = (data["emailLower"] as? String) ?? (data["email"] as? String),
                      !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    errorText = "המייל לא נמצא"
                    return nil
                }

                loginEmail = email
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }

            if let devCode = nextDeveloperCoachCode(for: loginEmail) {
                UserDefaults.standard.set(devCode, forKey: "coach_code")
                errorText = nil
                return devCode
            }

            // חיפוש המשתמש
            let snap = try await db.collection("users")
                .whereField("emailLower", isEqualTo: loginEmail)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snap.documents.first else {
                errorText = "המייל לא נמצא"
                return nil
            }

            let uid = doc.documentID
            let data = doc.data()

            let role = (data["role"] as? String ?? "").lowercased()
            let approved = data["coachApproved"] as? Bool ?? false

            if role != "coach" && !approved {
                errorText = "המשתמש אינו מאמן"
                return nil
            }

            // ✅ שכבת אבטחה: אימות מלא עם האימייל והסיסמה לפני איפוס קוד
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthDataResult, Error>) in
                Auth.auth().signIn(withEmail: loginEmail, password: rawPassword) { res, err in
                    if let err {
                        cont.resume(throwing: err)
                    } else if let res {
                        cont.resume(returning: res)
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "Auth",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing auth result"]
                        ))
                    }
                }
            }

            guard Auth.auth().currentUser?.uid == uid else {
                try? Auth.auth().signOut()
                errorText = "אימות המשתמש נכשל"
                return nil
            }

            // יצירת קוד חדש
            let newCode = CoachCodeGenerator.generate()
            try await db.collection("users")
                .document(uid)
                .updateData([
                    "coachCode": newCode,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            UserDefaults.standard.set(newCode, forKey: "coach_code")
            try? Auth.auth().signOut()

            return newCode

        } catch {
            if let nsError = error as NSError? {
                switch nsError.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    errorText = "הסיסמה שגויה"

                case AuthErrorCode.invalidCredential.rawValue:
                    errorText = "מייל או סיסמה שגויים"

                case AuthErrorCode.userNotFound.rawValue:
                    errorText = "המייל לא נמצא"

                case AuthErrorCode.invalidEmail.rawValue:
                    errorText = "כתובת האימייל אינה תקינה"

                case AuthErrorCode.tooManyRequests.rawValue:
                    errorText = "בוצעו יותר מדי ניסיונות. נסה שוב מאוחר יותר"

                case AuthErrorCode.networkError.rawValue:
                    errorText = "יש בעיית רשת. בדוק חיבור לאינטרנט ונסה שוב"

                default:
                    errorText = nsError.localizedDescription
                }
            } else {
                errorText = error.localizedDescription
            }
            return nil
        }
        #else
        errorText = "FirebaseAuth לא מותקן"
        return nil
        #endif
        #else
        errorText = "FirebaseFirestore לא מותקן"
        return nil
        #endif
    }
    
    // MARK: - Registration (Auth + Profile Save)
    func registerAndSaveProfile(form: RegistrationFormState) async {

        // מונע לחיצה כפולה על הרשמה
        if isLoading { return }

        errorText = nil
        let email = form.emailTrimmed
        let password = form.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard form.acceptsTerms else {
            errorText = "צריך לאשר תנאי שימוש"
            return
        }

        guard !email.isEmpty, password.count >= 6 else {
            errorText = "נא למלא אימייל וסיסמה (לפחות 6 תווים)"
            return
        }

        guard !form.fullNameTrimmed.isEmpty else {
            errorText = "נא למלא שם מלא"
            return
        }

        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseAuth)
        
        do {
            let uid = try await createUserLegacy(email: email, password: password)
            
#if canImport(FirebaseFirestore)
do {
    let db = Firestore.firestore()

    issuedCoachCode = nil

    // ✅ שומר את כל הטופס כפרופיל משתמש
    var userData = form.toFirestoreDictionary(uid: uid)

    // beltId עוזר לטעינת חגורה בהמשך
    if userData["beltId"] == nil {
        userData["beltId"] = form.belt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ✅ שומרים שיוך סניף וקבוצה כמו באנדרואיד
    let branchesFromForm =
        (userData["branches"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

    let groupsFromForm =
        (userData["groups"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

    let singleBranchFromForm =
        (userData["branch"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    let singleGroupFromForm =
        ((userData["group"] as? String) ??
         (userData["age_group"] as? String) ??
         "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    let branchClean = branchesFromForm.first ?? singleBranchFromForm
    let groupClean = groupsFromForm.first ?? singleGroupFromForm

    if !branchClean.isEmpty {
        userData["branch"] = branchClean
        userData["branches"] = [branchClean]
    }

    if !groupClean.isEmpty {
        userData["group"] = groupClean
        userData["groups"] = [groupClean]
        userData["age_group"] = groupClean
    }

    // ✅ מאמן מורשה בלבד + יצירת קוד אוטומטי כמו באנדרואיד
    let generatedCoachCode: String?
    if form.role == .coach {
        let normalizedPhone = form.phone.filter { $0.isNumber }
        let normalizedEmail = form.emailTrimmed.lowercased()

        guard CoachWhitelist.isWhitelisted(
            phone: normalizedPhone,
            email: normalizedEmail
        ) else {
            self.errorText = "הרישום כמאמן מותר רק למאמנים מורשים"
            return
        }

        let code: String

        if normalizedEmail == "ypo1980@gmail.com" {
            code = "123456"
        } else {
            code = CoachCodeGenerator.generate()
        }

        generatedCoachCode = code
        userData["coachCode"] = code
        userData["coachApproved"] = true

    } else {
        generatedCoachCode = nil
        userData["coachApproved"] = false
    }

    try await db.collection("users")
        .document(uid)
        .setData(userData, merge: true)

    // ✅ שמירה מקומית
    form.persistToUserDefaults()

    if let generatedCoachCode {
        UserDefaults.standard.set(generatedCoachCode, forKey: "coach_code")
        issuedCoachCode = generatedCoachCode
    } else {
        UserDefaults.standard.removeObject(forKey: "coach_code")
    }

} catch {
    self.errorText = "שמירת פרופיל נכשלה: \(error.localizedDescription)"
    return
}

#endif

            // ✅ מרעננים את הפרופיל מהשרת
            await loadUserProfile(uid: uid)
            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

                    } catch {

            if let nsError = error as NSError?,
               nsError.code == AuthErrorCode.emailAlreadyInUse.rawValue {

                self.errorText = "האימייל כבר רשום. מעבירים למסך התחברות..."

                #if canImport(FirebaseAuth)
                try? Auth.auth().signOut()
                #endif

            } else {
                self.errorText = error.localizedDescription
            }
        }
        
        #else
        errorText = "FirebaseAuth לא מותקן בפרויקט"
        #endif
    }
    
    // MARK: - Private Firebase helpers

    #if canImport(FirebaseAuth)
    private func createUserLegacy(email: String, password: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            Auth.auth().createUser(withEmail: email, password: password) { res, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }

                guard let uid = res?.user.uid else {
                    cont.resume(
                        throwing: NSError(
                            domain: "Auth",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing UID"]
                        )
                    )
                    return
                }

                cont.resume(returning: uid)
            }
        }
    }
    #endif

#if canImport(FirebaseFirestore)
private func loadUserProfileFromFirestore(uid: String) async {
    do {


        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)

        let snap: DocumentSnapshot
            if #available(iOS 15.0, *) {
                snap = try await ref.getDocument()
            } else {
                snap = try await withCheckedThrowingContinuation { cont in
                    ref.getDocument { snap, err in
                        if let err {
                            cont.resume(throwing: err)
                            return
                        }

                        if let snap {
                            cont.resume(returning: snap)
                            return
                        }

                        cont.resume(
                            throwing: NSError(
                                domain: "Firestore",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Missing snapshot"]
                            )
                        )
                    }
                }
            }

        let rawData = snap.data() ?? [:]



        let data = try await ensureUserProfileDocumentExists(
            uid: uid,
            existingData: rawData
        )



        // ✅ role מהשרת (עם fallback רחב יותר)
        let roleFromServer =
            (data["role"] as? String) ??
            (data["userRole"] as? String) ??
                (data["user_type"] as? String) ??
                (data["type"] as? String) ??
                ""

            let normalizedRole = roleFromServer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let fallbackEmail =
                Auth.auth().currentUser?.email?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            let resolvedRole: String = {
                if normalizedRole == "coach" || normalizedRole == "trainer" || normalizedRole == "מאמן" {
                    return "coach"
                }

                if (data["coachApproved"] as? Bool) == true {
                    return "coach"
                }

                if fallbackEmail == "ypo1980@gmail.com" {
                    return "coach"
                }

                return "trainee"
            }()

            self.userRole = resolvedRole
            UserDefaults.standard.set(resolvedRole, forKey: self.roleDefaultsKey)



            let rawBelt =
                (data["beltId"] as? String) ??
                (data["belt"] as? String) ??
                (data["registeredBelt"] as? String)

            let belt = BeltFlow.belt(fromRaw: rawBelt)
            self.registeredBelt = belt
            self.nextBelt = BeltFlow.nextBeltForUser(registeredBelt: belt)

            // ✅ region / branch / group למסך הבית
            let fullName =
                (data["fullName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let region =
                (data["region"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let branchesArray =
            (data["branches"] as? [String])?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []

        let singleBranch =
            (data["branch"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let branches = branchesArray.isEmpty
            ? (singleBranch.isEmpty ? [] : [singleBranch])
            : branchesArray

        let groupsArray =
            (data["groups"] as? [String])?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []

        let singleGroup =
            ((data["group"] as? String) ??
             (data["age_group"] as? String) ??
             (data["ageGroup"] as? String) ??
             "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let groups = groupsArray.isEmpty
            ? (singleGroup.isEmpty ? [] : [singleGroup])
            : groupsArray

        let primaryBranch = branches.first ?? ""
        let primaryGroup = groups.first ?? ""



        self.userFullName = fullName
        self.userRegion = region
        self.userBranch = primaryBranch
        self.userGroup = primaryGroup

        let ud = UserDefaults.standard

        ud.set(fullName, forKey: "fullName")
        ud.set(fullName, forKey: "name")
        ud.set(fullName, forKey: "displayName")

        if let email = Auth.auth().currentUser?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !email.isEmpty {
            ud.set(email, forKey: "email")
            ud.set(email, forKey: "user_email")
        }

        ud.set(resolvedRole, forKey: "user_role")
        ud.set(resolvedRole, forKey: "role")
        ud.set(resolvedRole, forKey: "userRole")
        ud.set(resolvedRole, forKey: "profile_role")

        if let belt {
            ud.set(belt.id, forKey: "belt")
            ud.set(belt.id, forKey: "beltId")
            ud.set(belt.id, forKey: "currentBeltId")
            ud.set(belt.id, forKey: "registeredBelt")
        }

        self.persistTrainingAssignmentToDefaults(
            region: region,
            branch: primaryBranch,
            group: primaryGroup
        )

        KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
        KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

        } catch {
            self.registeredBelt = nil
            self.nextBelt = BeltFlow.defaultBelt
            self.userFullName = ""
            self.userRegion = ""
            self.userBranch = ""
            self.userGroup = ""
        }
    }
    #endif

    private func loadUserProfile(uid: String) async {
        #if canImport(FirebaseFirestore)
        await loadUserProfileFromFirestore(uid: uid)
        #else
        self.registeredBelt = nil
        self.nextBelt = BeltFlow.defaultBelt
        #endif
    }
}
