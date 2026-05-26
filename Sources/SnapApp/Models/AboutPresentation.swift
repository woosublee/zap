import Foundation

struct AboutPresentation: Equatable {
    let appName: String
    let versionLine: String
    let creatorLine: String
    let creatorURL: URL

    init(appName: String, info: AboutInfo) {
        self.appName = appName
        versionLine = "Version \(info.version) (\(info.buildNumber))"
        creatorLine = "Created by \(info.creator)"
        creatorURL = URL(string: "https://github.com/woosublee")!
    }

    static var currentAppName: String {
        appName(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    static func appName(infoDictionary: [String: Any]) -> String {
        stringValue(for: "CFBundleDisplayName", in: infoDictionary)
            ?? stringValue(for: "CFBundleName", in: infoDictionary)
            ?? "Zap"
    }

    static func aboutMenuLabel(appName: String) -> String {
        "About \(appName)"
    }

    private static func stringValue(for key: String, in infoDictionary: [String: Any]) -> String? {
        guard let value = infoDictionary[key] as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
