import Foundation

/// Хранилище маршрутов.
///
/// Отдельный протокол и отдельный файл, а не поле в отметках: на 12-м этапе
/// маршруты уедут в Supabase и станут общими, а отметки на карте останутся
/// личными. Смешивать то, что разъедется, — значит потом это разделять.
protocol RouteStorage {
    func load() async throws -> [Route]
    func save(_ routes: [Route]) async throws
}

private struct RoutesSnapshot: Codable {
    var version: Int
    var routes: [Route]
    var updatedAt: Date
}

struct FileRouteStorage: RouteStorage {

    private let fileURL: URL

    init(fileName: String = "routes.json") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(fileName)
    }

    func load() async throws -> [Route] {
        try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(RoutesSnapshot.self, from: data).routes
        }.value
    }

    func save(_ routes: [Route]) async throws {
        let snapshot = RoutesSnapshot(version: 1, routes: routes, updatedAt: Date())
        try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        }.value
    }
}

struct EphemeralRouteStorage: RouteStorage {
    var initial: [Route] = []
    func load() async throws -> [Route] { initial }
    func save(_ routes: [Route]) async throws {}
}
