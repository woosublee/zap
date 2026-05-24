import Foundation

protocol DockItemProviding {
    func currentDockItems() -> [DockItem]
}

struct DockItemProvider: DockItemProviding {
    private let dockPlistURL: URL

    init(dockPlistURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Preferences/com.apple.dock.plist")) {
        self.dockPlistURL = dockPlistURL
    }

    func currentDockItems() -> [DockItem] {
        guard let data = try? Data(contentsOf: dockPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let apps = plist["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        return apps.compactMap(Self.dockItem(from:))
    }

    private static func dockItem(from item: [String: Any]) -> DockItem? {
        guard let tileData = item["tile-data"] as? [String: Any],
              let fileData = tileData["file-data"] as? [String: Any],
              let rawURL = fileData["_CFURLString"] as? String,
              let url = appURL(from: rawURL),
              url.pathExtension == "app" else {
            return nil
        }

        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent

        return DockItem(
            name: name,
            url: url,
            bundleIdentifier: bundle?.bundleIdentifier
        )
    }

    private static func appURL(from rawURL: String) -> URL? {
        if rawURL.hasPrefix("file://") {
            return URL(string: rawURL)
        }
        if rawURL.hasPrefix("/") {
            return URL(fileURLWithPath: rawURL)
        }
        return nil
    }
}
