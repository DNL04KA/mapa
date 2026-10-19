import XCTest
@testable import MAPA

/// Порядок обхода мест города.
///
/// Проверка нужна потому, что ошибку здесь видно не сразу: список мест
/// выглядит правдоподобно в любом порядке, и только в городе становится
/// понятно, что тебя гоняют через весь центр и обратно.
final class CityWalkTests: XCTestCase {

    /// Места кодируются тем же JSON, что лежит в бандле: заодно проверяем,
    /// что координаты из файла вообще доезжают до модели.
    private func landmarks(_ json: String) throws -> [Landmark] {
        try JSONDecoder().decode([Landmark].self, from: Data(json.utf8))
    }

    private func start(lon: Double, lat: Double) -> Coordinate {
        Coordinate(longitude: lon, latitude: lat)
    }

    func testИдёмОтБлижайшегоКБлижайшему() throws {
        // Три точки на одной линии к востоку от центра, перемешанные:
        // правильный порядок — 1, 2, 3, а не тот, в котором они пришли.
        let places = try landmarks("""
        [{"ru":"Дальняя","en":"Far","lon":10.30,"lat":50.0},
         {"ru":"Ближняя","en":"Near","lon":10.05,"lat":50.0},
         {"ru":"Средняя","en":"Mid","lon":10.15,"lat":50.0}]
        """)
        let plan = CityWalk.order(places, from: start(lon: 10.0, lat: 50.0))

        XCTAssertEqual(plan.steps.map(\.place.ru), ["Ближняя", "Средняя", "Дальняя"])
        // Длина — сумма шагов, а не расстояние по прямой от центра.
        XCTAssertEqual(plan.distance, plan.steps.reduce(0) { $0 + $1.fromPrevious }, accuracy: 0.001)
        XCTAssertGreaterThan(plan.distance, 20)
    }

    func testМестаБезКоординатНеВрутПроРасстояние() throws {
        let places = try landmarks("""
        [{"ru":"Без координат","en":"Unknown"},
         {"ru":"С координатами","en":"Known","lon":10.05,"lat":50.0}]
        """)
        let plan = CityWalk.order(places, from: start(lon: 10.0, lat: 50.0))

        // Известное идёт первым, неизвестное — в конце и с нулём вместо
        // выдуманного расстояния.
        XCTAssertEqual(plan.steps.map(\.place.ru), ["С координатами", "Без координат"])
        XCTAssertEqual(plan.steps.last?.fromPrevious, 0)
    }

    func testОдноМестоЭтоЕщёНеПрогулка() throws {
        let places = try landmarks("""
        [{"ru":"Одно","en":"One","lon":10.05,"lat":50.0}]
        """)
        XCTAssertTrue(CityWalk.order(places, from: start(lon: 10.0, lat: 50.0)).isEmpty)
    }
}
