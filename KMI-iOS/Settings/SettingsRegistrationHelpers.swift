import SwiftUI
import Foundation

extension SettingsView {

    // MARK: - Registration Save Helpers
    func saveRegistrationSnapshot(
        fullName: String,
        phone: String,
        email: String,
        region: String,
        belt: String,
        isCoach: Bool,
        branches: [String],
        groups: [String],
        username: String,
        birthDay: String,
        birthMonth: String,
        birthYear: String,
        gender: String,
        password: String,
        wantsSms: Bool,
        acceptsTerms: Bool,
        coachCode: String
    ) {
        print("⚙️ [2] submittedFullName =", fullName)
        print("⚙️ [3] submittedPhone =", phone)
        print("⚙️ [4] submittedEmail =", email)
        print("⚙️ [5] submittedRegion =", region)
        print("⚙️ [6] submittedBranches =", branches)
        print("⚙️ [7] submittedGroups =", groups)
        print("⚙️ [8] submittedBelt =", belt)

        let defaults = UserDefaults.standard

        let existingRole = (
            defaults.string(forKey: "user_role")
            ?? self.userRole
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let resolvedRole = existingRole.isEmpty ? "trainee" : existingRole

        print("⚙️ [9] submittedRole =", isCoach ? "coach" : "trainee")
        print("⚙️ [10] keepingExistingRole =", resolvedRole)

        // ✅ מנקים רווחים ובוחרים ערך ראשון אמיתי
        let cleanedBranches = branches
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleanedGroups = groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let firstBranch = cleanedBranches.first ?? ""
        let firstGroup = cleanedGroups.first ?? ""

        // ✅ direct keys
        defaults.set(fullName, forKey: "fullName")

        defaults.set(phone, forKey: "phone")
        defaults.set(email, forKey: "email")

        defaults.set(region, forKey: "region")
        defaults.set(firstBranch, forKey: "branch")
        defaults.set(firstGroup, forKey: "group")

        defaults.set(resolvedRole, forKey: "user_role")
        defaults.set(username, forKey: "username")

        defaults.set(birthDay, forKey: "birthDay")
        defaults.set(birthDay, forKey: "birth_day")

        defaults.set(birthMonth, forKey: "birthMonth")
        defaults.set(birthMonth, forKey: "birth_month")

        defaults.set(birthYear, forKey: "birthYear")
        defaults.set(birthYear, forKey: "birth_year")

        defaults.set(gender, forKey: "gender")
        defaults.set(password, forKey: "password")

        defaults.set(cleanedBranches, forKey: "branches")
        defaults.set(cleanedGroups, forKey: "groups")

        defaults.set(wantsSms, forKey: "wantsSms")
        defaults.set(acceptsTerms, forKey: "acceptsTerms")

        defaults.set(coachCode, forKey: "coachCode")
        defaults.set(coachCode, forKey: "coach_code")

        saveRegionKeys(region, defaults: defaults)
        saveBranchKeys(firstBranch, defaults: defaults)
        saveGroupKeys(firstGroup, defaults: defaults)
        saveBeltKeys(from: belt, defaults: defaults)

        print("⚙️ saved fullName =", defaults.string(forKey: "fullName") ?? "nil")
        print("⚙️ saved full_name =", defaults.string(forKey: "full_name") ?? "nil")
        print("⚙️ saved user_role =", defaults.string(forKey: "user_role") ?? "nil")
        print("⚙️ saved birthDay =", defaults.string(forKey: "birthDay") ?? "nil")
        print("⚙️ saved birthMonth =", defaults.string(forKey: "birthMonth") ?? "nil")

        print("⚙️ saved region =", defaults.string(forKey: "region") ?? "nil")
        print("⚙️ saved active_region =", defaults.string(forKey: "active_region") ?? "nil")
        print("⚙️ saved kmi.user.region =", defaults.string(forKey: "kmi.user.region") ?? "nil")

        print("⚙️ saved branch =", defaults.string(forKey: "branch") ?? "nil")
        print("⚙️ saved active_branch =", defaults.string(forKey: "active_branch") ?? "nil")
        print("⚙️ saved kmi.user.branch =", defaults.string(forKey: "kmi.user.branch") ?? "nil")

        print("⚙️ saved group =", defaults.string(forKey: "group") ?? "nil")
        print("⚙️ saved active_group =", defaults.string(forKey: "active_group") ?? "nil")
        print("⚙️ saved kmi.user.group =", defaults.string(forKey: "kmi.user.group") ?? "nil")
        print("⚙️ saved branches array =", defaults.stringArray(forKey: "branches") ?? [])
        print("⚙️ saved groups array =", defaults.stringArray(forKey: "groups") ?? [])

        // ✅ מרענן את ה-UI אחרי שמירה
        DispatchQueue.main.async {
            self.fullName = fullName
            self.phone = phone
            self.email = email
            self.region = region
            self.branch = firstBranch
            self.group = firstGroup
            self.userRole = resolvedRole
        }
    }

    func saveRegionKeys(_ value: String, defaults: UserDefaults) {
        defaults.set(value, forKey: "region")
        defaults.set(value, forKey: "active_region")
        defaults.set(value, forKey: "kmi.user.region")
    }

    func saveBranchKeys(_ value: String, defaults: UserDefaults) {
        defaults.set(value, forKey: "branch")
        defaults.set(value, forKey: "active_branch")
        defaults.set(value, forKey: "kmi.user.branch")
    }

    func saveGroupKeys(_ value: String, defaults: UserDefaults) {
        defaults.set(value, forKey: "group")
        defaults.set(value, forKey: "active_group")
        defaults.set(value, forKey: "kmi.user.group")
    }

    func saveBeltKeys(from belt: String, defaults: UserDefaults) {
        let beltId: String

        switch belt {
        case "צהובה":
            beltId = "yellow"
        case "כתומה":
            beltId = "orange"
        case "ירוקה":
            beltId = "green"
        case "כחולה":
            beltId = "blue"
        case "חומה":
            beltId = "brown"
        case "שחורה":
            beltId = "black"
        default:
            beltId = "white"
        }

        defaults.set(beltId, forKey: "current_belt")
        defaults.set(beltId, forKey: "belt_current")
    }
}
