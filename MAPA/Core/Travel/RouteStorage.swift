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

    /// Нынешний формат. Поднимается вместе со схемой, и каждый переход
    /// получает свой шаг в `migrated(_:)`.
    static let currentVersion = 1

    /// Привести снимок к нынешнему формату.
    ///
    /// Поля, добавленные необязательными — день выезда, например, —
    /// переходов не требуют: старый файл читается и получает `nil`.
    /// Шаг понадобится первому изменению, которое нельзя выразить
    /// необязательным полем, и писать его в спешке будет уже поздно.
    static func migrated(_ snapshot: RoutesSnapshot) -> RoutesSnapshot {
        snapshot
    }
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
            guard let data = try? Data(contentsOf: fileURL) else {
                throw StorageFailure.unreadable
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stored = try SchemaProbe.decode(RoutesSnapshot.self,
                                                from: data,
                                                supported: RoutesSnapshot.currentVersion,
                                                using: decoder)
            return RoutesSnapshot.migrated(stored).routes
        }.value
    }

    func save(_ routes: [Route]) async throws {
        let snapshot = RoutesSnapshot(version: RoutesSnapshot.currentVersion,
                                      routes: routes,
                                      updatedAt: Date())
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
