import XCTest
@testable import MAPA

/// Чтение сохранённых маршрутов.
///
/// Поля добавлялись по ходу: сначала появилась отметка «пройдено», потом
/// фотография, потом название страны. У человека на телефоне лежит файл,
/// записанный любой из прошлых версий, и он обязан открыться. Ошибка здесь
/// стоит дороже всех: это не «кнопка не нажалась», это «все мои маршруты
/// пропали».
final class RouteCodableTests: XCTestCase {

    private func decode(_ json: String) throws -> Route {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Route.self, from: Data(json.utf8))
    }

    func testСтарыйМаршрутБезНовыхПолейЧитается() throws {
        let json = """
        {
          "id": "6B29FC40-CA47-1067-B31D-00DD010662DA",
          "title": "Италия",
          "createdAt": "2026-09-10T10:00:00Z",
          "reviews": [],
          "points": [{
            "id": "6B29FC40-CA47-1067-B31D-00DD010662DB",
            "name": "Рим",
            "longitude": 12.5,
            "latitude": 41.9,
            "days": 3,
            "budget": 0,
            "note": ""
          }]
        }
        """
        let route = try decode(json)
        XCTAssertEqual(route.points.count, 1)
        XCTAssertEqual(route.points[0].name, "Рим")
        // Чего в старом файле не было, должно стать пустым, а не уронить чтение.
        XCTAssertFalse(route.points[0].isVisited)
        XCTAssertNil(route.points[0].photoID)
        XCTAssertNil(route.points[0].countryName)
    }

    func testЗаписьИЧтениеСовпадают() throws {
        let point = RoutePoint(cityID: "ITA-Rome", name: "Рим", countryID: "ITA",
                               countryName: "Италия",
                               coordinate: Coordinate(longitude: 12.5, latitude: 41.9),
                               days: 3, isVisited: true)
        let route = Route(title: "Италия", points: [point])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(route)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(Route.self, from: data)

        XCTAssertEqual(back.points[0].name, "Рим")
        XCTAssertEqual(back.points[0].countryName, "Италия")
        XCTAssertTrue(back.points[0].isVisited)
        XCTAssertEqual(back.points[0].days, 3)
    }

    func testПрогрессСчитаетсяПоОтметкам() {
        func point(_ name: String, done: Bool) -> RoutePoint {
            RoutePoint(name: name, coordinate: Coordinate(longitude: 0, latitude: 0),
                       isVisited: done)
        }
        let route = Route(title: "Тест", points: [
            point("а", done: true), point("б", done: true), point("в", done: false),
        ])
        XCTAssertEqual(route.visitedCount, 2)
        XCTAssertTrue(route.isInProgress)
        XCTAssertFalse(route.isComplete)
    }

    func testСреднейОценкиНетПокаНиктоНеОценил() {
        let route = Route(title: "Тест", points: [])
        // Ноль и «никто не оценивал» — разные вещи: нулём маршрут
        // оказался бы внизу любого списка, хотя его просто не смотрели.
        XCTAssertNil(route.averageRating)
    }
}

/// Копия карты.
///
/// Это единственная на сегодня страховка от потери телефона, и проверять
/// её надо не руками: ошибка здесь обнаружится ровно в тот момент, когда
/// человек попробует восстановиться, то есть когда всё уже потеряно.
final class BackupTests: XCTestCase {

    func testКопияВозвращаетсяТойЖе() throws {
        var log = TravelLog()
        log.set(.visited, for: "ITA")
        log.set(.wishlist, for: "JPN")
        log.setHome(HomePlace(countryID: "POL",
                              coordinate: Coordinate(longitude: 21.0, latitude: 52.2),
                              cityName: "Варшава"))

        let route = Route(title: "Италия", points: [])
        guard let url = Backup.write(log: log, routes: [route]) else {
            return XCTFail("копия не записалась")
        }
        defer { try? FileManager.default.removeItem(at: url) }

        guard let restored = Backup.read(from: url) else {
            return XCTFail("копия не прочиталась")
        }
        XCTAssertEqual(restored.log.status(for: "ITA"), .visited)
        XCTAssertEqual(restored.log.status(for: "JPN"), .wishlist)
        XCTAssertEqual(restored.log.home?.cityName, "Варшава")
        XCTAssertEqual(restored.routes.map(\.title), ["Италия"])
    }

    func testЧужойФайлНеПринимается() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-mapa.json")
        try Data(#"{"hello":"world"}"#.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(Backup.read(from: url), "чужой json не должен притворяться копией")
    }

    func testКопияИзБудущегоНеОткрывается() throws {
        // Файл, записанный более новой версией приложения, читать нельзя:
        // молча потерять половину полей хуже, чем честно отказаться.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("future.json")
        let json = """
        {"version":99,"exportedAt":"2030-01-01T00:00:00Z",
         "log":{"statuses":{}},"routes":[]}
        """
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(Backup.read(from: url))
    }
}
