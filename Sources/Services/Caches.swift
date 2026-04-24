import Foundation

/// Small caches that persist the last successful API response to disk so the kiosk
/// can still launch and accept sign-ins while offline.

enum ServicesCache {
    private static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("services.json")
    }
    static func save(_ services: Services) {
        if let data = try? JSONEncoder().encode(services) {
            try? data.write(to: url, options: .atomic)
        }
    }
    static func load() -> Services? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Services.self, from: data)
    }
}

enum FranchiseCache {
    private static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("franchise.json")
    }
    static func save(_ info: FranchiseInfo) {
        if let data = try? JSONEncoder().encode(info) {
            try? data.write(to: url, options: .atomic)
        }
    }
    static func load() -> FranchiseInfo? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FranchiseInfo.self, from: data)
    }
}
