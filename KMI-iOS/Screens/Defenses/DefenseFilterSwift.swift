//
//  DefenseFilterSwift.swift
//  KMI-iOS
//
//  Created by יובל פולק on 28/02/2026.
//import Foundation
import Shared

enum DefenseUIKind: String, CaseIterable, Identifiable {
    case internalDef = "פנימיות"
    case externalDef = "חיצוניות"
    var id: String { rawValue }
}

enum AttackUIType: String, CaseIterable, Identifiable {
    case punch = "אגרופים"
    case kick  = "בעיטות"
    var id: String { rawValue }
}

struct DefenseFilterSwift {

    static func isPunch(_ text: String) -> Bool {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.contains("אגרוף") || s.contains("אגרופים")
    }

    static func isKick(_ text: String) -> Bool {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.contains("בעיטה") || s.contains("בעיטות")
    }

    static func matchesAttack(subTopicTitle: String?, item: String, type: AttackUIType) -> Bool {
        let sub = subTopicTitle ?? ""
        switch type {
        case .punch:
            return isPunch(sub) || isPunch(item)
        case .kick:
            return isKick(sub) || isKick(item)
        }
    }

    /// פילטר לפי הטקסט של הנושא הראשי בחגורה (פנימיות/חיצוניות) + תת־נושא/פריט (אגרוף/בעיטה)
    static func filteredItems(belt: Belt, kind: DefenseUIKind, type: AttackUIType) -> [String] {
        let catalog = CatalogData.shared.data
        guard let beltContent = catalog[belt] else { return [] }

        let kindNeedle = (kind == .internalDef) ? "הגנות פנימיות" : "הגנות חיצוניות"

        // מוצאים נושאים שיש בהם "הגנות פנימיות/חיצוניות" בכותרת
        let defenseTopics = beltContent.topics.filter { $0.title.contains(kindNeedle) }

        // אוספים פריטים מתוך subTopics כדי לדעת אם זה punch/kick (ולא רק items כלליים)
        var out: [String] = []
        for t in defenseTopics {
            for st in t.subTopics {
                for item in st.items {
                    if matchesAttack(subTopicTitle: st.title, item: item, type: type) {
                        out.append(item)
                    }
                }
            }
            // אם יש גם items ישירות על topic (בלי subtopic), ננסה לסנן לפי הטקסט עצמו
            for item in t.items {
                if matchesAttack(subTopicTitle: t.title, item: item, type: type) {
                    out.append(item)
                }
            }
        }

        // ניקוי כפילויות ושמירה על סדר הופעה
        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }
}

