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
            version: infoDictionary.trimmedString(for: "CFBundleShortVersionString") ?? "Unknown",
            buildNumber: infoDictionary.trimmedString(for: "CFBundleVersion") ?? "Unknown",
            creator: "Woosub Lee"
        )
    }
}
