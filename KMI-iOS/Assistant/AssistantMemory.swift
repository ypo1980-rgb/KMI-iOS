import Foundation

final class AssistantMemory {
    private let defaults: UserDefaults
    private let prefix: String

    init(
        defaults: UserDefaults = .standard,
        prefix: String = "kmi_assistant_memory"
    ) {
        self.defaults = defaults
        self.prefix = prefix
    }

    private func key(_ suffix: String) -> String {
        "\(prefix).\(suffix)"
    }

    func setLastBranch(_ value: String?) {
        defaults.set(value, forKey: key("branch"))
    }

    func getLastBranch() -> String? {
        defaults.string(forKey: key("branch"))
    }

    func setLastGroup(_ value: String?) {
        defaults.set(value, forKey: key("group"))
    }

    func getLastGroup() -> String? {
        defaults.string(forKey: key("group"))
    }

    func setLastDay(_ value: String?) {
        defaults.set(value, forKey: key("day"))
    }

    func getLastDay() -> String? {
        defaults.string(forKey: key("day"))
    }

    func setLastIntent(_ value: String?) {
        defaults.set(value, forKey: key("assistant_last_intent"))
    }

    func getLastIntent() -> String? {
        defaults.string(forKey: key("assistant_last_intent"))
    }

    func setLastAnswerContext(_ value: String?) {
        defaults.set(value, forKey: key("assistant_last_answer"))
    }

    func getLastAnswerContext() -> String? {
        defaults.string(forKey: key("assistant_last_answer"))
    }

    func clearMemory() {
        defaults.removeObject(forKey: key("branch"))
        defaults.removeObject(forKey: key("group"))
        defaults.removeObject(forKey: key("day"))
        defaults.removeObject(forKey: key("assistant_last_intent"))
        defaults.removeObject(forKey: key("assistant_last_answer"))
    }
}
