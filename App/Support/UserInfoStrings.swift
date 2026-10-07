import Foundation

enum UserInfoStrings {
    static func parse(_ userInfo: [AnyHashable: Any]?) -> [String: String] {
        guard let userInfo else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in userInfo {
            guard let key = key as? String else { continue }
            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            }
        }
        return result
    }
}
