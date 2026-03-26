import Foundation

struct CoachCodeGenerator {

    static func generate() -> String {
        let number = Int.random(in: 0...999999)
        return String(format: "%06d", number)
    }

}
