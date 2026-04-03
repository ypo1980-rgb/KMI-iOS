import Foundation
import Combine
import Shared

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
        isLoading = true
        isSignedIn = false

        // ✅ UI מהיר עד שנמשוך מהשרת
        self.userRole = UserDefaults.standard.string(forKey: roleDefaultsKey) ?? "trainee"
    }
    
    func forceSignOutForFreshLogin() {
        isSignedIn = false

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

        isLoading = true

        #if DEBUG
        print("AuthViewModel.start() attaching auth state listener…")
        #endif

        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            Task { @MainActor in
                self.isSignedIn = (user != nil)

                if let user {
                    // ✅ טוענים פרופיל מהשרת כדי לדעת חגורה ותפקיד
                    await self.loadUserProfile(uid: user.uid)

                    #if DEBUG
                    print("🟣 AUTH_START uid =", user.uid)
                    print("🟣 AUTH_START userFullName =", self.userFullName)
                    print("🟣 AUTH_START userBranch =", self.userBranch)
                    print("🟣 AUTH_START userGroup =", self.userGroup)
                    #endif
                } else {
                    // ✅ יציאה -> מאפסים
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
                }

                self.isLoading = false

                #if DEBUG
                if let user {
                    print("Auth state changed: signed in uid=\(user.uid)")
                } else {
                    print("Auth state changed: signed out")
                }
                #endif
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

            #if DEBUG
            print("AuthViewModel.stop() removed auth state listener")
            #endif
        }
        #endif
    }

    private func persistTrainingAssignmentToDefaults(
        region: String,
        branch: String,
        group: String
    ) {
        let ud = UserDefaults.standard

        ud.set(region, forKey: "kmi.user.region")
        ud.set(branch, forKey: "kmi.user.branch")
        ud.set(group, forKey: "kmi.user.group")

        ud.set(region, forKey: "region")
        ud.set(branch, forKey: "branch")
        ud.set(group, forKey: "group")
        ud.set(group, forKey: "age_group")
        ud.set(group, forKey: "age_groups")
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

    #if DEBUG
    print("🟡 ensureUserProfileDocumentExists repaired users/\(uid)")
    print("🟡 ensureUserProfileDocumentExists resolvedBranch =", resolvedBranch)
    print("🟡 ensureUserProfileDocumentExists resolvedGroup =", resolvedGroup)
    print("🟡 ensureUserProfileDocumentExists repairedData =", repairedData)
    #endif

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
            #if DEBUG
            print("🔴 reloadProfileIfSignedIn: no current uid")
            #endif
            return
        }

        #if DEBUG
        print("🟠 reloadProfileIfSignedIn uid =", uid)
        #endif

        Task { @MainActor in
            await self.loadUserProfile(uid: uid)

            #if DEBUG
            print("🟠 reloadProfileIfSignedIn result fullName =", self.userFullName)
            print("🟠 reloadProfileIfSignedIn result branch =", self.userBranch)
            print("🟠 reloadProfileIfSignedIn result group =", self.userGroup)
            print("🟠 reloadProfileIfSignedIn defaults.branch =", UserDefaults.standard.string(forKey: "kmi.user.branch") ?? "")
            print("🟠 reloadProfileIfSignedIn defaults.group =", UserDefaults.standard.string(forKey: "kmi.user.group") ?? "")
            #endif
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

        #if DEBUG
        print("🟢 saveTrainingAssignment branch =", cleanBranch)
        print("🟢 saveTrainingAssignment group =", cleanGroup)
        #endif

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
                        "branches": cleanBranch.isEmpty ? [] : [cleanBranch],
                        "group": cleanGroup,
                        "groups": cleanGroup.isEmpty ? [] : [cleanGroup],
                        "age_group": cleanGroup,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], merge: true)

                #if DEBUG
                print("🟢 saveTrainingAssignment saved to Firestore uid =", uid)
                #endif
            } catch {
                #if DEBUG
                print("🔴 saveTrainingAssignment failed =", error.localizedDescription)
                #endif
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

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty, !p.isEmpty else {
            errorText = "נא למלא אימייל וסיסמה"
            completion?(false)
            return
        }

        isLoading = true

        #if canImport(FirebaseAuth)
        Auth.auth().signIn(withEmail: e, password: p) { [weak self] result, err in
            DispatchQueue.main.async {
                guard let self else {
                    completion?(false)
                    return
                }

                self.isLoading = false

                if let err {
                    self.errorText = err.localizedDescription
                    completion?(false)
                    return
                }

                self.errorText = nil
                self.isSignedIn = (result?.user != nil)
                completion?(result?.user != nil)
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
            errorText = "נא למלא שם משתמש וסיסמה"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseAuth)
        #if canImport(FirebaseFirestore)
        do {
            let loginEmail: String

            let isEmail: Bool = {
                let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let range = NSRange(location: 0, length: rawId.utf16.count)
                let matches = detector?.matches(in: rawId, options: [], range: range) ?? []
                return matches.first?.url?.scheme == "mailto"
            }()

            if isEmail {
                loginEmail = rawId.lowercased()
            } else {
                let db = Firestore.firestore()
                let snap = try await db.collection("users")
                    .whereField("usernameLower", isEqualTo: rawId.lowercased())
                    .limit(to: 1)
                    .getDocuments()

                guard let data = snap.documents.first?.data(),
                      let resolvedEmail = (data["emailLower"] as? String) ?? (data["email"] as? String),
                      !resolvedEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    errorText = "שם המשתמש לא נמצא"
                    return false
                }

                loginEmail = resolvedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                // ✅ מאפשר גם לחשבון מאמן להיכנס במצב מתאמן
                // חסימה תבוצע רק אם בעתיד יהיה תפקיד לא מזוהה או לא תקין
                if serverRole != "trainee" && serverRole != "coach" && serverRole != "trainer" {
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
            }

            await loadUserProfile(uid: uid)
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
                    errorText = "שם משתמש או סיסמה שגויים"

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
                    self?.errorText = err.localizedDescription
                    completion(false, err.localizedDescription)
                } else {
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

        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            errorText = error.localizedDescription
        }
        #else
        errorText = "FirebaseAuth לא מותקן בפרויקט"
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

        #if DEBUG
        print("🟠 registerAndSaveProfile: started email=\(email) role=\(form.roleKey)")
        #endif

        #if canImport(FirebaseAuth)
        
        do {
            let uid = try await createUserLegacy(email: email, password: password)
            
#if DEBUG
print("🟠 registerAndSaveProfile: created auth user uid=\(uid)")
#endif
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

    #if DEBUG
    print("🟠 registerAndSaveProfile resolved branchClean =", branchClean)
    print("🟠 registerAndSaveProfile resolved groupClean =", groupClean)
    #endif

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

    #if DEBUG
    print("🟠 registerAndSaveProfile: saved Firestore profile uid=\(uid)")
    #endif

    // ✅ שמירה מקומית
    form.persistToUserDefaults()

    if let generatedCoachCode {
        UserDefaults.standard.set(generatedCoachCode, forKey: "coach_code")
        issuedCoachCode = generatedCoachCode
    } else {
        UserDefaults.standard.removeObject(forKey: "coach_code")
    }

} catch {
    #if DEBUG
    print("🔴 registerAndSaveProfile: Firestore save failed: \(error.localizedDescription)")
    #endif
    self.errorText = "שמירת פרופיל נכשלה: \(error.localizedDescription)"
    return
}

#endif

// ✅ מרעננים את הפרופיל מהשרת
await loadUserProfile(uid: uid)

            #if DEBUG
            print("✅ registerAndSaveProfile success uid=\(uid)")
            #endif

        } catch {
            #if DEBUG
            print("🔴 registerAndSaveProfile: auth/create failed: \(error.localizedDescription)")
            #endif

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
        #if DEBUG
        print("🟠 loadUserProfileFromFirestore(uid:) start uid =", uid)
        #endif

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

#if DEBUG
print("🟠 FIRESTORE users/\(uid) exists =", snap.exists)
print("🟠 FIRESTORE users/\(uid) data =", rawData)
print("🟠 FIRESTORE users/\(uid) keys =", Array(rawData.keys).sorted())
#endif

        let data = try await ensureUserProfileDocumentExists(
            uid: uid,
            existingData: rawData
        )

        #if DEBUG
        print("🟠 FIRESTORE users/\(uid) normalized data =", data)
        #endif

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

            #if DEBUG
            print("KMI_ROLE raw role =", roleFromServer, "resolved =", resolvedRole)
            #endif

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

#if DEBUG
print("🟠 PROFILE_PARSED fullName =", fullName)
print("🟠 PROFILE_PARSED region =", region)
print("🟠 PROFILE_PARSED raw branch =", data["branch"] as Any)
print("🟠 PROFILE_PARSED raw branches =", data["branches"] as Any)
print("🟠 PROFILE_PARSED raw group =", data["group"] as Any)
print("🟠 PROFILE_PARSED raw groups =", data["groups"] as Any)
print("🟠 PROFILE_PARSED raw age_group =", data["age_group"] as Any)
print("🟠 PROFILE_PARSED raw ageGroup =", data["ageGroup"] as Any)
print("🟠 PROFILE_PARSED branchesArray =", branchesArray)
print("🟠 PROFILE_PARSED singleBranch =", singleBranch)
print("🟠 PROFILE_PARSED branches =", branches)
print("🟠 PROFILE_PARSED groupsArray =", groupsArray)
print("🟠 PROFILE_PARSED singleGroup =", singleGroup)
print("🟠 PROFILE_PARSED groups =", groups)
print("🟠 PROFILE_PARSED primaryBranch =", primaryBranch)
print("🟠 PROFILE_PARSED primaryGroup =", primaryGroup)
#endif

        self.userFullName = fullName
        self.userRegion = region
        self.userBranch = primaryBranch
        self.userGroup = primaryGroup

        self.persistTrainingAssignmentToDefaults(
            region: region,
            branch: primaryBranch,
            group: primaryGroup
        )

        #if DEBUG
        print("🟠 PROFILE_STATE userFullName =", self.userFullName)
        print("🟠 PROFILE_STATE userBranch =", self.userBranch)
        print("🟠 PROFILE_STATE userGroup =", self.userGroup)
        print("🟢 AUTH_PROFILE uid =", uid)
        print("🟢 AUTH_PROFILE fullName =", fullName)
            print("🟢 AUTH_PROFILE region =", region)
            print("🟢 AUTH_PROFILE branches =", branches)
            print("🟢 AUTH_PROFILE groups =", groups)
            print("🟢 AUTH_PROFILE primaryBranch =", primaryBranch)
            print("🟢 AUTH_PROFILE primaryGroup =", primaryGroup)
            print("Loaded profile uid=\(uid) rawBelt=\(rawBelt ?? "nil") region=\(region) branch=\(primaryBranch) group=\(primaryGroup) -> registered=\(String(describing: belt)) next=\(self.nextBelt)")
            #endif

        } catch {
            self.registeredBelt = nil
            self.nextBelt = BeltFlow.defaultBelt
            self.userFullName = ""
            self.userRegion = ""
            self.userBranch = ""
            self.userGroup = ""

            #if DEBUG
            print("🔴 AUTH_PROFILE load failed uid =", uid)
            print("🔴 AUTH_PROFILE error =", error.localizedDescription)
            #endif
        }
    }
    #endif

    private func loadUserProfile(uid: String) async {
        #if DEBUG
        print("🟠 loadUserProfile(uid:) called with uid =", uid)
        #endif

        #if canImport(FirebaseFirestore)
        await loadUserProfileFromFirestore(uid: uid)
        #else
        self.registeredBelt = nil
        self.nextBelt = BeltFlow.defaultBelt
        #endif
    }
}
