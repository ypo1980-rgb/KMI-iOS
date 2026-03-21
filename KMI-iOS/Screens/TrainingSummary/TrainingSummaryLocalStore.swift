import Foundation

final class TrainingSummaryLocalStore {
    static let shared = TrainingSummaryLocalStore()
    private init() {}

    private let defaults = UserDefaults.standard
    private let prefix = "training_summary"
    private let markedDaysPrefix = "training_summary_days"

    private func keyFor(ownerUid: String, role: SummaryAuthorRole, summaryId: String) -> String {
        "\(prefix)_\(ownerUid.trimmed())_\(role.rawValue)_\(summaryId.trimmed())"
    }

    private func markedDaysKey(ownerUid: String, role: SummaryAuthorRole) -> String {
        "\(markedDaysPrefix)_\(ownerUid.trimmed())_\(role.rawValue)"
    }

    func loadForOwner(
        ownerUid: String,
        role: SummaryAuthorRole,
        summaryId: String
    ) -> TrainingSummaryEntity? {
        guard
            let data = defaults.data(forKey: keyFor(ownerUid: ownerUid, role: role, summaryId: summaryId)),
            let decoded = try? JSONDecoder().decode(TrainingSummaryEntity.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveForOwner(
        ownerUid: String,
        role: SummaryAuthorRole,
        summary: TrainingSummaryEntity
    ) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var toSave = summary
        toSave.ownerUid = ownerUid.trimmed()
        toSave.ownerRole = role
        if toSave.createdAtMs <= 0 { toSave.createdAtMs = now }
        toSave.updatedAtMs = now

        if let encoded = try? JSONEncoder().encode(toSave) {
            defaults.set(encoded, forKey: keyFor(ownerUid: ownerUid, role: role, summaryId: toSave.id))
        }

        addMarkedDay(ownerUid: ownerUid, role: role, dateIso: toSave.dateIso)
    }

    func clearForOwner(
        ownerUid: String,
        role: SummaryAuthorRole,
        summaryId: String
    ) {
        defaults.removeObject(forKey: keyFor(ownerUid: ownerUid, role: role, summaryId: summaryId))
    }

    func addMarkedDay(ownerUid: String, role: SummaryAuthorRole, dateIso: String) {
        let key = markedDaysKey(ownerUid: ownerUid, role: role)
        var set = defaults.stringArray(forKey: key) ?? []
        let clean = dateIso.trimmed()
        if !clean.isEmpty && !set.contains(clean) {
            set.append(clean)
            defaults.set(set, forKey: key)
        }
    }

    func listDatesForOwnerBetween(
        ownerUid: String,
        role: SummaryAuthorRole,
        startIso: String,
        endIsoExclusive: String
    ) -> Set<String> {
        let key = markedDaysKey(ownerUid: ownerUid, role: role)
        let all = Set(defaults.stringArray(forKey: key) ?? [])
        return Set(
            all.filter { iso in
                iso >= startIso && iso < endIsoExclusive
            }
        )
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
