import SwiftUI
import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case coach = "מאמן"
    case trainee = "מתאמן"
    var id: String { rawValue }
}

struct RegistrationFormState: Equatable {
    var role: UserRole = .trainee

    var coachCode: String = ""

    var fullName: String = ""
    var phone: String = ""
    var email: String = ""

    var birthDay: String = ""
    var birthMonth: String = ""
    var birthYear: String = ""

    var gender: String = ""

    var username: String = ""
    var password: String = ""
    var showPassword: Bool = false

    var region: String = ""
    var branches: Set<String> = []
    var groups: Set<String> = []

    var branchType: String = "israel" // israel / abroad

    var activeBranch: String = ""
    var activeGroup: String = ""

    var belt: String = ""

    var wantsSms: Bool = true
    var acceptsTerms: Bool = false
}

// MARK: - Helpers

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension RegistrationFormState {

    var roleKey: String {
        switch role {
        case .coach: return "coach"
        case .trainee: return "trainee"
        }
    }

    var emailTrimmed: String { email.trimmed }
    var emailLower: String { emailTrimmed.lowercased() }

    var fullNameTrimmed: String { fullName.trimmed }

    var usernameTrimmed: String { username.trimmed }
    var usernameLower: String { usernameTrimmed.lowercased() }

    var phoneNormalized: String {
        let raw = phone.trimmed
        let digits = raw.filter { $0.isNumber }
        if digits.hasPrefix("972") { return "+" + digits }
        if digits.hasPrefix("0") { return "+972" + String(digits.dropFirst()) }
        if raw.hasPrefix("+") { return raw }
        return digits
    }

    var birthDateString: String {
        let d = birthDay.trimmed
        let m = birthMonth.trimmed
        let y = birthYear.trimmed
        if d.isEmpty || m.isEmpty || y.isEmpty { return "" }
        return "\(y)-\(m.count == 1 ? "0\(m)" : m)-\(d.count == 1 ? "0\(d)" : d)"
    }

    var branchesArray: [String] {
        branches.map { $0.trimmed }.filter { !$0.isEmpty }.sorted()
    }

    var groupsArray: [String] {
        groups.map { $0.trimmed }.filter { !$0.isEmpty }.sorted()
    }

    var primaryGroup: String {
        groupsArray.first ?? ""
    }

    var activeBranchFinal: String {
        let manual = activeBranch.trimmed
        if !manual.isEmpty { return manual }
        return branchesArray.first ?? ""
    }

    var activeGroupFinal: String {
        let manual = activeGroup.trimmed
        if !manual.isEmpty { return manual }
        return groupsArray.first ?? ""
    }

    var currentBeltId: String {
        switch belt.trimmed {
        case "לבנה", "white":
            return "white"

        case "צהובה", "yellow":
            return "yellow"

        case "כתומה", "orange":
            return "orange"

        case "ירוקה", "green":
            return "green"

        case "כחולה", "blue":
            return "blue"

        case "חומה", "brown":
            return "brown"

        case "שחורה", "שחורה דאן 1", "black", "black_dan_1":
            return "black"

        case "שחורה דאן 2", "black_dan_2":
            return "black_dan_2"

        case "שחורה דאן 3", "black_dan_3":
            return "black_dan_3"

        case "שחורה דאן 4", "black_dan_4":
            return "black_dan_4"

        case "שחורה דאן 5", "black_dan_5":
            return "black_dan_5"

        case "שחורה דאן 6", "black_dan_6":
            return "black_dan_6"

        case "שחורה דאן 7", "black_dan_7":
            return "black_dan_7"

        case "שחורה דאן 8", "black_dan_8":
            return "black_dan_8"

        case "שחורה דאן 9", "black_dan_9":
            return "black_dan_9"

        case "שחורה דאן 10", "black_dan_10":
            return "black_dan_10"

        default:
            return ""
        }
    }

    var canSubmit: Bool {
        acceptsTerms
        && !fullNameTrimmed.isEmpty
        && !emailLower.isEmpty
        && !phoneNormalized.isEmpty
        && !gender.trimmed.isEmpty
        && !birthDateString.isEmpty
        && !region.trimmed.isEmpty
        && !branchesArray.isEmpty
        && !currentBeltId.isEmpty
    }

    func toFirestoreDictionary(uid: String) -> [String: Any] {
        var dict: [String: Any] = [
            "uid": uid,
            "role": roleKey,
            "fullName": fullNameTrimmed,
            "phone": phoneNormalized,
            "email": emailTrimmed,
            "emailLower": emailLower,
            "birthDate": birthDateString,
            "gender": gender.trimmed,
            "username": usernameTrimmed,
            "usernameLower": usernameLower,
            "region": region.trimmed,
            "branchType": branchType.trimmed.isEmpty ? "israel" : branchType.trimmed,
            "branch_type": branchType.trimmed.isEmpty ? "israel" : branchType.trimmed,
            "branches": branchesArray,
            "branchesCsv": branchesArray.joined(separator: ", "),
            "activeBranch": activeBranchFinal,
            "groups": groupsArray,
            "primaryGroup": primaryGroup,
            "activeGroup": activeGroupFinal,
            "belt": currentBeltId,
            "currentBelt": currentBeltId,
            "current_belt": currentBeltId,
            "wantsSms": wantsSms,
            "acceptsTerms": acceptsTerms,
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970
        ]

        if role == .coach {
            dict["coachCode"] = coachCode.trimmed
        }

        return dict
    }

    func persistToUserDefaults() {
        let ud = UserDefaults.standard

        let branchesCsv = branchesArray.joined(separator: ", ")
        let groupsCsv = groupsArray.joined(separator: ", ")
        let primaryGroup = primaryGroup
        let activeBranchFinal = activeBranchFinal
        let activeGroupFinal = activeGroupFinal

        ud.set(fullNameTrimmed, forKey: "fullName")
        ud.set(fullNameTrimmed, forKey: "full_name")

        ud.set(phone.trimmed, forKey: "phone")
        ud.set(emailTrimmed, forKey: "email")

        ud.set(region.trimmed, forKey: "region")
        ud.set(region.trimmed, forKey: "active_region")
        ud.set(region.trimmed, forKey: "kmi.user.region")

        let normalizedBranchType = branchType.trimmed.isEmpty ? "israel" : branchType.trimmed
        ud.set(normalizedBranchType, forKey: "branch_type")

        // ✅ branches
        ud.set(branchesArray, forKey: "branches")
        ud.set(activeBranchFinal, forKey: "branch")
        ud.set(activeBranchFinal, forKey: "active_branch")
        ud.set(activeBranchFinal, forKey: "kmi.user.branch")
        ud.set(branchesCsv, forKey: "branches_csv")

        // ✅ groups
        ud.set(groupsArray, forKey: "groups")
        ud.set(groupsCsv, forKey: "age_groups")
        ud.set(primaryGroup, forKey: "age_group")
        ud.set(primaryGroup, forKey: "group")
        ud.set(activeGroupFinal, forKey: "active_group")
        ud.set(activeGroupFinal, forKey: "kmi.user.group")

        ud.set(usernameTrimmed, forKey: "username")
        ud.set(password, forKey: "password")

        ud.set(wantsSms, forKey: "wantsSms")
        ud.set(wantsSms, forKey: "subscribeSms")
        ud.set(acceptsTerms, forKey: "acceptsTerms")

        ud.set(roleKey, forKey: "user_role")
        ud.set(gender.trimmed, forKey: "gender")

        ud.set(birthDay.trimmed, forKey: "birthDay")
        ud.set(birthDay.trimmed, forKey: "birth_day")

        ud.set(birthMonth.trimmed, forKey: "birthMonth")
        ud.set(birthMonth.trimmed, forKey: "birth_month")

        ud.set(birthYear.trimmed, forKey: "birthYear")
        ud.set(birthYear.trimmed, forKey: "birth_year")

        ud.set(currentBeltId, forKey: "current_belt")
        ud.set(currentBeltId, forKey: "belt_current")
        ud.set(currentBeltId, forKey: "belt")
        ud.set(belt.trimmed, forKey: "belt_he")

        if role == .coach {
            ud.set(coachCode.trimmed, forKey: "coachCode")
            ud.set(coachCode.trimmed, forKey: "coach_code")
        } else {
            ud.removeObject(forKey: "coachCode")
            ud.removeObject(forKey: "coach_code")
        }

        ud.set(true, forKey: "is_logged_in")
    }
}
