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

    var activeBranch: String = ""
    var activeGroup: String = ""

    var belt: String = "ללא"

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
        case "צהובה": return "yellow"
        case "כתומה": return "orange"
        case "ירוקה": return "green"
        case "כחולה": return "blue"
        case "חומה": return "brown"
        case "שחורה": return "black"
        default: return "white"
        }
    }

    var canSubmit: Bool {
        acceptsTerms
        && !fullNameTrimmed.isEmpty
        && !emailLower.isEmpty
        && password.trimmed.count >= 6
        && !usernameLower.isEmpty
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
            "branches": branchesArray,
            "branchesCsv": branchesArray.joined(separator: ", "),
            "activeBranch": activeBranchFinal,
            "groups": groupsArray,
            "primaryGroup": primaryGroup,
            "activeGroup": activeGroupFinal,
            "belt": role == .trainee ? currentBeltId : "",
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
        ud.set(phone.trimmed, forKey: "phone")
        ud.set(emailTrimmed, forKey: "email")
        ud.set(region.trimmed, forKey: "region")

        ud.set(branchesCsv, forKey: "branch")
        ud.set(activeBranchFinal, forKey: "active_branch")

        ud.set(groupsCsv, forKey: "age_groups")
        ud.set(primaryGroup, forKey: "age_group")
        ud.set(primaryGroup, forKey: "group")
        ud.set(activeGroupFinal, forKey: "active_group")

        ud.set(usernameTrimmed, forKey: "username")
        ud.set(password, forKey: "password")
        ud.set(wantsSms, forKey: "subscribeSms")
        ud.set(roleKey, forKey: "user_role")
        ud.set(gender.trimmed, forKey: "gender")

        ud.set(birthDay.trimmed, forKey: "birth_day")
        ud.set(birthMonth.trimmed, forKey: "birth_month")
        ud.set(birthYear.trimmed, forKey: "birth_year")

        if role == .trainee {
            ud.set(currentBeltId, forKey: "current_belt")
            ud.set(currentBeltId, forKey: "belt_current")
        } else {
            ud.removeObject(forKey: "current_belt")
            ud.removeObject(forKey: "belt_current")
        }

        if role == .coach {
            ud.set(coachCode.trimmed, forKey: "coach_code")
        } else {
            ud.removeObject(forKey: "coach_code")
        }

        ud.set(true, forKey: "is_logged_in")
    }
}
