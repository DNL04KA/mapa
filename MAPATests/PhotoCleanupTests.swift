import UIKit
import XCTest
@testable import MAPA

/// Что происходит со снимками, когда маршрут уходит.
///
/// Файл фотографии живёт отдельно от маршрута, и ссылка на него — одна
/// строка в JSON. Удалили маршрут, строки нет — файл остаётся лежать:
/// показать его некому, удалить тоже некому. На сотне поездок это
/// гигабайты, которых человек не просил.
///
/// Вторая половина проверки важнее первой: уборка не должна срабатывать,
/// когда маршруты просто не прочитались. Пустой список тогда означает не
/// «ни на что не ссылаются», а «мы не знаем» — и разница здесь в том,
/// останутся ли у человека фотографии.
@MainActor
final class PhotoCleanupTests: XCTestCase {

    private var made: [String] = []

    override func tearDown() {
        for id in made { PhotoStore.routes.delete(id: id) }
        made = []
        super.tearDown()
    }

    private func makePhoto() throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let id = try XCTUnwrap(PhotoStore.routes.save(image))
        made.append(id)
        return id
    }

    private func route(photoID: String) -> Route {
        var point = RoutePoint(name: "Токио",
                               coordinate: Coordinate(longitude: 139.7, latitude: 35.7))
        point.photoID = photoID
        var second = RoutePoint(name: "Киото",
                                coordinate: Coordinate(longitude: 135.8, latitude: 35.0))
        second.photoID = nil
        return Route(title: "Япония", points: [point, second])
    }

    func testУдалениеМаршрутаУноситЕгоСнимки() async throws {
        let photoID = try makePhoto()
        let stored = route(photoID: photoID)

        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(),
                                      routeStorage: EphemeralRouteStorage(initial: [stored]))
        await model.load()
        XCTAssertNotNil(PhotoStore.routes.data(id: photoID))

        model.deleteRoute(stored)

        // Удаление уходит в сторону от главного потока, поэтому ждём файл,
        // а не проверяем сразу.
        for _ in 0..<40 where PhotoStore.routes.data(id: photoID) != nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertNil(PhotoStore.routes.data(id: photoID), "снимок удалённого маршрута остался")
    }

    func testПриЗапускеУбираютсяСнимкиБезМаршрута() async throws {
        let kept = try makePhoto()
        let orphan = try makePhoto()

        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(),
                                      routeStorage: EphemeralRouteStorage(initial: [route(photoID: kept)]))
        await model.load()

        XCTAssertNotNil(PhotoStore.routes.data(id: kept), "снимок живого маршрута трогать нельзя")
        XCTAssertNil(PhotoStore.routes.data(id: orphan), "снимок без маршрута должен убраться")
    }

    func testПослеСбояЧтенияСнимкиНеТрогаются() async throws {
        let photoID = try makePhoto()

        let model = WorldMapViewModel(storage: EphemeralTravelLogStorage(),
                                      routeStorage: BrokenRouteStorage())
        await model.load()

        XCTAssertEqual(model.routesFailure, .unreadable)
        XCTAssertNotNil(PhotoStore.routes.data(id: photoID),
                        "пустой список после сбоя — это не «ни на что не ссылаются»")
    }
}

private final class BrokenRouteStorage: RouteStorage {
    func load() async throws -> [Route] { throw StorageFailure.unreadable }
    func save(_ routes: [Route]) async throws {}
}
