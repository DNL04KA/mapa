import XCTest
@testable import MAPA

/// Открытый маршрут должен оказаться в кадре.
///
/// Проверка не про красоту: до неё маршрут открывался там, где человек
/// бросил камеру. Берёшь из списка японский, смотришь на Европу — и
/// решаешь, что маршрут пустой или сломался. Экран при этом не падает,
/// поэтому заметить такое можно только тестом или глазами.
@MainActor
final class RouteFocusTests: XCTestCase {

    private func model() async -> WorldMapViewModel {
        let model = WorldMapViewModel(storage: MemoryLogStorage(), routeStorage: MemoryRouteStorage())
        await model.load()
        model.updateViewport(CGSize(width: 393, height: 852))
        return model
    }

    private func route(country: String, in model: WorldMapViewModel) throws -> Route {
        let cities = model.cities.filter { $0.countryID == country }
        let stops = CountryRoutePlanner.suggest(for: cities)
        try XCTSkipIf(stops.count < 2, "в каталоге нет маршрута по \(country)")
        return CountryRoutePlanner.route(
            title: country,
            countryID: country,
            countryName: country,
            stops: stops
        )
    }

    func testКамераПриходитКМаршруту() async throws {
        let model = await model()
        let japan = try route(country: "JPN", in: model)

        // Камера начинает над отметками, которых нет, — то есть над миром.
        let before = model.camera
        model.openRoute(japan, reduceMotion: true)
        let after = model.camera

        let points = japan.points.map(\.unitPoint)
        guard let first = points.first else { return XCTFail("маршрут без точек") }
        var box = CGRect(origin: first, size: .zero)
        for point in points.dropFirst() { box = box.union(CGRect(origin: point, size: .zero)) }

        XCTAssertGreaterThan(after.zoom, before.zoom, "к маршруту надо подойти ближе, чем к миру")
        XCTAssertEqual(after.center.x, box.midX, accuracy: 0.02)
        XCTAssertEqual(after.center.y, box.midY, accuracy: 0.02)
    }

    /// Все точки маршрута должны попасть в кадр, а не только середина.
    func testМаршрутЦеликомВидноНаЭкране() async throws {
        let model = await model()
        let italy = try route(country: "ITA", in: model)
        model.openRoute(italy, reduceMotion: true)

        let camera = model.camera
        let viewport = CGSize(width: 393, height: 852)
        for point in italy.points.map(\.unitPoint) {
            let screen = camera.screenPoint(unit: point, in: viewport)
            XCTAssertTrue(
                (0...viewport.width).contains(screen.x) && (0...viewport.height).contains(screen.y),
                "точка маршрута за краем экрана: \(screen)"
            )
        }
    }
}

private final class MemoryLogStorage: TravelLogStorage {
    private var stored = TravelLog()
    func load() async throws -> TravelLog { stored }
    func save(_ log: TravelLog) async throws { stored = log }
}

private final class MemoryRouteStorage: RouteStorage {
    private var stored: [Route] = []
    func load() async throws -> [Route] { stored }
    func save(_ routes: [Route]) async throws { stored = routes }
}
