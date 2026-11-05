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
    ///
    /// 1 — маршрут без состояния: только города, дни и отзывы.
    /// 2 — у маршрута появилось состояние поездки.
    static let currentVersion = 2

    /// Привести снимок к нынешнему формату.
    ///
    /// Переход с первой версии делает сам разбор маршрута: состояния в
    /// старом файле нет, и оно выводится из пройденных точек — ставить
    /// всем «черновик» значило бы спрятать уже совершённые поездки в
    /// раздел набросков. Здесь остаётся поднять номер формата, чтобы
    /// файл перезаписался в новом виде и второй раз ничего не выводилось.
    ///
    /// Повторный запуск безопасен: снимок нынешней версии возвращается
    /// как есть.
    static func migrated(_ snapshot: RoutesSnapshot) -> RoutesSnapshot {
        guard snapshot.version < currentVersion else { return snapshot }
        var result = snapshot
        result.version = currentVersion
        return result
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
