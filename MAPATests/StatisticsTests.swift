import XCTest
@testable import MAPA

/// Счёт на главном экране.
///
/// Процент открытого мира — единственное число, которое человек видит
/// каждый раз. Если оно разойдётся с таблицей по континентам, доверия
/// к приложению не останется, а заметить это на глаз нельзя.
final class StatisticsTests: XCTestCase {

    private func geometry() async throws -> WorldGeometry {
        try await WorldGeometryLoader.loadFromBundle().geometry
    }

    func testПустойЖурналДаётНули() async throws {
        let stats = TravelStatistics.make(log: TravelLog(), geometry: try await geometry())
        XCTAssertEqual(stats.worldPercent, 0, accuracy: 0.0001)
        XCTAssertEqual(stats.exploredCount, 0)
        XCTAssertTrue(stats.isEmpty)
    }

    func testХочуНеСчитаетсяЗаПройденное() async throws {
        let geo = try await geometry()
        guard let country = geo.countries.first(where: { $0.areaKm2 > 100_000 }) else {
            return XCTFail("нет подходящей страны")
        }
        var log = TravelLog()
        log.set(.wishlist, for: country.id)

        let stats = TravelStatistics.make(log: log, geometry: geo)
        // Желание — не факт: процент открытого мира оно двигать не должно.
        XCTAssertEqual(stats.worldPercent, 0, accuracy: 0.0001)
        XCTAssertEqual(stats.wishlistCount, 1)
        XCTAssertEqual(stats.exploredCount, 0)
    }

    func testПроцентСходитсяССуммойПоКонтинентам() async throws {
        let geo = try await geometry()
        var log = TravelLog()
        for country in geo.countries.prefix(40) {
            log.set(.visited, for: country.id)
        }

        let stats = TravelStatistics.make(log: log, geometry: geo)
        let fromContinents = stats.continents.reduce(0.0) { sum, progress in
            sum + progress.exploredArea
        }
        XCTAssertEqual(stats.worldPercent,
                       fromContinents / geo.totalAreaKm2 * 100,
                       accuracy: 0.01)
    }

    func testПроцентНеПревышаетСта() async throws {
        let geo = try await geometry()
        var log = TravelLog()
        for country in geo.countries {
            log.set(.visited, for: country.id)
        }
        let stats = TravelStatistics.make(log: log, geometry: geo)
        XCTAssertLessThanOrEqual(stats.worldPercent, 100.0001)
        XCTAssertGreaterThan(stats.worldPercent, 99)
    }
}
