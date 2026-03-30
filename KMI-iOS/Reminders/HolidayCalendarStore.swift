import Foundation

struct HolidayFileItem: Codable {
    let date_iso: String?
    let name: String
}

struct HolidayFileRoot: Codable {
    let timezone: String?
    let items: [HolidayFileItem]
}

enum HolidayCalendarStore {

    private static let fileName = "holidays_hebrew_2024_2026"
    private static let fileExtension = "json"

    struct HolidayEntry: Hashable {
        let date: Date
        let name: String
    }

    static func loadEntries() -> [HolidayEntry] {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(HolidayFileRoot.self, from: data)
        else {
            return []
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "yyyy-MM-dd"

        return root.items.compactMap { item in
            guard let iso = item.date_iso,
                  let date = formatter.date(from: iso)
            else { return nil }

            return HolidayEntry(date: date, name: item.name)
        }
    }
}
