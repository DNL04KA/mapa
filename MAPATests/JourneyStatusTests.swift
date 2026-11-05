import XCTest
@testable import MAPA

/// Состояние поездки и переход старых файлов на него.
///
/// Под словом «маршрут» жили три разные вещи: мечта, план и воспоминание.
/// Состояние их наконец различает — и первым делом оно должно правильно
/// достаться тем маршрутам, которые записаны прежней версией и про
/// состояние ничего не знают.
final class JourneyStatusTests: XCTestCase {

    private func point(_ name: String, visited: Bool = false, days: Int = 2) -> RoutePoint {
        RoutePoint(name: name,
                   coordinate: Coordinate(longitude: 0, latitude: 0),
                   days: days,
                   isVisited: visited)
    }

    private func decode(_ json: String) throws -> Route {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Route.self, from: Data(json.utf8))
    }

    private func oldRoute(points: String) -> String {
        """
        {"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","title":"Италия",
         "createdAt":"2026-01-10T10:00:00Z","reviews":[],"points":[\(points)]}
        """
    }

    private func oldPoint(_ name: String, visited: Bool) -> String {
        """
        {"id":"\(UUID().uuidString)","name":"\(name)","longitude":12.5,"latitude":41.9,
         "days":2,"budget":0,"note":"","isVisited":\(visited)}
        """
    }

    // MARK: - Старые файлы

    func testПройденныйМаршрутИзСтарогоФайлаНеСтановитсяЧерновиком() throws {
        let route = try decode(oldRoute(points: [oldPoint("Рим", visited: true),
                                                 oldPoint("Милан", visited: true)].joined(separator: ",")))
        XCTAssertEqual(route.status, .completed,
                       "уже совершённая поездка не должна уехать в наброски")
    }

    func testНачатыйМаршрутИзСтарогоФайлаИдётСейчас() throws {
        let route = try decode(oldRoute(points: [oldPoint("Рим", visited: true),
                                                 oldPoint("Милан", visited: false)].joined(separator: ",")))
        XCTAssertEqual(route.status, .inProgress)
    }

    func testНетронутыйМаршрутИзСтарогоФайлаЧерновик() throws {
        let route = try decode(oldRoute(points: oldPoint("Рим", visited: false)))
        XCTAssertEqual(route.status, .draft)
    }

    func testЗаписанноеСостояниеСильнееВыведенного() throws {
        // Отменённая поездка со всеми пройденными точками остаётся
        // отменённой: человек сказал, вывод тут ни при чём.
        let json = """
        {"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","title":"Италия",
         "createdAt":"2026-01-10T10:00:00Z","reviews":[],"status":"cancelled",
         "points":[\(oldPoint("Рим", visited: true))]}
        """
        XCTAssertEqual(try decode(json).status, .cancelled)
    }

    func testСостояниеПереживаетЗаписьИЧтение() throws {
        let route = Route(title: "Япония", points: [point("Токио")], status: .planned)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let back = try decoder.decode(Route.self, from: try encoder.encode(route))
        XCTAssertEqual(back.status, .planned)
    }

    // MARK: - Подсказка

    func testПодсказкаНичегоНеМеняетСама() {
        let start = Date(timeIntervalSince1970: 1_772_323_200)  // 1 марта 2026
        var route = Route(title: "Япония",
                          points: [point("Токио", days: 3)],
                          startDate: start,
                          status: .planned)

        let duringTrip = start.addingTimeInterval(86_400)
        XCTAssertEqual(route.suggestedStatus(on: duringTrip), .inProgress)
        // Само состояние не изменилось: подсказка — это предложение.
        XCTAssertEqual(route.status, .planned)

        route.status = .inProgress
        let afterTrip = start.addingTimeInterval(10 * 86_400)
        XCTAssertEqual(route.suggestedStatus(on: afterTrip), .completed)
    }

    func testЧерновикСБудущейДатойПредлагаетсяКакПлан() {
        let start = Date().addingTimeInterval(14 * 86_400)
        let route = Route(title: "Япония", points: [point("Токио")],
                          startDate: start, status: .draft)
        XCTAssertEqual(route.suggestedStatus(), .planned)
    }

    func testБезДатНичегоНеПредлагается() {
        let route = Route(title: "Япония", points: [point("Токио")], status: .draft)
        XCTAssertNil(route.suggestedStatus(), "без дня выезда предлагать нечего")
    }

    func testПройденномуИОтменённомуПредлагатьНечего() {
        let start = Date(timeIntervalSince1970: 1_772_323_200)
        for status in [JourneyStatus.completed, .cancelled] {
            let route = Route(title: "Япония", points: [point("Токио")],
                              startDate: start, status: status)
            XCTAssertNil(route.suggestedStatus(on: Date()),
                         "\(status.rawValue): поездка уже позади")
        }
    }

    func testВсеТочкиПройденыЗначитПредлагаемЗавершить() {
        let route = Route(title: "Италия",
                          points: [point("Рим", visited: true), point("Милан", visited: true)],
                          status: .planned)
        XCTAssertEqual(route.suggestedStatus(), .completed,
                       "отметки пройденного — сигнал сильнее календаря")
    }

    func testПерваяПройденнаяТочкаПредлагаетНачатьПоездку() {
        let route = Route(title: "Италия",
                          points: [point("Рим", visited: true), point("Милан")],
                          status: .planned)
        XCTAssertEqual(route.suggestedStatus(), .inProgress)
    }

    func testПорядокВСпискеОтТекущегоКПрошлому() {
        let sorted = JourneyStatus.allCases.sorted { $0.listOrder < $1.listOrder }
        XCTAssertEqual(sorted, [.inProgress, .planned, .draft, .completed, .cancelled])
    }
}
