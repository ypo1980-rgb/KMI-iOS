import SwiftUI
import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case coach = "מאמן"
    case trainee = "מתאמן"
    var id: String { rawValue }
}

struct RegistrationFormState: Equatable {
    var role: UserRole = .trainee

    var coachCode: String = ""   // ✅ NEW: קוד מאמן

    var fullName: String = ""
    var phone: String = ""
    var email: String = ""

    var birthDay: String = ""
    var birthMonth: String = ""
    var birthYear: String = ""

    var username: String = ""
    var password: String = ""
    var showPassword: Bool = false

    var region: String = "השרון"
    var branches: Set<String> = []
    var groups: Set<String> = []
    var belt: String = "ללא"

    var wantsSms: Bool = true
    var acceptsTerms: Bool = false
}

// MARK: - Helpers

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension RegistrationFormState {

    // ✅ NEW: ערך יציב לשרת/שיתוף בין אנדרואיד+iOS
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

    var branchesArray: [String] { branches.map { $0.trimmed }.filter { !$0.isEmpty }.sorted() }
    var groupsArray: [String] { groups.map { $0.trimmed }.filter { !$0.isEmpty }.sorted() }

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

            "username": usernameTrimmed,
            "usernameLower": usernameLower,

            "region": region.trimmed,
            "branches": branchesArray,
            "groups": groupsArray,
            "belt": belt.trimmed,
            "beltId": belt.trimmed,   // ✅ NEW – תואם ללוגיקה של AuthViewModel

            "wantsSms": wantsSms,
            "acceptsTerms": acceptsTerms,

            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970
        ]

        // ✅ NEW: רק למאמן
        if role == .coach {
            dict["coachCode"] = coachCode.trimmed
        }

        return dict
    }
    
    func persistToUserDefaults() {
        let ud = UserDefaults.standard

        ud.set(roleKey, forKey: "user_role")
        ud.set(fullNameTrimmed, forKey: "full_name")
        ud.set(phoneNormalized, forKey: "phone")

        ud.set(emailLower, forKey: "email")
        ud.set(emailLower, forKey: "email_lower")

        ud.set(usernameTrimmed, forKey: "user_name")
        ud.set(usernameLower, forKey: "user_name_lower")

        ud.set(region.trimmed, forKey: "region")
        ud.set(region.trimmed, forKey: "kmi.user.region")   // ✅ HomeViewModel

        ud.set(belt.trimmed, forKey: "belt")
        ud.set(usernameLower, forKey: "last_login_hint")

        if role == .coach {
            ud.set(coachCode.trimmed, forKey: "coach_code")
        } else {
            ud.removeObject(forKey: "coach_code")
        }

        let branchList = branchesArray
        let groupList = groupsArray

        if let data = try? JSONEncoder().encode(branchList),
           let str = String(data: data, encoding: .utf8) {
            ud.set(str, forKey: "branches_json")
        }

        let branchesCsv = branchList.joined(separator: ",")
        ud.set(branchesCsv, forKey: "branches")

        let groupsCsv = groupList.joined(separator: ",")
        ud.set(groupsCsv, forKey: "age_groups")
        ud.set(groupsCsv, forKey: "age_group")
        ud.set(groupsCsv, forKey: "group")

        // ✅ השיוך הראשי שמסך הבית כבר קורא
        let primaryBranch = branchList.first ?? ""
        let primaryGroup = groupList.first ?? ""

        ud.set(primaryBranch, forKey: "branch")
        ud.set(primaryBranch, forKey: "kmi.user.branch")

        ud.set(primaryGroup, forKey: "kmi.user.group")
    }
}
