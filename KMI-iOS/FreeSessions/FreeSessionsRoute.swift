import Foundation

enum FreeSessionsRoute {
    static let pattern = "free_sessions/{branch}/{groupKey}/{uid}/{name}"

    static func build(
        branch: String,
        groupKey: String,
        uid: String,
        name: String
    ) -> String {
        func enc(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        }

        return "free_sessions/\(enc(branch))/\(enc(groupKey))/\(enc(uid))/\(enc(name))"
    }
}
