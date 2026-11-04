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
        // Даты появились последними. Старый маршрут — без дат, и это не
        // «первое января»: выдуманная дата хуже отсутствующей.
        XCTAssertNil(route.startDate)
        XCTAssertTrue(route.schedule().isEmpty)
    }

    func testДатаВыездаПереживаетЗаписьИЧтение() throws {
        let start = Date(timeIntervalSince1970: 1_772_323_200)  // 1 марта 2026
        let route = Route(
            title: "Япония",
            points: [RoutePoint(name: "Токио", coordinate: Coordinate(longitude: 139.7, latitude: 35.7))],
            startDate: start
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(Route.self, from: encoder.encode(route))

        XCTAssertEqual(back.startDate?.timeIntervalSince1970, start.timeIntervalSince1970)
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

    func testДатыОстановокИдутПодрядИБезДыр() {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(identifier: "UTC") else { return XCTFail("нет UTC") }
        calendar.timeZone = utc

        func point(_ name: String, days: Int) -> RoutePoint {
            RoutePoint(name: name, coordinate: Coordinate(longitude: 0, latitude: 0), days: days)
        }

        // 1 марта 2026, полночь UTC.
        let start = Date(timeIntervalSince1970: 1_772_323_200)
        let route = Route(
            title: "Тест",
            points: [point("а", days: 3), point("б", days: 2), point("в", days: 1)],
            startDate: start
        )

        let schedule = route.schedule(calendar: calendar)
        XCTAssertEqual(schedule.count, 3)

        // Уехал из города — в тот же день приехал в следующий: суток
        // между двумя городами в поездке не бывает.
        XCTAssertEqual(schedule[0].departure, schedule[1].arrival)
        XCTAssertEqual(schedule[1].departure, schedule[2].arrival)

        let day: TimeInterval = 86_400
        XCTAssertEqual(schedule[0].arrival.timeIntervalSince(start), 0)
        XCTAssertEqual(schedule[0].departure.timeIntervalSince(start), 3 * day)
        XCTAssertEqual(schedule[2].departure.timeIntervalSince(start), 6 * day)

        // Возвращение — отъезд из последней точки, и ровно `totalDays`
        // от выезда: если эти два числа разойдутся, человек купит
        // обратный билет не на тот день.
        XCTAssertEqual(route.endDate(calendar: calendar), schedule[2].departure)
        XCTAssertEqual(route.endDate(calendar: calendar)?.timeIntervalSince(start),
                       Double(route.totalDays) * day)
    }

    func testБезДатыВыездаРасписанияНет() {
        let route = Route(title: "Тест", points: [
            RoutePoint(name: "а", coordinate: Coordinate(longitude: 0, latitude: 0)),
        ])
        XCTAssertTrue(route.schedule().isEmpty)
        XCTAssertNil(route.endDate())
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
