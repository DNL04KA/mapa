import XCTest
@testable import MAPA

/// Правка поездки: имя, заметка, бюджет остановки.
///
/// Всё это поля, которые раньше либо отсутствовали, либо лежали в модели
/// без единого экрана. Проверяем не наличие, а то, ради чего они заведены:
/// что правка доживает до следующего запуска.
@MainActor
final class RouteEditingTests: XCTestCase {

    private func point(_ name: String, budget: Int = 0) -> RoutePoint {
        RoutePoint(name: name,
                   coordinate: Coordinate(longitude: 0, latitude: 0),
                   budget: budget)
    }

    private func model(with routes: [Route]) async -> (WorldMapViewModel, SpyRoutes) {
        let storage = SpyRoutes(initial: routes)
        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(), routeStorage: storage)
        await model.load()
        return (model, storage)
    }

    func testИмяПравитсяИСохраняется() async throws {
        let route = Route(title: "Япония", points: [point("Токио"), point("Киото")])
        let (model, storage) = await model(with: [route])
        model.openRoute(route, reduceMotion: true)

        model.renameRoute("Зимняя Япония")
        await model.flushPendingSaves()

        XCTAssertEqual(model.editingRoute?.title, "Зимняя Япония")
        XCTAssertEqual(storage.saved.last?.first?.title, "Зимняя Япония")
    }

    func testПустоеИмяВозвращаетРасчётное() async throws {
        let route = Route(title: "Япония", points: [point("Токио"), point("Киото")])
        let (model, _) = await model(with: [route])
        model.openRoute(route, reduceMotion: true)

        model.renameRoute("   ")

        XCTAssertEqual(model.editingRoute?.title, "")
        XCTAssertEqual(model.editingRoute?.displayTitle, "Токио → Киото",
                       "пустое имя — это не пустая строка в списке")
    }

    func testЗаметкаОПоездкеСохраняется() async throws {
        let route = Route(title: "Япония", points: [point("Токио"), point("Киото")])
        let (model, storage) = await model(with: [route])
        model.openRoute(route, reduceMotion: true)

        model.setRouteNote("Купить JR Pass заранее")
        await model.flushPendingSaves()

        XCTAssertEqual(storage.saved.last?.first?.note, "Купить JR Pass заранее")
    }

    func testПравкаОстановкиУходитНаДискСразу() async throws {
        let route = Route(title: "Япония", points: [point("Токио"), point("Киото")])
        let (model, storage) = await model(with: [route])
        model.openRoute(route, reduceMotion: true)

        guard var first = model.editingRoute?.points.first else {
            return XCTFail("нет точки")
        }
        first.budget = 1200
        first.note = "Отель у вокзала"
        first.days = 4
        model.update(first)
        await model.flushPendingSaves()

        let stored = try XCTUnwrap(storage.saved.last?.first?.points.first)
        XCTAssertEqual(stored.budget, 1200)
        XCTAssertEqual(stored.note, "Отель у вокзала")
        XCTAssertEqual(stored.days, 4)
    }

    func testБюджетПоездкиСкладываетсяИзОстановок() {
        let route = Route(title: "Япония",
                          points: [point("Токио", budget: 1200), point("Киото", budget: 800)])
        XCTAssertEqual(route.totalBudget, 2000)

        // Ноль и «не задано» — одно и то же: пока нигде не проставлено,
        // показывать в итогах нечего.
        let empty = Route(title: "Япония", points: [point("Токио"), point("Киото")])
        XCTAssertEqual(empty.totalBudget, 0)
    }

    func testЗаметкаПереживаетЗаписьИЧтение() throws {
        let route = Route(title: "Япония", points: [point("Токио")], note: "Взять зонт")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let back = try decoder.decode(Route.self, from: try encoder.encode(route))
        XCTAssertEqual(back.note, "Взять зонт")
    }

    func testСтарыйФайлБезЗаметкиЧитаетсяПустым() throws {
        let json = """
        {"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","title":"Италия",
         "createdAt":"2026-01-10T10:00:00Z","reviews":[],"points":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let route = try decoder.decode(Route.self, from: Data(json.utf8))

        XCTAssertEqual(route.note, "", "чего не было — пусто, а не придумано")
    }
}

private final class SpyRoutes: RouteStorage {
    private let initial: [Route]
    private(set) var saved: [[Route]] = []

    init(initial: [Route]) { self.initial = initial }

    func load() async throws -> [Route] { initial }
    func save(_ routes: [Route]) async throws { saved.append(routes) }
}
