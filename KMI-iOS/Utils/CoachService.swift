import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
final class CoachService: ObservableObject {

    @Published var isCoach: Bool = false
    @Published var isLoading: Bool = true

    static let shared = CoachService()

    private init() {}

    private var localCoachAccessEnabled: Bool {
        UserDefaults.standard.bool(forKey: "is_coach") ||
        UserDefaults.standard.bool(forKey: "coach_access_enabled")
    }

    func checkCoach(userRole: String? = nil, forceRefresh: Bool = false) async {
        if !forceRefresh && !isLoading {
            return
        }

        isLoading = true

        let authUser = Auth.auth().currentUser
        let uid = authUser?.uid ?? ""

        if authUser == nil {
            let roleFromDefaults = normalizeRole(UserDefaults.standard.string(forKey: "user_role"))

            if isCoachRole(roleFromDefaults) {
                markCoach(true)
            } else {
                markCoach(false)
            }

            return
        }
        
        let roleFromArgument = normalizeRole(userRole)
        let roleFromDefaults = normalizeRole(UserDefaults.standard.string(forKey: "user_role"))
        let normalizedEmail = normalizeEmail(authUser?.email)
        let normalizedPhone = normalizePhone(authUser?.phoneNumber)

        // 1) הרשאה לפי role מהפרופיל / UserDefaults
        if isCoachRole(roleFromArgument) || isCoachRole(roleFromDefaults) || localCoachAccessEnabled {
            markCoach(true)
            return
        }

        let db = Firestore.firestore()

        // 3) בדיקה לפי users/{uid}
        if !uid.isEmpty {
            do {
                let userDoc = try await db
                    .collection("users")
                    .document(uid)
                    .getDocument()

                if userDoc.exists {
                    persistCoachProfileSnapshot(from: userDoc)

                    let role =
                        normalizeRole(userDoc.get("role") as? String) ??
                        normalizeRole(userDoc.get("userRole") as? String) ??
                        normalizeRole(userDoc.get("type") as? String) ??
                        ""

                    if isCoachRole(role) {
                        markCoach(true)
                        return
                    }

                    let isCoachBool =
                        (userDoc.get("isCoach") as? Bool) ??
                        (userDoc.get("coach") as? Bool) ??
                        false

                    if isCoachBool {
                        markCoach(true)
                        return
                    }

                    let rolesArray = (
                        userDoc.get("roles") as? [String] ??
                        userDoc.get("userRoles") as? [String] ??
                        []
                    )
                    .map { normalizeRole($0) ?? "" }

                    if rolesArray.contains(where: { isCoachRole($0) }) {
                        markCoach(true)
                        return
                    }

                    let coachCode =
                        (userDoc.get("coachCode") as? String) ??
                        (userDoc.get("coach_code") as? String) ??
                        ""

                    if !coachCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        markCoach(true)
                        return
                    }

                    let coachEmail = normalizeEmail(userDoc.get("coachEmail") as? String)
                    let coachEmailAlt = normalizeEmail(userDoc.get("coach_email") as? String)

                    if !normalizedEmail.isEmpty &&
                        (
                            (!coachEmail.isEmpty && coachEmail == normalizedEmail) ||
                            (!coachEmailAlt.isEmpty && coachEmailAlt == normalizedEmail)
                        ) {
                        markCoach(true)
                        return
                    }
                }
            } catch {
                // Silent fallback: continue with phone/email coach checks.
            }
        }

        // 4) בדיקה לפי מספר טלפון במסמך coaches/{phone}
        let phoneCandidates = normalizedPhoneCandidates(normalizedPhone)

        for phone in phoneCandidates where !phone.isEmpty {
            do {
                let phoneDoc = try await db
                    .collection("coaches")
                    .document(phone)
                    .getDocument()

                if phoneDoc.exists {
                    markCoach(true)
                    return
                }
            } catch {
                // Silent fallback: continue with the next phone candidate.
            }
        }

        // 5) fallback לפי אימייל בתוך collection coaches
        if !normalizedEmail.isEmpty {
            do {
                let emailSnapLower = try await db
                    .collection("coaches")
                    .whereField("emailLower", isEqualTo: normalizedEmail)
                    .limit(to: 1)
                    .getDocuments()

                if !emailSnapLower.documents.isEmpty {
                    markCoach(true)
                    return
                }

                let emailSnap = try await db
                    .collection("coaches")
                    .whereField("email", isEqualTo: normalizedEmail)
                    .limit(to: 1)
                    .getDocuments()

                if !emailSnap.documents.isEmpty {
                    markCoach(true)
                    return
                }
            } catch {
                // Silent fallback: deny only after all checks fail.
            }
        }

        markCoach(false)
    }

    private func persistCoachProfileSnapshot(from document: DocumentSnapshot) {
        let defaults = UserDefaults.standard

        let branch = (
            (document.get("coachBranch") as? String) ??
            (document.get("branch") as? String) ??
            firstString(from: document.get("branches")) ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let groupKey = (
            (document.get("coachGroupKey") as? String) ??
            (document.get("groupKey") as? String) ??
            (document.get("group_key") as? String) ??
            (document.get("group") as? String) ??
            (document.get("primaryGroup") as? String) ??
            firstString(from: document.get("groups")) ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let fullName = (
            (document.get("fullName") as? String) ??
            (document.get("full_name") as? String) ??
            (document.get("name") as? String) ??
            (document.get("displayName") as? String) ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let email = (
            (document.get("email") as? String) ??
            (document.get("emailLower") as? String) ??
            ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if !branch.isEmpty {
            defaults.set(branch, forKey: "coach_branch")
            defaults.set(branch, forKey: "active_branch")
            defaults.set(branch, forKey: "selected_branch")
            defaults.set(branch, forKey: "current_branch")
            defaults.set(branch, forKey: "branch")
            defaults.set(branch, forKey: "kmi.user.branch")
        }

        if !groupKey.isEmpty {
            defaults.set(groupKey, forKey: "coach_groupKey")
            defaults.set(groupKey, forKey: "active_group")
            defaults.set(groupKey, forKey: "groupKey")
            defaults.set(groupKey, forKey: "group_key")
            defaults.set(groupKey, forKey: "primaryGroup")
            defaults.set(groupKey, forKey: "group")
            defaults.set(groupKey, forKey: "kmi.user.group")
        }

        if !fullName.isEmpty {
            defaults.set(fullName, forKey: "fullName")
            defaults.set(fullName, forKey: "full_name")
            defaults.set(fullName, forKey: "kmi.user.fullName")
        }

        if !email.isEmpty {
            defaults.set(email, forKey: "email")
            defaults.set(email, forKey: "kmi.user.email")
        }
    }

    private func firstString(from value: Any?) -> String? {
        if let array = value as? [String] {
            return array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
        }

        if let array = value as? [Any] {
            return array
                .compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
        }

        return nil
    }
    
    private func markCoach(_ value: Bool) {
        isCoach = value
        isLoading = false

        UserDefaults.standard.set(value, forKey: "is_coach")
        UserDefaults.standard.set(value, forKey: "coach_access_enabled")

        if value {
            UserDefaults.standard.set("coach", forKey: "user_role")
        } else {
            let currentRole = UserDefaults.standard
                .string(forKey: "user_role")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""

            if isCoachRole(currentRole) {
                UserDefaults.standard.set("trainee", forKey: "user_role")
            }
        }
    }
    
    private func normalizeRole(_ value: String?) -> String? {
        let clean = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return clean.isEmpty ? nil : clean
    }

    private func normalizeEmail(_ value: String?) -> String {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func normalizePhone(_ value: String?) -> String {
        (value ?? "").filter { $0.isNumber }
    }

    private func normalizedPhoneCandidates(_ phone: String) -> [String] {
        let clean = normalizePhone(phone)
        guard !clean.isEmpty else { return [] }

        var values: [String] = [clean]

        // ישראל: 97252xxxxxxx -> 052xxxxxxx
        if clean.hasPrefix("972"), clean.count >= 11 {
            let local = "0" + clean.dropFirst(3)
            values.append(String(local))
        }

        // ישראל: 052xxxxxxx -> 97252xxxxxxx
        if clean.hasPrefix("0"), clean.count >= 10 {
            let intl = "972" + clean.dropFirst()
            values.append(String(intl))
        }

        return Array(Set(values))
    }

    private func isCoachRole(_ role: String?) -> Bool {
        let clean = role?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        return clean == "coach" ||
               clean == "trainer" ||
               clean == "instructor" ||
               clean == "teacher" ||
               clean == "admin_coach" ||
               clean == "coach_admin" ||
               clean == "מאמן" ||
               clean == "מדריך" ||
               clean == "מדריכה" ||
               clean == "מאמנת"
    }
}

struct CoachOnlyGateView<Content: View>: View {

    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var role = CoachService.shared

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"
    @AppStorage("selected_language_code") private var selectedLanguageCode: String = "he"

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            selectedLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var gateLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var gateTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var gateHorizontalAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        Group {
            if role.isLoading {
                loadingView
            } else if role.isCoach {
                content()
            } else {
                blockedView
            }
        }
        .environment(\.layoutDirection, gateLayoutDirection)
        .task(id: auth.userRole) {
            await role.checkCoach(userRole: auth.userRole, forceRefresh: true)
        }
    }

    private var loadingView: some View {
        ZStack {
            premiumBackground

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)

                Text(tr("בודק הרשאות מאמן…", "Checking coach permissions…"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center)

                Text(tr("אנא המתן רגע", "Please wait a moment"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private var blockedView: some View {
        ZStack {
            premiumBackground

            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Text(tr("המסך זמין למאמנים בלבד", "This screen is available for coaches only"))
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: gateHorizontalAlignment)
                    .multilineTextAlignment(gateTextAlignment)

                Text(
                    tr(
                        "ההרשאה נקבעת לפי פרטי המשתמש שנשמרו במערכת.",
                        "Access is based on the user details saved in the system."
                    )
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: gateHorizontalAlignment)
                .multilineTextAlignment(gateTextAlignment)

                Button {
                    Task {
                        await role.checkCoach(userRole: auth.userRole, forceRefresh: true)
                    }
                } label: {
                    Text(tr("בדוק שוב", "Check again"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.20))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var premiumBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: 0xFF141E30),
                Color(hex: 0xFF243B55),
                Color(hex: 0xFF0EA5E9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
