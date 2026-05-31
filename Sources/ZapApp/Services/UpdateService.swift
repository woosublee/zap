import Foundation
import Sparkle

@MainActor
protocol UpdateDriving: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var canCheckForUpdates: Bool { get }

    func start()
    func checkForUpdates()
}

@MainActor
final class UpdateService: ObservableObject {
    private let driverFactory: @MainActor () -> UpdateDriving
    private let buildTagProvider: () -> String?
    private lazy var driver = driverFactory()
    private var hasStarted = false

    init(
        driverFactory: @escaping @MainActor () -> UpdateDriving = { SparkleUpdateDriver() },
        buildTagProvider: @escaping () -> String? = {
            Bundle.main.object(forInfoDictionaryKey: "ZapBuildTag") as? String
        }
    ) {
        self.driverFactory = driverFactory
        self.buildTagProvider = buildTagProvider
    }

    var automaticallyChecksForUpdates: Bool {
        get { driver.automaticallyChecksForUpdates }
        set { driver.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        driver.canCheckForUpdates
    }

    func start() {
        guard Self.isReleaseBuildTagForAutomaticChecks(buildTagProvider()) else {
            return
        }

        startIfNeeded()
    }

    func checkForUpdates() {
        if !Self.isReleaseBuildTagForAutomaticChecks(buildTagProvider()) {
            driver.automaticallyChecksForUpdates = false
        }

        startIfNeeded()
        driver.checkForUpdates()
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        driver.start()
        hasStarted = true
    }

    nonisolated static func isReleaseBuildTagForAutomaticChecks(_ buildTag: String?) -> Bool {
        guard let buildTag = buildTag?.trimmingCharacters(in: .whitespacesAndNewlines),
              buildTag.hasPrefix("v") || buildTag.hasPrefix("V") else {
            return false
        }

        var normalized = buildTag
        normalized.removeFirst()

        let versionAndBuildMetadata = normalized
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        guard let versionPart = versionAndBuildMetadata.first,
              !versionPart.isEmpty else {
            return false
        }

        if versionAndBuildMetadata.count > 1 {
            let buildMetadata = versionAndBuildMetadata[1]
            let identifiers = buildMetadata.split(separator: ".", omittingEmptySubsequences: false)
            guard !buildMetadata.isEmpty,
                  !identifiers.isEmpty,
                  identifiers.allSatisfy({ !$0.isEmpty }) else {
                return false
            }
        }

        let versionAndPrerelease = versionPart
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            .map(String.init)
        guard versionAndPrerelease.count >= 1 else { return false }

        let coreComponents = versionAndPrerelease[0]
            .split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)
        guard coreComponents.count == 3,
              coreComponents.allSatisfy({ !$0.isEmpty && Int($0) != nil }) else {
            return false
        }

        if versionAndPrerelease.count > 1 {
            let prerelease = versionAndPrerelease[1]
            guard !prerelease.isEmpty else { return false }
            let identifiers = prerelease.split(separator: ".", omittingEmptySubsequences: false)
            guard !identifiers.isEmpty,
                  identifiers.allSatisfy({ !$0.isEmpty }) else {
                return false
            }
        }

        return true
    }
}

@MainActor
private final class SparkleUpdateDriver: UpdateDriving {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
