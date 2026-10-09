import Foundation

enum AppBuildFlavor: Equatable {
    case official
    case development

    init(bundleIdentifier: String?) {
        self = bundleIdentifier?.hasSuffix(".dev") == true ? .development : .official
    }

    static var current: AppBuildFlavor {
        AppBuildFlavor(bundleIdentifier: Bundle.main.bundleIdentifier)
    }
}
