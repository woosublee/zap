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
        infoDictionary.trimmedString(for: "CFBundleDisplayName")
            ?? infoDictionary.trimmedString(for: "CFBundleName")
            ?? "Zap"
    }

    static func aboutMenuLabel(appName: String) -> String {
        "About \(appName)"
    }
}
