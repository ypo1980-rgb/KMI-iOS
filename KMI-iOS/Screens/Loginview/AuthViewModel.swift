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

    @Published private(set) var userBranchAssignments:
        [RegistrationFormState.BranchAssignment] = []

    @Published private(set) var isProfileLoading = false
    @Published private(set) var profileLoadFailed = false
    @Published private(set) var loadedProfileUID: String?

    private var profileLoadRequestID = UUID()

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

        let defaults = UserDefaults.standard

        let storedRole =
            defaults.string(forKey: roleDefaultsKey) ??
            defaults.string(forKey: "user_role") ??
            defaults.string(forKey: "role") ??
            defaults.string(forKey: "userRole") ??
            defaults.string(forKey: "profile_role") ??
            "trainee"

        self.userRole = normalizedActiveRole(
            storedRole
        )
    }

    private func normalizedActiveRole(
        _ rawValue: String
    ) -> String {
        let normalized = rawValue
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        switch normalized {
        case "coach",
             "trainer",
             "instructor",
             "coach_user",
             "kmi_coach",
             "מאמן":
            return "coach"

        default:
            return "trainee"
        }
    }

    func setActiveUserRole(
        _ rawValue: String
    ) {
        let resolvedRole =
            normalizedActiveRole(rawValue)

        userRole = resolvedRole

        let defaults = UserDefaults.standard

        defaults.set(
            resolvedRole,
            forKey: roleDefaultsKey
        )
        defaults.set(
            resolvedRole,
            forKey: "user_role"
        )
        defaults.set(
            resolvedRole,
            forKey: "role"
        )
        defaults.set(
            resolvedRole,
            forKey: "userRole"
        )
        defaults.set(
            resolvedRole,
            forKey: "profile_role"
        )
        defaults.set(
            resolvedRole,
            forKey: "active_user_mode"
        )
        defaults.set(
            resolvedRole,
            forKey: "last_active_app_role"
        )

        NotificationCenter.default.post(
            name: Notification.Name(
                "KMI_ACTIVE_ROLE_CHANGED"
            ),
            object: resolvedRole
        )
    }
    
    private func clearTrainingAssignmentsOnSignOut() {
        userBranchAssignments = []

        let defaults = UserDefaults.standard

        defaults.removeObject(
            forKey: RegistrationFormState
                .BranchAssignmentsCodec
                .preferenceKey
        )

        let keys = [
            "fullName",
            "full_name",
            "name",
            "displayName",
            "email",
            "user_email",
            "phone",
            "phone_number",
            "phoneNumber",
            "mobile",

            "regions",
            "selected_regions",
            "regions_json",
            "regions_csv",
            "branch_type",

            "birthDay",
            "birth_day",
            "birthMonth",
            "birth_month",
            "birthYear",
            "birth_year",
            "gender",
            "username",

            "subscribeSms",
            "wantsSms",
            "acceptsTerms",
            "authProvider",
            "google_login",

            "password",
            "user_password",
            "remember_password",

            "belt_he",

            "belt",
            "beltId",
            "currentBeltId",
            "registeredBelt",
            "current_belt",
            "belt_current",

            "kmi.user.region",
            "region",
            "active_region",

            "kmi.user.branch",
            "branch",
            "branches",
            "branches_json",
            "branchesCsv",
            "selected_branches",
            "active_branch",
            "activeBranch",
            "selected_branch",
            "current_branch",
            "branch2",
            "branch3",

            "kmi.user.group",
            "group",
            "groups",
            "groups_json",
            "groupsCsv",
            "selected_groups",
            "groupKey",
            "group_key",
            "active_group",
            "activeGroup",
            "primaryGroup",
            "age_group",
            "ageGroup",
            "age_groups",
            "current_groupKey",
            "selected_groupKey",

            "coach_code",
            "coachCode",

            "coach_broadcast_open_dialog",
            "coach_broadcast_open_from_push",
            "coach_broadcast_push_id",
            "coach_broadcast_push_received_at",

            "profile_completed",
            "registration_complete",
            "registration_form_completed",
            "registration_schema_version",
            "profile_completed_uid",
            "profile_completed_at",

            "active_user_mode",
            "last_active_app_role",

            "coach_authorized",
            "can_open_coach_drawer",
            "can_view_trainees",
            "can_manage_trainees",
            "can_manage_attendance",
            "can_manage_internal_exams",
            "can_view_payment_reports",
            "can_manage_payments",
            "can_send_broadcasts"
        ]

        for key in keys {
            defaults.removeObject(forKey: key)
        }

        TrainingReminderScheduler.shared.resetForSignedOutUser()
    }

    func forceSignOutForFreshLogin() {
        clearTrainingAssignmentsOnSignOut()

        profileLoadRequestID = UUID()
        isProfileLoading = false
        profileLoadFailed = false
        loadedProfileUID = nil

        isSignedIn = false
        registeredBelt = nil
        nextBelt = BeltFlow.defaultBelt
        setActiveUserRole("trainee")
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
                guard Auth.auth().currentUser?.uid == user?.uid else {
                    return
                }

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
                    self.clearTrainingAssignmentsOnSignOut()

                    self.profileLoadRequestID = UUID()
                    self.isProfileLoading = false
                    self.profileLoadFailed = false
                    self.loadedProfileUID = nil

                    self.registeredBelt = nil
                    self.nextBelt = BeltFlow.defaultBelt
                    self.setActiveUserRole("trainee")
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

    private func hasServerCoachAccess(
        uid: String
    ) async -> Bool {
        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            return false
        }

        let database = Firestore.firestore()

        do {
            let coachDocument = try await database
                .collection("authorizedCoaches")
                .document(uid)
                .getDocument()

            let data = coachDocument.data() ?? [:]

            let role = (data["role"] as? String ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

            if coachDocument.exists,
               data["active"] as? Bool == true,
               role == "coach",
               !Task.isCancelled,
               Auth.auth().currentUser?.uid == uid {
                return true
            }
        } catch {
            // ממשיכים לבדיקת הרשאת מנהל.
        }

        do {
            let adminDocument = try await database
                .collection("admins")
                .document(uid)
                .getDocument()

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid else {
                return false
            }

            return adminDocument.exists &&
                adminDocument.data()?["enabled"] as? Bool == true
        } catch {
            return false
        }
    }

    private func ensureUserProfileDocumentExists(
        uid: String,
        existingData: [String: Any]
    ) async throws -> [String: Any] {
        guard !Task.isCancelled,
              let currentUser = Auth.auth().currentUser,
              currentUser.uid == uid else {
            throw CancellationError()
        }

        func clean(_ value: String?) -> String {
            value?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
        }

        func normalizedValues(_ values: [String]) -> [String] {
            var seen = Set<String>()

            return values
                .map { clean($0) }
                .filter { !$0.isEmpty }
                .filter { seen.insert($0).inserted }
        }

        var patch: [String: Any] = [:]

        if existingData["uid"] == nil {
            patch["uid"] = uid
        }

        if clean(existingData["fullName"] as? String).isEmpty {
            let verifiedName = clean(currentUser.displayName)

            if !verifiedName.isEmpty {
                patch["fullName"] = verifiedName
            }
        }

        let serverEmail = clean(
            existingData["email"] as? String
        )

        let resolvedEmail = (
            serverEmail.isEmpty
                ? clean(currentUser.email)
                : serverEmail
        )
        .lowercased()

        if serverEmail.isEmpty && !resolvedEmail.isEmpty {
            patch["email"] = resolvedEmail
        }

        if clean(existingData["emailLower"] as? String).isEmpty,
           !resolvedEmail.isEmpty {
            patch["emailLower"] = resolvedEmail
        }

        if clean(existingData["phone"] as? String).isEmpty {
            let resolvedPhone = [
                clean(existingData["phoneNumber"] as? String),
                clean(existingData["mobile"] as? String),
                clean(currentUser.phoneNumber)
            ]
            .first { !$0.isEmpty } ?? ""

            if !resolvedPhone.isEmpty {
                patch["phone"] = resolvedPhone
            }
        }

        if existingData["branches"] == nil {
            let serverBranch = clean(
                existingData["branch"] as? String
            )

            let branches = normalizedValues([serverBranch])

            if !branches.isEmpty {
                patch["branches"] = branches
            }
        }

        if existingData["groups"] == nil {
            let serverGroup = [
                clean(existingData["group"] as? String),
                clean(existingData["age_group"] as? String),
                clean(existingData["ageGroup"] as? String)
            ]
            .first { !$0.isEmpty } ?? ""

            let groups = normalizedValues([serverGroup])

            if !groups.isEmpty {
                patch["groups"] = groups
            }
        }

        if existingData.isEmpty {
            patch["createdAt"] = FieldValue.serverTimestamp()
        }

        guard !patch.isEmpty else {
            return existingData
        }

        patch["updatedAt"] = FieldValue.serverTimestamp()

        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            throw CancellationError()
        }

        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(
                patch,
                merge: true
            )

        return existingData.merging(patch) { _, newValue in
            newValue
        }
    }
    #endif

    // MARK: - Helpers
    func refreshCurrentUser() {
#if canImport(FirebaseAuth)
guard let currentUser = Auth.auth().currentUser else {
    isLoading = false
    return
}

isLoading = true

currentUser.reload(completion: { [weak self] err in
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

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid else {
                return
            }

            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()
        }
        #endif
    }

    func saveTrainingAssignment(
        branch: String,
        group: String
    ) {
        #if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        #endif

        let cleanBranch = branch
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanGroup = group
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        /*
         * כאשר קיימים שיוכים מפורשים, הבחירה
         * הפעילה חייבת להתאים לסניף ולקבוצות שלו.
         */
        if !userBranchAssignments.isEmpty {
            guard let assignment =
                userBranchAssignments.first(where: {
                    $0.branch == cleanBranch
                }),
                (
                    assignment.groups.contains(cleanGroup) ||
                    (
                        assignment.groups.isEmpty &&
                        cleanGroup.isEmpty
                    )
                )
            else {
                return
            }
        }

        self.userBranch = cleanBranch
        self.userGroup = cleanGroup

        let defaults = UserDefaults.standard

        var storedBranches =
            (defaults.stringArray(forKey: "branches") ?? [])
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }

        var storedGroups =
            (defaults.stringArray(forKey: "groups") ?? [])
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }

        /*
         * תאימות לפרופילים ישנים שבהם עדיין לא נשמרו
         * מערכים מלאים אלא רק סניף וקבוצה יחידים.
         */
        if storedBranches.isEmpty && !cleanBranch.isEmpty {
            storedBranches = [cleanBranch]
        }

        if storedGroups.isEmpty && !cleanGroup.isEmpty {
            storedGroups = [cleanGroup]
        }

        /*
         * הפונקציה מעדכנת את הסניף והקבוצה הפעילים בלבד.
         */
        self.persistTrainingAssignmentToDefaults(
            region: self.userRegion,
            branch: cleanBranch,
            group: cleanGroup
        )

        /*
         * מחזירים את הרשימות המלאות לאחר עדכון
         * הערכים הפעילים, כדי שלא יצטמצמו לפריט יחיד.
         */
        defaults.set(
            storedBranches,
            forKey: "branches"
        )

        defaults.set(
            storedGroups,
            forKey: "groups"
        )

        defaults.set(
            storedBranches.joined(separator: ","),
            forKey: "branchesCsv"
        )

        defaults.set(
            storedGroups.joined(separator: ","),
            forKey: "groupsCsv"
        )

        defaults.set(
            cleanBranch,
            forKey: "activeBranch"
        )

        defaults.set(
            cleanBranch,
            forKey: "active_branch"
        )

        defaults.set(
            cleanGroup,
            forKey: "activeGroup"
        )

        defaults.set(
            cleanGroup,
            forKey: "active_group"
        )

#if canImport(FirebaseAuth)
Task { @MainActor in
    #if canImport(FirebaseFirestore)
    guard !Task.isCancelled,
          Auth.auth().currentUser?.uid == uid else {
        return
    }

    do {
                /*
                 * מעדכנים בשרת רק את הבחירה הפעילה.
                 * אין לכתוב כאן branches או groups משום
                 * שהם מכילים את כל בחירות המשתמש.
                 */
                try await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .setData(
                        [
                            "branch": cleanBranch,
                            "activeBranch": cleanBranch,
                            "active_branch": cleanBranch,

                            "group": cleanGroup,
                            "groupKey": cleanGroup,
                            "group_key": cleanGroup,
                            "activeGroup": cleanGroup,
                            "active_group": cleanGroup,
                            "primaryGroup": cleanGroup,
                            "age_group": cleanGroup,
                            "ageGroup": cleanGroup,

                            "updatedAt":
                                FieldValue.serverTimestamp()
                        ],
                        merge: true
                    )

        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            return
        }

        KmiPushManager.shared
            .savePendingFcmTokenAfterLoginIfNeeded()

        KmiPushManager.shared
            .refreshAndSaveFcmTokenIfPossible()

    } catch {
        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            return
        }

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

                guard !Task.isCancelled,
                      Auth.auth().currentUser?.uid == uid else {
                    completion?(false)
                    return
                }

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
        let wantedRole = expectedRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard wantedRole == "trainee" || wantedRole == "coach" else {
            return false
        }

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

            let isCoachAccount =
                serverRole == "coach" ||
                serverRole == "trainer" ||
                (data["coachApproved"] as? Bool ?? false)

            let isDeveloperDualRole = isDeveloperDualRoleUser(
                email: loginEmailNormalized,
                uid: uid
            )

            if wantedRole == "coach" {
                let authorized =
                    await hasServerCoachAccess(uid: uid)

                guard authorized else {
                    errorText =
                        "לא ניתן לאמת הרשאת מאמן. בדוק את החיבור ואת ההרשאה בשרת."
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

                let storedCoachCode =
                    (data["coachCode"] as? String ?? "")
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

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

            for key in [
                "remember_password",
                "password",
                "user_password"
            ] {
                defaults.removeObject(forKey: key)
            }

            defaults.set(true, forKey: "is_logged_in")
            setActiveUserRole(wantedRole)

            if wantedRole == "coach", let coachCode {
                defaults.set(coachCode.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "coach_code")
            } else {
                defaults.removeObject(forKey: "coach_code")
            }

            await loadUserProfile(uid: uid)

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid else {
                return false
            }

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

    private func activePresentingViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return nil
        }

        let window =
            windowScene.windows.first(where: { $0.isKeyWindow }) ??
            windowScene.windows.first(where: { !$0.isHidden })

        guard let rootViewController = window?.rootViewController else {
            return nil
        }

        func topViewController(
            from viewController: UIViewController
        ) -> UIViewController {
            if let presented = viewController.presentedViewController {
                return topViewController(from: presented)
            }

            if let navigationController =
                viewController as? UINavigationController,
               let visible = navigationController.visibleViewController {
                return topViewController(from: visible)
            }

            if let tabController =
                viewController as? UITabBarController,
               let selected = tabController.selectedViewController {
                return topViewController(from: selected)
            }

            if let splitController =
                viewController as? UISplitViewController,
               let last = splitController.viewControllers.last {
                return topViewController(from: last)
            }

            for child in viewController.children.reversed() {
                if child.viewIfLoaded?.window != nil {
                    return topViewController(from: child)
                }
            }

            return viewController
        }

        return topViewController(from: rootViewController)
    }
    
    func signInWithGoogle(
        expectedRole: String,
        coachCode: String?
    ) async -> Bool {
        errorText = nil

        let wantedRole = expectedRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard wantedRole == "trainee" || wantedRole == "coach" else {
            return false
        }

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

            guard let presentingViewController =
                activePresentingViewController()
            else {
                errorText = "לא נמצא מסך פעיל להצגת התחברות Google"
                return false
            }

            guard presentingViewController.viewIfLoaded?.window != nil else {
                errorText = "מסך ההתחברות עדיין אינו מוכן להצגת Google"
                return false
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
            let isCoachAccount =
                serverRole == "coach" ||
                serverRole == "trainer" ||
                (data["coachApproved"] as? Bool ?? false)

            let isDeveloperDualRole = isDeveloperDualRoleUser(
                email: loginEmail,
                uid: uid
            )

            if wantedRole == "coach" {
                let authorized =
                    await hasServerCoachAccess(uid: uid)

                guard authorized else {
                    errorText =
                        "לא ניתן לאמת הרשאת מאמן. בדוק את החיבור ואת ההרשאה בשרת."
                    try? Auth.auth().signOut()
                    return false
                }

                let typedCoachCode = (coachCode ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let storedCoachCode =
                    (data["coachCode"] as? String ?? "")
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

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
            setActiveUserRole(wantedRole)

            if wantedRole == "coach", let coachCode {
                defaults.set(coachCode.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "coach_code")
            } else {
                defaults.removeObject(forKey: "coach_code")
            }

            await loadUserProfile(uid: uid)

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid else {
                return false
            }

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

            self.clearTrainingAssignmentsOnSignOut()

            self.profileLoadRequestID = UUID()
            self.isProfileLoading = false
            self.profileLoadFailed = false
            self.loadedProfileUID = nil

            self.isSignedIn = false
            self.registeredBelt = nil
            self.nextBelt = BeltFlow.defaultBelt
            self.setActiveUserRole("trainee")
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

            let authorized = await hasServerCoachAccess(uid: uid)

            guard authorized else {
                try? Auth.auth().signOut()
                errorText =
                    "לא ניתן לאמת הרשאת מאמן. בדוק את החיבור ואת ההרשאה בשרת."
                return nil
            }

            guard !Task.isCancelled,
                  Auth.auth().currentUser?.uid == uid else {
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

#if canImport(FirebaseAuth)
let isGoogleRegistration =
    Auth.auth().currentUser?.providerData.contains {
        $0.providerID == "google.com"
    } == true
#else
let isGoogleRegistration = false
#endif

guard !email.isEmpty else {
    errorText = "נא למלא כתובת מייל"
    return
}

guard isGoogleRegistration || password.count >= 6 else {
    errorText = "נא למלא סיסמה באורך 6 תווים לפחות"
    return
}

guard form.role == .trainee else {
    errorText = "הרשאת מאמן ניתנת לאחר אישור מהשרת"
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
            let uid: String

            if isGoogleRegistration {
                guard let currentUser =
                    Auth.auth().currentUser,
                    !currentUser.uid.isEmpty else {
                    errorText = "יש להתחבר מחדש באמצעות Google"
                    return
                }

                let authenticatedEmail =
                    (currentUser.email ?? "")
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .lowercased()

                guard authenticatedEmail == email.lowercased() else {
                    errorText = "כתובת המייל חייבת להתאים לחשבון Google המחובר"
                    return
                }

                uid = currentUser.uid
            } else {
                do {
                    uid = try await createUserLegacy(
                        email: email,
                        password: password
                    )
                } catch {
                    let authError = error as NSError

                    guard authError.code ==
                        AuthErrorCode.emailAlreadyInUse.rawValue else {
                        throw error
                    }

                    /*
                     * כמו Android:
                     * מייל קיים מחייב אימות בסיסמה,
                     * ורק לאחריו ממשיכים לשמירת הפרופיל.
                     */
                    let result = try await Auth.auth()
                        .signIn(
                            withEmail: email,
                            password: password
                        )

                    uid = result.user.uid
                }
            }

#if canImport(FirebaseFirestore)
do {
    guard !Task.isCancelled,
          Auth.auth().currentUser?.uid == uid else {
        return
    }

    let db = Firestore.firestore()

    issuedCoachCode = nil

    // ✅ שומר את כל הטופס כפרופיל משתמש
    var userData = form.toFirestoreDictionary(uid: uid)

    // beltId עוזר לטעינת חגורה בהמשך
    if userData["beltId"] == nil {
        userData["beltId"] = form.currentBeltId
    }

    // ✅ שומרים את כל הסניפים וכל הקבוצות כמו באנדרואיד
    let branchesFromForm =
        (userData["branches"] as? [String])?
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .reduce(into: [String]()) { result, branch in
                if !result.contains(branch) {
                    result.append(branch)
                }
            } ?? []

    let groupsFromForm =
        (userData["groups"] as? [String])?
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter {
                !$0.isEmpty
            }
            .reduce(into: [String]()) { result, group in
                if !result.contains(group) {
                    result.append(group)
                }
            } ?? []

    let singleBranchFromForm =
        (userData["branch"] as? String)?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

    let singleGroupFromForm =
        (
            (userData["group"] as? String) ??
            (userData["age_group"] as? String) ??
            ""
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    let requestedActiveBranch = form.activeBranch
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    let requestedActiveGroup = form.activeGroup
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )

    let resolvedBranches: [String] = {
        if !branchesFromForm.isEmpty {
            return branchesFromForm
        }

        if !singleBranchFromForm.isEmpty {
            return [singleBranchFromForm]
        }

        return []
    }()

    let resolvedGroups: [String] = {
        if !groupsFromForm.isEmpty {
            return groupsFromForm
        }

        if !singleGroupFromForm.isEmpty {
            return [singleGroupFromForm]
        }

        return []
    }()

    let primaryBranch: String = {
        if resolvedBranches.contains(requestedActiveBranch) {
            return requestedActiveBranch
        }

        return resolvedBranches.first ?? ""
    }()

    let activeBranchGroups: [String] = {
        if form.hasCompleteBranchAssignments {
            return form.normalizedBranchAssignments
                .first {
                    $0.branch == primaryBranch
                }?
                .groups ?? []
        }

        /*
         * תאימות למבנה ישן רק בסניף יחיד.
         */
        return resolvedBranches.count == 1
            ? resolvedGroups
            : []
    }()

    let primaryGroup: String = {
        if activeBranchGroups.contains(requestedActiveGroup) {
            return requestedActiveGroup
        }

        return activeBranchGroups.first ?? ""
    }()

    userData["branches"] = resolvedBranches
    userData["groups"] = resolvedGroups

    /*
     * כותבים גם ערך ריק כדי לנקות בחירה קודמת
     * בזמן שמירה באמצעות merge.
     */
    userData["branch"] = primaryBranch
    userData["activeBranch"] = primaryBranch
    userData["active_branch"] = primaryBranch

    userData["group"] = primaryGroup
    userData["age_group"] = primaryGroup
    userData["ageGroup"] = primaryGroup
    userData["activeGroup"] = primaryGroup
    userData["active_group"] = primaryGroup

    /*
     * רישום הטופס אינו מעניק הרשאת מאמן
     * ואינו משנה אישור או קוד קיימים.
     */
    userData.removeValue(forKey: "coachCode")
    userData.removeValue(forKey: "coachApproved")

    userData["authProvider"] =
        isGoogleRegistration ? "google" : "local"

    if isGoogleRegistration {
        userData["username"] = email
        userData["usernameLower"] = email.lowercased()
    }

    guard !Task.isCancelled,
          Auth.auth().currentUser?.uid == uid else {
        return
    }

    try await db.collection("users")
        .document(uid)
        .setData(userData, merge: true)

    /*
     * בזמן ההמתנה לשמירה ייתכן שהחשבון התחלף.
     * שומרים מקומית רק עבור המשתמש שעדיין מחובר.
     */
    guard !Task.isCancelled,
          Auth.auth().currentUser?.uid == uid else {
        return
    }

    // ✅ שמירה מקומית
    form.persistToUserDefaults()

    let registrationDefaults =
        UserDefaults.standard

    registrationDefaults.removeObject(
        forKey: "coach_code"
    )

    registrationDefaults.set(
        isGoogleRegistration ? "google" : "local",
        forKey: "authProvider"
    )

    registrationDefaults.set(
        isGoogleRegistration,
        forKey: "google_login"
    )

    if isGoogleRegistration {
        registrationDefaults.set(
            email,
            forKey: "username"
        )
    }

} catch {
    self.errorText =
        "לא ניתן לשמור את הפרופיל כרגע. בדוק את החיבור ונסה שוב."
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
        guard Auth.auth().currentUser?.uid == uid else {
            return
        }

        if let previousUID = loadedProfileUID,
           previousUID != uid {
            clearTrainingAssignmentsOnSignOut()

            loadedProfileUID = nil
            registeredBelt = nil
            nextBelt = BeltFlow.defaultBelt

            setActiveUserRole("trainee")

            userFullName = ""
            userRegion = ""
            userBranch = ""
            userGroup = ""
        }

        let requestID = UUID()
        profileLoadRequestID = requestID
        isProfileLoading = true
        profileLoadFailed = false

        defer {
            if profileLoadRequestID == requestID {
                isProfileLoading = false
            }
        }

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

            guard !Task.isCancelled,
                  profileLoadRequestID == requestID,
                  Auth.auth().currentUser?.uid == uid else {
                return
            }

            let rawData = snap.data() ?? [:]

            let data = try await ensureUserProfileDocumentExists(
                uid: uid,
                existingData: rawData
            )

            guard !Task.isCancelled,
                  profileLoadRequestID == requestID,
                  Auth.auth().currentUser?.uid == uid else {
                return
            }



        // ✅ role מהשרת עם תמיכה בחשבון מנהל דו־תפקידי
            let roleFromServer = [
                data["role"] as? String,
                data["user_role"] as? String,
                data["userRole"] as? String,
                data["user_type"] as? String,
                data["type"] as? String
            ]
            .compactMap { $0 }
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first { !$0.isEmpty } ?? ""

        let normalizedRole = roleFromServer
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
            let serverPhoneRaw = [
                data["phone"] as? String,
                data["phoneNumber"] as? String,
                data["phone_number"] as? String,
                data["mobile"] as? String
            ]
            .compactMap { $0 }
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first { !$0.isEmpty } ?? ""
            let serverAllowsCoach =
                await hasServerCoachAccess(uid: uid)

            /*
             * בזמן בדיקת ההרשאה ייתכן שהמשתמש
             * התנתק או שהתחילה טעינת פרופיל אחרת.
             */
            guard !Task.isCancelled,
                  profileLoadRequestID == requestID,
                  Auth.auth().currentUser?.uid == uid else {
                return
            }

            let defaults = UserDefaults.standard

            let storedActiveRole = [
                defaults.string(
                    forKey: "last_active_app_role"
                ),
                defaults.string(
                    forKey: "active_user_mode"
                ),
                defaults.string(
                    forKey: "user_role"
                ),
                defaults.string(
                    forKey: roleDefaultsKey
                )
            ]
            .compactMap { $0 }
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first { !$0.isEmpty }

            let requestedRole =
                normalizedActiveRole(
                    storedActiveRole ?? normalizedRole
                )

            let resolvedRole =
                requestedRole == "coach" &&
                serverAllowsCoach
                    ? "coach"
                    : "trainee"

            self.setActiveUserRole(resolvedRole)

            let rawBelt = [
                data["beltId"] as? String,
                data["belt"] as? String,
                data["currentBelt"] as? String,
                data["registeredBelt"] as? String,
                data["current_belt"] as? String,
                data["belt_current"] as? String
            ]
            .compactMap { $0 }
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first { !$0.isEmpty }

            let belt = BeltFlow.belt(fromRaw: rawBelt)
            self.registeredBelt = belt
            self.nextBelt = BeltFlow.nextBeltForUser(registeredBelt: belt)

            // ✅ region / branch / group למסך הבית
            let fullName =
                (data["fullName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let legacyRegion =
                (data["region"] as? String)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            let serverRegions =
                (data["regions"] as? [String] ?? [])
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty }

            var seenRegions = Set<String>()

            let regions = (
                serverRegions.isEmpty
                    ? [legacyRegion]
                    : serverRegions
            )
            .filter { !$0.isEmpty }
            .filter {
                seenRegions.insert($0).inserted
            }

            let region =
                regions.contains(legacyRegion)
                    ? legacyRegion
                    : regions.first ?? ""

            let codec = RegistrationFormState.BranchAssignmentsCodec.self

            let rawAssignments = data[codec.firestoreKey] as? [Any]

            let assignments = rawAssignments.map {
                codec.fromFirestoreList($0)
            } ?? []

            let hasAssignmentsField = rawAssignments != nil

            let legacyBranches =
                (data["branches"] as? [String])?
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty } ?? []

            let singleBranch =
                (data["branch"] as? String)?
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ) ?? ""

            let branches: [String]

            if hasAssignmentsField {
                branches = codec.flattenBranches(assignments)
            } else {
                branches = legacyBranches.isEmpty
                    ? (singleBranch.isEmpty ? [] : [singleBranch])
                    : legacyBranches
            }

            let legacyGroups =
                (data["groups"] as? [String])?
                    .map {
                        $0.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                    }
                    .filter { !$0.isEmpty } ?? []

            let singleGroup = [
                data["group"] as? String ?? "",
                data["age_group"] as? String ?? "",
                data["ageGroup"] as? String ?? ""
            ]
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .first { !$0.isEmpty } ?? ""

            let groups: [String]

            if hasAssignmentsField {
                groups = codec.flattenGroups(assignments)
            } else {
                groups = legacyGroups.isEmpty
                    ? (singleGroup.isEmpty ? [] : [singleGroup])
                    : legacyGroups
            }

            let requestedBranches = [
                data["active_branch"] as? String ?? "",
                data["activeBranch"] as? String ?? "",
                singleBranch
            ]
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }

            let primaryBranch =
                requestedBranches.first {
                    !$0.isEmpty && branches.contains($0)
                } ?? branches.first ?? ""

            let activeBranchGroups: [String]

            if hasAssignmentsField {
                activeBranchGroups = assignments
                    .first { $0.branch == primaryBranch }?
                    .groups ?? []
            } else {
                activeBranchGroups = groups
            }

            let requestedGroups = [
                data["active_group"] as? String ?? "",
                data["activeGroup"] as? String ?? "",
                singleGroup
            ]
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }

            let primaryGroup =
                requestedGroups.first {
                    !$0.isEmpty && activeBranchGroups.contains($0)
                } ?? activeBranchGroups.first ?? ""



            self.userFullName = fullName
            self.userRegion = region
            self.userBranch = primaryBranch
            self.userGroup = primaryGroup
            self.userBranchAssignments = assignments

            let ud = UserDefaults.standard

            if hasAssignmentsField {
                ud.set(
                    codec.encode(assignments),
                    forKey: codec.preferenceKey
                )
            } else {
                ud.removeObject(forKey: codec.preferenceKey)
            }

            ud.set(fullName, forKey: "fullName")
            ud.set(fullName, forKey: "full_name")
            ud.set(fullName, forKey: "name")
            ud.set(fullName, forKey: "displayName")

            let gender = (data["gender"] as? String ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            ud.set(gender, forKey: "gender")

            let birthDate = (data["birthDate"] as? String ?? "")
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            let birthParts = birthDate.split(
                separator: "-",
                omittingEmptySubsequences: false
            )

            for key in [
                "birthDay",
                "birth_day",
                "birthMonth",
                "birth_month",
                "birthYear",
                "birth_year"
            ] {
                ud.removeObject(forKey: key)
            }

            if birthParts.count == 3,
               let year = Int(birthParts[0]),
               let month = Int(birthParts[1]),
               let day = Int(birthParts[2]),
               (1900...2100).contains(year),
               (1...12).contains(month),
               (1...31).contains(day) {
                ud.set(String(day), forKey: "birthDay")
                ud.set(String(day), forKey: "birth_day")
                ud.set(String(month), forKey: "birthMonth")
                ud.set(String(month), forKey: "birth_month")
                ud.set(String(year), forKey: "birthYear")
                ud.set(String(year), forKey: "birth_year")
            }

            ud.set(
                data["username"] as? String ?? "",
                forKey: "username"
            )

            let wantsSms =
                data["subscribeSms"] as? Bool
                ?? data["wantsSms"] as? Bool
                ?? false

            ud.set(wantsSms, forKey: "subscribeSms")
            ud.set(wantsSms, forKey: "wantsSms")

            let abroad =
                TrainingCatalogIOS.isAbroadRegion(region) ||
                branches.contains {
                    TrainingCatalogIOS.isAbroadBranch($0)
                }

            ud.set(
                abroad ? "abroad" : "israel",
                forKey: "branch_type"
            )

            let normalizedPhone =
                serverPhoneRaw.filter { $0.isNumber }

            for key in [
                "phone",
                "phone_number",
                "phoneNumber"
            ] {
                ud.set(normalizedPhone, forKey: key)
            }

            let resolvedEmail = [
                Auth.auth().currentUser?.email ?? "",
                data["email"] as? String ?? ""
            ]
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
            }
            .first { !$0.isEmpty } ?? ""

            ud.set(resolvedEmail, forKey: "email")
            ud.set(resolvedEmail, forKey: "user_email")

            let beltPreferenceKeys = [
                "belt",
                "beltId",
                "currentBeltId",
                "registeredBelt",
                "current_belt",
                "belt_current"
            ]

            if let belt {
                for key in beltPreferenceKeys {
                    ud.set(belt.id, forKey: key)
                }
            } else {
                for key in beltPreferenceKeys {
                    ud.removeObject(forKey: key)
                }
            }

        /*
         * שומר את הערכים הראשיים לצורך תאימות
         * למסכים הישנים באפליקציה.
         */
        self.persistTrainingAssignmentToDefaults(
            region: region,
            branch: primaryBranch,
            group: primaryGroup
        )

        /*
         * שומר גם את כל הרשימות. ערכים אלה משמשים
         * את מסך עריכת הפרופיל ואת מסך האימונים הקרובים.
         */
            ud.set(regions, forKey: "regions")
            ud.set(regions, forKey: "selected_regions")
            ud.set(region, forKey: "active_region")

            ud.set(
                regions.joined(separator: ", "),
                forKey: "regions_csv"
            )

            ud.set(branches, forKey: "branches")
            ud.set(groups, forKey: "groups")

            ud.set(
                branches.joined(separator: ","),
            forKey: "branchesCsv"
        )

        ud.set(
            groups.joined(separator: ","),
            forKey: "groupsCsv"
        )

        ud.set(primaryBranch, forKey: "activeBranch")
        ud.set(primaryBranch, forKey: "active_branch")

        ud.set(primaryGroup, forKey: "activeGroup")
        ud.set(primaryGroup, forKey: "active_group")

            self.loadedProfileUID = uid
            self.profileLoadFailed = false

            KmiPushManager.shared.savePendingFcmTokenAfterLoginIfNeeded()
            KmiPushManager.shared.refreshAndSaveFcmTokenIfPossible()

            } catch {
                guard !Task.isCancelled,
                      profileLoadRequestID == requestID,
                      Auth.auth().currentUser?.uid == uid else {
                    return
                }

                self.profileLoadFailed = true
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
