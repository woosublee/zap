enum AppDistribution: Equatable {
    case direct
    case appStore

    static var current: AppDistribution {
        #if ZAP_APP_STORE
        .appStore
        #else
        .direct
        #endif
    }

    var supportsInAppUpdates: Bool {
        self == .direct
    }
}
