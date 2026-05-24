import Foundation

struct DockItem: Identifiable, Equatable {
    let name: String
    let url: URL
    let bundleIdentifier: String?

    var id: String {
        bundleIdentifier ?? url.path
    }
}
