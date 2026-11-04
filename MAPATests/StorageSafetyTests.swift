import XCTest
@testable import MAPA

/// Что происходит, когда файл с данными не читается.
///
/// Самая дорогая ошибка в приложении — не падение, а тихая пустота:
/// приложение показывает чистую карту, человек пожимает плечами и ставит
/// первую отметку, и она записывается поверх пятнадцати лет поездок.
/// Поэтому проверяем не «не упало», а «не записало».
final class StorageSafetyTests: XCTestCase {

    private var fileName = ""

    private var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(fileName)
    }

    override func setUp() {
        super.setUp()
        fileName = "test-\(UUID().uuidString).json"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func write(_ text: String) {
        let base = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try? Data(text.utf8).write(to: fileURL, options: .atomic)
    }

    // MARK: - Отметки

    func testИспорченныйФайлОтметокНеЧитаетсяИОстаётсяНаМесте() async {
        write("{ это не json")
        let storage = FileTravelLogStorage(fileName: fileName)

        do {
            _ = try await storage.load()
            XCTFail("испорченный файл не должен читаться как пустая карта")
        } catch {
            XCTAssertEqual(error as? StorageFailure, .unreadable)
        }

        // Файл не тронут: в нём могут быть данные, которые починит
        // следующая версия приложения.
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testФайлБудущейВерсииНеЧитается() async {
        write(#"{"version":99,"statuses":{"ITA":"visited"},"updatedAt":"2026-01-01T00:00:00Z"}"#)
        let storage = FileTravelLogStorage(fileName: fileName)

        do {
            _ = try await storage.load()
            XCTFail("файл новой версии открывать нельзя")
        } catch {
            XCTAssertEqual(error as? StorageFailure, .futureVersion(found: 99, supported: 1))
        }
    }

    func testСвоимиЖеРукамиЗаписанноеЧитается() async throws {
        let storage = FileTravelLogStorage(fileName: fileName)
        var log = TravelLog()
        log.set(.visited, for: "ITA")
        log.set(.wishlist, for: "JPN")

        try await storage.save(log)
        let back = try await storage.load()

        XCTAssertEqual(back.status(for: "ITA"), .visited)
        XCTAssertEqual(back.status(for: "JPN"), .wishlist)
    }

    func testОтсутствующийФайлЭтоПустаяКартаАНеОшибка() async throws {
        let storage = FileTravelLogStorage(fileName: fileName)
        let log = try await storage.load()
        XCTAssertTrue(log.statuses.isEmpty, "первый запуск — это не поломка")
    }

    // MARK: - Маршруты

    func testИспорченныйФайлМаршрутовНеЧитается() async {
        write("{{{")
        let storage = FileRouteStorage(fileName: fileName)

        do {
            _ = try await storage.load()
            XCTFail("испорченный файл не должен читаться как «маршрутов нет»")
        } catch {
            XCTAssertEqual(error as? StorageFailure, .unreadable)
        }
    }

    func testФайлМаршрутовБудущейВерсииНеЧитается() async {
        write(#"{"version":7,"routes":[],"updatedAt":"2026-01-01T00:00:00Z"}"#)
        let storage = FileRouteStorage(fileName: fileName)

        do {
            _ = try await storage.load()
            XCTFail("файл новой версии открывать нельзя")
        } catch {
            XCTAssertEqual(error as? StorageFailure, .futureVersion(found: 7, supported: 1))
        }
    }
}

/// Приложение после неудачного чтения.
@MainActor
final class StorageLockTests: XCTestCase {

    func testПослеНеудачногоЧтенияОтметкаНеЗаписывается() async throws {
        let storage = FailingLogStorage()
        let model = WorldMapViewModel(storage: storage, routeStorage: SpyRouteStorage())
        await model.load()

        XCTAssertEqual(model.logFailure, .unreadable, "беду надо заметить")

        guard let italy = model.allCountries.first(where: { $0.id == "ITA" }) else {
            return XCTFail("нет Италии")
        }
        model.mark(.visited, for: italy)

        // Отметка на экране есть — человек её поставил, и спорить с ним
        // незачем. А вот на диск она не ушла: там лежит файл, который мы
        // не поняли, и переписывать его нельзя.
        XCTAssertEqual(model.travelLog.status(for: "ITA"), .visited)
        await model.flushPendingSaves()
        XCTAssertEqual(storage.saves, 0, "запись поверх непрочитанного файла")
    }

    func testИспорченныеМаршрутыНеМешаютОтмечатьСтраны() async throws {
        let log = SpyLogStorage()
        let model = WorldMapViewModel(storage: log, routeStorage: FailingRouteStorage())
        await model.load()

        XCTAssertEqual(model.routesFailure, .unreadable)
        XCTAssertNil(model.logFailure, "замки раздельные")

        guard let japan = model.allCountries.first(where: { $0.id == "JPN" }) else {
            return XCTFail("нет Японии")
        }
        model.mark(.wishlist, for: japan)
        await model.flushPendingSaves()

        XCTAssertGreaterThan(log.saves, 0, "целый файл отметок должен писаться")
    }
}

// MARK: - Двойники

private final class FailingLogStorage: TravelLogStorage {
    private(set) var saves = 0
    func load() async throws -> TravelLog { throw StorageFailure.unreadable }
    func save(_ log: TravelLog) async throws { saves += 1 }
}

private final class SpyLogStorage: TravelLogStorage {
    private(set) var saves = 0
    func load() async throws -> TravelLog { TravelLog() }
    func save(_ log: TravelLog) async throws { saves += 1 }
}

private final class FailingRouteStorage: RouteStorage {
    func load() async throws -> [Route] { throw StorageFailure.unreadable }
    func save(_ routes: [Route]) async throws {}
}

private final class SpyRouteStorage: RouteStorage {
    func load() async throws -> [Route] { [] }
    func save(_ routes: [Route]) async throws {}
}
