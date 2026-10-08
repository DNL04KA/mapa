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
