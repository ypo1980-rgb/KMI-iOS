import Foundation

struct CoachWhitelist {
    
    static let allowedPhones: [String: String] = [
        "0526664660": "יובל פולק",
        "0524887178": "יוני מלסה",
        "0526969287": "איציק ביטון",
        "0585911518": "אדם הולצמן",
        "0526319090": "גל חג'ג'"
    ]
    
    static let allowedEmails: [String: String] = [
        "ypo1980@gmail.com": "יובל פולק",
        "yonatanmalesa99@gmail.com": "יוני מלסה",
        "coach3@example.com": "מאמן 3"
    ]
    
    static func isWhitelisted(phone: String, email: String) -> Bool {
        
        let normalizedPhone = phone.filter { $0.isNumber }
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if allowedPhones[normalizedPhone] != nil {
            return true
        }
        
        if allowedEmails[normalizedEmail] != nil {
            return true
        }
        
        return false
    }
}
