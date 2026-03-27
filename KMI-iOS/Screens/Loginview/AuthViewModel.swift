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
                } else {
                    // ✅ יציאה -> מאפסים
                    self.registeredBelt = nil
                    self.nextBelt = BeltFlow.defaultBelt
                    self.userRole = "trainee"
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

            if rawId.contains("@") {
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
            } else {
                if serverRole != wantedRole {
                    errorText = wantedRole == "coach"
                        ? "המשתמש אינו מוגדר כמאמן"
                        : "המשתמש אינו מוגדר כמתאמן"
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
            errorText = error.localizedDescription
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
            self.errorText = error.localizedDescription
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

            let data = snap.data() ?? [:]

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
            let region =
                (data["region"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let branches =
                (data["branches"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let groups =
                (data["groups"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []

            let primaryBranch = branches.first ?? ""
            let primaryGroup = groups.first ?? ""

            self.userRegion = region
            self.userBranch = primaryBranch
            self.userGroup = primaryGroup

            self.persistTrainingAssignmentToDefaults(
                region: region,
                branch: primaryBranch,
                group: primaryGroup
            )

            #if DEBUG
            print("Loaded profile uid=\(uid) rawBelt=\(rawBelt ?? "nil") region=\(region) branch=\(primaryBranch) group=\(primaryGroup) -> registered=\(String(describing: belt)) next=\(self.nextBelt)")
            #endif

        } catch {
            self.registeredBelt = nil
            self.nextBelt = BeltFlow.defaultBelt
            self.userRegion = ""
            self.userBranch = ""
            self.userGroup = ""

            #if DEBUG
            print("Failed to load profile uid=\(uid): \(error.localizedDescription)")
            #endif
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
