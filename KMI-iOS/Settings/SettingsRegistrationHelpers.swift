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
        let defaults = UserDefaults.standard

        let cleanedFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCoachCode = coachCode.trimmingCharacters(in: .whitespacesAndNewlines)

        let existingRole = (
            defaults.string(forKey: "user_role")
            ?? self.userRole
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

        let submittedRole = isCoach ? "coach" : "trainee"
        let resolvedRole = existingRole.isEmpty ? submittedRole : existingRole

        let cleanedBranches = branches
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicatesKeepingOrder()

        let cleanedGroups = groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicatesKeepingOrder()

        let firstBranch = cleanedBranches.first ?? ""
        let firstGroup = cleanedGroups.first ?? ""

        defaults.set(cleanedFullName, forKey: "fullName")
        defaults.set(cleanedFullName, forKey: "full_name")
        defaults.set(cleanedFullName, forKey: "kmi.user.fullName")

        defaults.set(cleanedPhone, forKey: "phone")
        defaults.set(cleanedPhone, forKey: "kmi.user.phone")

        defaults.set(cleanedEmail, forKey: "email")
        defaults.set(cleanedEmail, forKey: "kmi.user.email")

        defaults.set(cleanedRegion, forKey: "region")
        defaults.set(firstBranch, forKey: "branch")
        defaults.set(firstGroup, forKey: "group")

        defaults.set(resolvedRole, forKey: "user_role")
        defaults.set(cleanedUsername, forKey: "username")

        defaults.set(birthDay.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthDay")
        defaults.set(birthDay.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_day")

        defaults.set(birthMonth.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthMonth")
        defaults.set(birthMonth.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_month")

        defaults.set(birthYear.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthYear")
        defaults.set(birthYear.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_year")

        defaults.set(cleanedGender, forKey: "gender")
        defaults.set(password, forKey: "password")

        defaults.set(cleanedBranches, forKey: "branches")
        defaults.set(cleanedGroups, forKey: "groups")

        defaults.set(wantsSms, forKey: "wantsSms")
        defaults.set(wantsSms, forKey: "wants_sms")

        defaults.set(acceptsTerms, forKey: "acceptsTerms")
        defaults.set(acceptsTerms, forKey: "accepts_terms")

        defaults.set(cleanedCoachCode, forKey: "coachCode")
        defaults.set(cleanedCoachCode, forKey: "coach_code")

        saveRegionKeys(cleanedRegion, defaults: defaults)
        saveBranchKeys(firstBranch, defaults: defaults)
        saveGroupKeys(firstGroup, defaults: defaults)
        saveBeltKeys(from: belt, defaults: defaults)

        defaults.synchronize()

        DispatchQueue.main.async {
            self.fullName = cleanedFullName
            self.phone = cleanedPhone
            self.email = cleanedEmail
            self.region = cleanedRegion
            self.branch = firstBranch
            self.group = firstGroup
            self.userRole = resolvedRole
        }
    }
    
    func saveRegionKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "region")
        defaults.set(clean, forKey: "active_region")
        defaults.set(clean, forKey: "selected_region")
        defaults.set(clean, forKey: "current_region")
        defaults.set(clean, forKey: "kmi.user.region")
    }

    func saveBranchKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "branch")
        defaults.set(clean, forKey: "active_branch")
        defaults.set(clean, forKey: "selected_branch")
        defaults.set(clean, forKey: "current_branch")
        defaults.set(clean, forKey: "kmi.user.branch")
    }

    func saveGroupKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "group")
        defaults.set(clean, forKey: "active_group")
        defaults.set(clean, forKey: "groupKey")
        defaults.set(clean, forKey: "group_key")
        defaults.set(clean, forKey: "primaryGroup")
        defaults.set(clean, forKey: "age_group")
        defaults.set(clean, forKey: "ageGroup")
        defaults.set(clean, forKey: "kmi.user.group")
    }

    func saveBeltKeys(from belt: String, defaults: UserDefaults) {
        let clean = belt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "חגורה", with: "")
            .replacingOccurrences(of: "belt", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let beltId: String

        switch clean {
        case "white", "לבנה", "לבן":
            beltId = "white"
        case "yellow", "צהובה", "צהוב":
            beltId = "yellow"
        case "orange", "כתומה", "כתום":
            beltId = "orange"
        case "green", "ירוקה", "ירוק":
            beltId = "green"
        case "blue", "כחולה", "כחול":
            beltId = "blue"
        case "brown", "חומה", "חום":
            beltId = "brown"
        case "black", "שחורה", "שחור":
            beltId = "black"
        default:
            beltId = currentBeltId.isEmpty ? "white" : currentBeltId
        }

        defaults.set(beltId, forKey: "current_belt")
        defaults.set(beltId, forKey: "belt_current")
        defaults.set(beltId, forKey: "kmi.user.belt")
        defaults.set(beltId, forKey: "registered_belt")
        defaults.set(beltId, forKey: "rank")
        defaults.set(beltId, forKey: "rank_id")
    }
}

private extension Array where Element: Hashable {
    func removingDuplicatesKeepingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
