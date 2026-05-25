import Foundation

struct AboutInfo: Equatable {
    let version: String
    let buildNumber: String
    let creator: String

    static var current: AboutInfo {
        make(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    static func make(infoDictionary: [String: Any]) -> AboutInfo {
        AboutInfo(
            version: stringValue(for: "CFBundleShortVersionString", in: infoDictionary) ?? "Unknown",
            buildNumber: stringValue(for: "CFBundleVersion", in: infoDictionary) ?? "Unknown",
            creator: "Woosub Lee"
        )
    }

    private static func stringValue(for key: String, in infoDictionary: [String: Any]) -> String? {
        guard let value = infoDictionary[key] as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
