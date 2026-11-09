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
            XCTAssertEqual(error as? StorageFailure, .futureVersion(found: 99, supported: 2))
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

    func testНастоящийСтарыйФайлПервойВерсииЧитается() async throws {
        // Ровно то, что записывала прежняя версия: номер формата, статусы
        // строками и дом. Пока переходов между версиями нет, проверка
        // сторожит сам факт чтения по номеру формата.
        write(OldFiles.travelLogV1)
        let log = try await FileTravelLogStorage(fileName: fileName).load()

        XCTAssertEqual(log.status(for: "ITA"), .visited)
        XCTAssertEqual(log.status(for: "JPN"), .wishlist)
        XCTAssertEqual(log.home?.cityName, "Варшава")
    }

    func testНеизвестныйСтатусНеРонитВсюКарту() async throws {
        write(OldFiles.travelLogWithUnknownStatus)
        let log = try await FileTravelLogStorage(fileName: fileName).load()

        // Потерять одну непонятную отметку лучше, чем всю карту: файл
        // прочитан, и запись не останавливается.
        XCTAssertEqual(log.status(for: "ITA"), .visited)
        XCTAssertNil(log.status(for: "XXX"))
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

    func testНастоящийСтарыйФайлМаршрутовЧитается() async throws {
        write(OldFiles.routesV1)
        let routes = try await FileRouteStorage(fileName: fileName).load()

        XCTAssertEqual(routes.map(\.title), ["Италия"])
        XCTAssertEqual(routes[0].points.map(\.name), ["Рим"])
        // Поля, появившиеся позже, читаются пустыми, а не придуманными.
        XCTAssertNil(routes[0].startDate)
        XCTAssertFalse(routes[0].points[0].isVisited)
    }

    func testФайлМаршрутовПервойВерсииПереезжаетНаВторую() async throws {
        write(OldFiles.routesV1)
        let storage = FileRouteStorage(fileName: fileName)

        let routes = try await storage.load()
        XCTAssertEqual(routes.count, 1)

        // Состояние выведено при чтении, а не поставлено черновиком всем
        // подряд: точки в этом файле не пройдены.
        XCTAssertEqual(routes[0].status, .draft)

        try await storage.save(routes)
        let raw = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(raw.contains("\"version\":2"), "файл должен перезаписаться новым форматом")

        // Повторный запуск миграции ничего не ломает и не выводит заново.
        let again = try await storage.load()
        XCTAssertEqual(again[0].status, .draft)
        XCTAssertEqual(again[0].title, "Италия")
    }

    func testФайлМаршрутовБудущейВерсииНеЧитается() async {
        write(#"{"version":77,"routes":[],"updatedAt":"2026-01-01T00:00:00Z"}"#)
        let storage = FileRouteStorage(fileName: fileName)

        do {
            _ = try await storage.load()
            XCTFail("файл новой версии открывать нельзя")
        } catch {
            XCTAssertEqual(error as? StorageFailure, .futureVersion(found: 77, supported: 2))
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

/// Файлы, какими их писали прежние версии приложения.
///
/// Лежат строками, а не собираются кодом: смысл проверки в том, чтобы
/// читался настоящий старый файл, а не то, что сегодняшний кодировщик
/// считает старым форматом.
private enum OldFiles {

    static let travelLogV1 = """
    {"version":1,"statuses":{"ITA":"visited","JPN":"wishlist","POL":"living"},\
    "home":{"countryID":"POL","cityName":"Варшава","longitude":21,"latitude":52.2},\
    "updatedAt":"2026-02-01T10:00:00Z"}
    """

    static let travelLogWithUnknownStatus = """
    {"version":1,"statuses":{"ITA":"visited","XXX":"teleported"},\
    "updatedAt":"2026-02-01T10:00:00Z"}
    """

    static let routesV1 = """
    {"version":1,"updatedAt":"2026-02-01T10:00:00Z","routes":[\
    {"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","title":"Италия",\
    "createdAt":"2026-01-10T10:00:00Z","reviews":[],"points":[\
    {"id":"6B29FC40-CA47-1067-B31D-00DD010662DB","name":"Рим",\
    "longitude":12.5,"latitude":41.9,"days":3,"budget":0,"note":""}]}]}
    """
}

/// Города и места: переход файла журнала на вторую версию.
@MainActor
final class VisitedPlacesTests: XCTestCase {

    private var fileName = "visited-\(UUID().uuidString).json"

    private var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(fileName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testСтарыйЖурналЧитаетсяИПереезжаетНаВторуюВерсию() async throws {
        try Data(OldFiles.travelLogV1.utf8).write(to: fileURL, options: .atomic)
        let storage = FileTravelLogStorage(fileName: fileName)

        var log = try await storage.load()
        XCTAssertEqual(log.status(for: "ITA"), .visited)
        // Городов и мест в старом файле нет — это более ранний формат,
        // а не пустая карта.
        XCTAssertTrue(log.visitedCities.isEmpty)
        XCTAssertTrue(log.visitedPlaces.isEmpty)

        log.setCityVisited(true, cityID: "ITA-Rome")
        try await storage.save(log)

        let raw = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(raw.contains("\"version\":2"), "файл должен перезаписаться новым форматом")

        let back = try await storage.load()
        XCTAssertTrue(back.isCityVisited("ITA-Rome"))
        XCTAssertEqual(back.status(for: "ITA"), .visited, "старое не потерялось")
    }

    func testКлючМестаНеЗависитОтНазвания() {
        let landmark = Landmark(ru: "Колизей", en: "Colosseum", small: nil, large: nil,
                                author: nil, license: nil, lon: 12.4922, lat: 41.8902)
        let renamed = Landmark(ru: "Колизей (Флавиев амфитеатр)", en: "Colosseum",
                               small: nil, large: nil, author: nil, license: nil,
                               lon: 12.4922, lat: 41.8902)

        XCTAssertEqual(VisitedPlace.key(for: landmark), VisitedPlace.key(for: renamed),
                       "каталог пересобирается, а прошлое человека меняться не должно")
    }

    func testМестоБезКоординатОтметитьНельзя() {
        let nowhere = Landmark(ru: "Где-то", en: "Somewhere", small: nil, large: nil,
                               author: nil, license: nil, lon: nil, lat: nil)
        XCTAssertNil(VisitedPlace.key(for: nowhere))
        XCTAssertNil(VisitedPlace(landmark: nowhere, cityID: "ITA-Rome"))
    }

    func testПройденнаяТочкаМаршрутаСчитаетсяПосещённымГородом() async throws {
        var point = RoutePoint(cityID: "JPN-Tokyo", name: "Токио", countryID: "JPN",
                               coordinate: Coordinate(longitude: 139.7, latitude: 35.7))
        point.isVisited = true
        let route = Route(title: "Япония", points: [point])

        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(),
                                      routeStorage: EphemeralRouteStorage(initial: [route]))
        await model.load()

        XCTAssertTrue(model.visitedCityIDs.contains("JPN-Tokyo"))
        XCTAssertEqual(model.statistics.visitedCityCount, 1)
        // В журнале этой отметки нет: она выводится из маршрута, а не
        // хранится дважды.
        XCTAssertFalse(model.travelLog.isCityVisited("JPN-Tokyo"))
    }
}
