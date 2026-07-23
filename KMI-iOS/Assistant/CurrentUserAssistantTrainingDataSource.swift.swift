import Foundation

final class CurrentUserAssistantTrainingDataSource:
    AssistantTrainingDataSource {

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func allTrainings() -> [TrainingRow] {
        let region = firstStoredValue(
            keys: [
                "active_region",
                "region",
                "kmi.user.region"
            ]
        )

        let branch = firstStoredValue(
            keys: [
                "active_branch",
                "branch",
                "kmi.user.branch"
            ]
        )

        let group = firstStoredValue(
            keys: [
                "active_group",
                "group",
                "age_group",
                "kmi.user.group"
            ]
        )

        guard !region.isEmpty,
              !branch.isEmpty,
              !group.isEmpty else {
            return []
        }

        guard TrainingCatalogIOS.regionStatusMessage(region) == nil else {
            return []
        }

        let trainings = TrainingCatalogIOS.upcomingFor(
            region: region,
            branch: branch,
            group: group,
            count: 50
        )

        return trainings
            .filter {
                !$0.isPast(
                    now: Date(),
                    graceMinutes: 1
                )
            }
            .sorted {
                $0.date < $1.date
            }
            .map { training in
                makeTrainingRow(
                    training: training,
                    branch: branch,
                    group: group
                )
            }
    }

    private func makeTrainingRow(
        training: TrainingData,
        branch: String,
        group: String
    ) -> TrainingRow {
        TrainingRow(
            branchName: branch,
            groupName: group,
            dayName: formattedDayName(training.date),
            timeRange: formattedTimeRange(training),
            location: formattedLocation(training),
            coachName: cleanValue(training.coach),
            startAtMillis: training.startMillis
        )
    }

    private func formattedDayName(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(
            identifier: isEnglish ? "en_US" : "he_IL"
        )
        formatter.dateFormat = "EEEE"

        return formatter.string(from: date)
    }

    private func formattedTimeRange(
        _ training: TrainingData
    ) -> String {
        let startFormatter = DateFormatter()
        startFormatter.calendar = calendar
        startFormatter.locale = Locale(identifier: "en_US_POSIX")
        startFormatter.dateFormat = "HH:mm"

        let startTime = startFormatter.string(
            from: training.date
        )

        let cleanEnd = cleanTimeText(training.endText)

        guard !cleanEnd.isEmpty else {
            return startTime
        }

        return "\(startTime)–\(cleanEnd)"
    }

    private func cleanTimeText(
        _ value: String
    ) -> String {
        let clean = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if let match = clean.range(
            of: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#,
            options: .regularExpression
        ) {
            return String(clean[match])
        }

        return clean
    }

    private func formattedLocation(
        _ training: TrainingData
    ) -> String {
        let place = cleanValue(training.place)
        let address = cleanValue(training.address)

        if place.isEmpty {
            return address
        }

        if address.isEmpty ||
            normalized(place) == normalized(address) {
            return place
        }

        return "\(place), \(address)"
    }

    private func firstStoredValue(
        keys: [String]
    ) -> String {
        for key in keys {
            guard let rawValue = defaults.string(
                forKey: key
            ) else {
                continue
            }

            let values = splitStoredValues(rawValue)

            if let first = values.first {
                return first
            }
        }

        return ""
    }

    private func splitStoredValues(
        _ value: String
    ) -> [String] {
        value
            .components(
                separatedBy: CharacterSet(
                    charactersIn: ",;|\n"
                )
            )
            .map(cleanValue)
            .filter { !$0.isEmpty }
    }

    private func cleanValue(
        _ value: String
    ) -> String {
        value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func normalized(
        _ value: String
    ) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "־", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
    }

    private var isEnglish: Bool {
        let values = [
            defaults.string(forKey: "kmi_app_language") ?? "",
            defaults.string(forKey: "selected_language_code") ?? "",
            defaults.string(forKey: "app_language") ?? "",
            defaults.string(forKey: "initial_language_code") ?? ""
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()
        }

        return values.contains("en") ||
            values.contains("english")
    }
}
