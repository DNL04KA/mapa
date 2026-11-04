import Foundation

/// Хранилище отметок.
///
/// Протокол существует ровно затем, чтобы всё остальное приложение не знало,
/// где именно лежат данные. Сейчас за ним файл, дальше встанет SwiftData —
/// поменяется одна строка в инициализаторе вьюмодели.
protocol TravelLogStorage {
    func load() async throws -> TravelLog
    func save(_ log: TravelLog) async throws
}

/// То, что реально попадает на диск.
///
/// Статус хранится строкой, а не индексом: если завтра в перечислении
/// поменяется порядок, старые файлы не превратятся в кашу.
/// `version` читается при каждом открытии: файл, записанный версией новее
/// этой, мы не трогаем вовсе — в нём есть то, чего мы не умеем записать
/// обратно.
private struct TravelLogSnapshot: Codable {
    var version: Int
    var statuses: [String: String]
    var home: HomePlace?
    var updatedAt: Date

    /// Нынешний формат. Меняется вместе со схемой, и каждый переход
    /// получает свой шаг в `migrated(_:)`.
    static let currentVersion = 1

    /// Привести снимок к нынешнему формату.
    ///
    /// Переходов пока нет — формат один. Место для них есть здесь, а не
    /// россыпью необязательных полей по всей модели: иначе через год
    /// никто не скажет, какая версия что значила.
    static func migrated(_ snapshot: TravelLogSnapshot) -> TravelLogSnapshot {
        snapshot
    }
}

/// Файловое хранилище в Application Support.
struct FileTravelLogStorage: TravelLogStorage {

    private let fileURL: URL

    init(fileName: String = "travel-log.json") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        // Application Support при первом запуске может не существовать.
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        fileURL = base.appendingPathComponent(fileName)
    }

    func load() async throws -> TravelLog {
        try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return TravelLog()
            }

            guard let data = try? Data(contentsOf: fileURL) else {
                throw StorageFailure.unreadable
            }
            // Даты в .iso8601, как и в маршрутах: один формат на оба файла,
            // иначе копия карты и копия маршрутов расходятся в мелочи,
            // которая всплывёт при первом же обмене файлами.
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stored = try SchemaProbe.decode(TravelLogSnapshot.self,
                                                from: data,
                                                supported: TravelLogSnapshot.currentVersion,
                                                using: decoder)
            let snapshot = TravelLogSnapshot.migrated(stored)

            // Неизвестные статусы просто отбрасываем: лучше потерять одну отметку,
            // чем уронить загрузку всей карты.
            let statuses = snapshot.statuses.compactMapValues(TravelStatus.init(rawValue:))
            return TravelLog(statuses: statuses, home: snapshot.home)
        }.value
    }

    func save(_ log: TravelLog) async throws {
        let snapshot = TravelLogSnapshot(
            version: TravelLogSnapshot.currentVersion,
            statuses: log.statuses.mapValues(\.rawValue),
            home: log.home,
            updatedAt: Date()
        )

        try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            // Атомарно: при обрыве на записи старый файл остаётся целым.
            try data.write(to: fileURL, options: .atomic)
        }.value
    }
}

/// Хранилище для превью и тестов: ничего не пишет.
struct EphemeralTravelLogStorage: TravelLogStorage {
    var initial = TravelLog()
    func load() async throws -> TravelLog { initial }
    func save(_ log: TravelLog) async throws {}
}
