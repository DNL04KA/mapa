import XCTest
@testable import MAPA

/// Поведение маршрутов целиком: собрать, переставить, пройти, закрыть.
///
/// Это характеристические тесты — они записывают то, как приложение ведёт
/// себя сегодня, чтобы перестановка кода не поменяла этого незаметно.
/// Проверяют не «метод вызвался», а правила, которые человек видит:
/// маршрут из одной точки не сохраняется, пройденная точка красит страну,
/// удалённый маршрут исчезает отовсюду.
@MainActor
final class RouteFlowTests: XCTestCase {

    private func model(_ routes: [Route] = []) async -> (WorldMapViewModel, SpyRouteStore) {
        let store = SpyRouteStore(initial: routes)
        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(), routeStorage: store)
        await model.load()
        model.updateViewport(CGSize(width: 393, height: 852))
        return (model, store)
    }

    private func city(_ model: WorldMapViewModel, _ id: String) throws -> City {
        try XCTUnwrap(model.cities.first { $0.id == id }, "нет города \(id)")
    }

    // MARK: - Сборка

    func testМаршрутИзОднойТочкиНеСохраняется() async throws {
        let (model, store) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)

        XCTAssertEqual(model.editingRoute?.points.count, 1)
        model.closeRoute(reduceMotion: true)
        await model.flushPendingSaves()

        XCTAssertTrue(model.routes.isEmpty,
                      "одна точка — это не маршрут, а случайно открытый редактор")
        XCTAssertTrue(store.saved.last?.isEmpty ?? true)
    }

    func testДвеТочкиУжеМаршрутИОнСохраняется() async throws {
        let (model, store) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)
        model.closeRoute(reduceMotion: true)
        await model.flushPendingSaves()

        XCTAssertEqual(model.routes.count, 1)
        XCTAssertEqual(store.saved.last?.first?.points.map(\.name), ["Токио", "Киото"])
    }

    func testПовторноеКасаниеГородаУбираетЕгоИзМаршрута() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        let tokyo = try city(model, "JPN-Tokyo")
        model.add(tokyo, reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)
        model.add(tokyo, reduceMotion: true)

        XCTAssertEqual(model.editingRoute?.points.map(\.name), ["Киото"],
                       "повторный тап — это способ исправить промах")
    }

    func testЛинияНаКартеИдётЗаТочками() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)

        XCTAssertEqual(model.overlay.routeLine.count, 2)
        model.closeRoute(reduceMotion: true)
        XCTAssertTrue(model.overlay.routeLine.isEmpty, "закрытый маршрут не рисуется")
    }

    // MARK: - Правка

    func testТочкиПереставляются() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)
        model.add(try city(model, "JPN-Osaka"), reduceMotion: true)

        let before = model.editingRoute?.points.map(\.name)
        model.movePoint(from: 0, to: 2)
        let after = model.editingRoute?.points.map(\.name)

        XCTAssertEqual(after?.count, before?.count)
        XCTAssertEqual(after?.last, before?.first, "перетащенная точка встала в конец")
    }

    func testУбраннаяТочкаИсчезаетИЗСписка() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)

        guard let first = model.editingRoute?.points.first else { return XCTFail("нет точки") }
        model.removePoint(first)

        XCTAssertEqual(model.editingRoute?.points.map(\.name), ["Киото"])
    }

    // MARK: - Прохождение

    func testПройденнаяТочкаКраситСтрануИГород() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)

        guard let first = model.editingRoute?.points.first else { return XCTFail("нет точки") }
        XCTAssertNil(model.travelLog.status(for: "JPN"))

        model.togglePassed(first, reduceMotion: true)

        XCTAssertEqual(model.travelLog.status(for: "JPN"), .visited,
                       "доехал до города — значит был в стране")
        XCTAssertTrue(model.visitedCityIDs.contains("JPN-Tokyo"))
        XCTAssertEqual(model.statistics.visitedCityCount, 1)
    }

    func testОтметкаСтраныНеСнимаетсяВместеСТочкой() async throws {
        let (model, _) = await model()
        model.startRoute(reduceMotion: true)
        model.add(try city(model, "JPN-Tokyo"), reduceMotion: true)
        model.add(try city(model, "JPN-Kyoto"), reduceMotion: true)

        guard let first = model.editingRoute?.points.first else { return XCTFail("нет точки") }
        model.togglePassed(first, reduceMotion: true)
        guard let passed = model.editingRoute?.points.first else { return XCTFail("нет точки") }
        model.togglePassed(passed, reduceMotion: true)

        // Страна остаётся отмеченной: человек там был, даже если потом
        // передумал считать точку пройденной.
        XCTAssertEqual(model.travelLog.status(for: "JPN"), .visited)
        XCTAssertFalse(model.visitedCityIDs.contains("JPN-Tokyo"))
    }

    // MARK: - Удаление

    func testУдалённыйМаршрутИсчезаетИЗСпискаИСКарты() async throws {
        var point = RoutePoint(cityID: "JPN-Tokyo", name: "Токио", countryID: "JPN",
                               coordinate: Coordinate(longitude: 139.7, latitude: 35.7))
        point.isVisited = true
        let second = RoutePoint(cityID: "JPN-Kyoto", name: "Киото", countryID: "JPN",
                                coordinate: Coordinate(longitude: 135.8, latitude: 35.0))
        let route = Route(title: "Япония", points: [point, second])

        let (model, store) = await model([route])
        model.openRoute(route, reduceMotion: true)
        XCTAssertFalse(model.overlay.routeLine.isEmpty)

        model.deleteRoute(route)
        await model.flushPendingSaves()

        XCTAssertTrue(model.routes.isEmpty)
        XCTAssertNil(model.editingRoute)
        XCTAssertTrue(store.saved.last?.isEmpty ?? false)
    }
}

private final class SpyRouteStore: RouteStorage {
    private let initial: [Route]
    private(set) var saved: [[Route]] = []

    init(initial: [Route]) { self.initial = initial }

    func load() async throws -> [Route] { initial }
    func save(_ routes: [Route]) async throws { saved.append(routes) }
}
