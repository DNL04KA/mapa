import SwiftUI
import XCTest
@testable import MAPA

/// Проекция и камера.
///
/// Это самая незаметная часть приложения: если проекция поедет на тысячную
/// долю, карта не сломается — она просто начнёт врать, и заметит это человек,
/// ткнувший в Швейцарию и попавший в Австрию.
final class GeometryTests: XCTestCase {

    func testОбратнаяПроекцияВозвращаетИсходныеКоординаты() {
        for (lon, lat) in [(0.0, 0.0), (37.6, 55.75), (-74.0, 40.7), (151.2, -33.9), (12.5, 41.9)] {
            let unit = MapProjection.unitPoint(longitude: lon, latitude: lat)
            let back = MapProjection.coordinate(from: unit)
            XCTAssertEqual(back.longitude, lon, accuracy: 0.0001, "долгота \(lon)")
            XCTAssertEqual(back.latitude, lat, accuracy: 0.0001, "широта \(lat)")
        }
    }

    func testПроекцияНеВыходитЗаЕдиничныйКвадрат() {
        // Полюса в проекции Меркатора уходят в бесконечность, поэтому
        // широта подрезана. Проверяем, что подрезка честно держит границы:
        // однажды северный полюс дал −1.1e-16 и страна уехала за край.
        for lat in [90.0, 85.05112878, -90.0, -85.05112878] {
            for lon in [-180.0, 0.0, 180.0] {
                let p = MapProjection.unitPoint(longitude: lon, latitude: lat)
                XCTAssertGreaterThanOrEqual(p.x, 0)
                XCTAssertLessThanOrEqual(p.x, 1)
                XCTAssertGreaterThanOrEqual(p.y, 0)
                XCTAssertLessThanOrEqual(p.y, 1)
            }
        }
    }

    func testКамераНеПоказываетМеньшеЭкрана() {
        let viewport = CGSize(width: 393, height: 852)
        let camera = MapCamera(zoom: 0.1, center: CGPoint(x: 0.5, y: 0.5)).clamped(in: viewport)
        // Мир обязан закрывать экран по высоте: иначе сверху и снизу
        // появляются полосы пустоты, и карта перестаёт быть картой.
        XCTAssertGreaterThanOrEqual(camera.worldSide(in: viewport), viewport.height - 0.5)
    }

    func testКадрированиеВмещаетЗаданнуюОбласть() {
        let viewport = CGSize(width: 393, height: 852)
        let box = CGRect(x: 0.45, y: 0.3, width: 0.1, height: 0.08)
        let camera = MapCamera().fitting(box, in: viewport, padding: 0.2).clamped(in: viewport)

        let topLeft = camera.screenPoint(unit: CGPoint(x: box.minX, y: box.minY), in: viewport)
        let bottomRight = camera.screenPoint(unit: CGPoint(x: box.maxX, y: box.maxY), in: viewport)

        XCTAssertGreaterThanOrEqual(topLeft.x, -1)
        XCTAssertLessThanOrEqual(bottomRight.x, viewport.width + 1)
    }

    func testЭкранныеКоординатыИЕдиничныеСогласованы() {
        // Тот самый инвариант, на котором держится попадание пальцем:
        // чем рисуем, тем и меряем.
        let viewport = CGSize(width: 393, height: 852)
        let camera = MapCamera(zoom: 3, center: CGPoint(x: 0.52, y: 0.33))
        let unit = CGPoint(x: 0.5, y: 0.35)

        let screen = camera.screenPoint(unit: unit, in: viewport)
        let back = camera.unitPoint(screen: screen, in: viewport)

        XCTAssertEqual(back.x, unit.x, accuracy: 0.0001)
        XCTAssertEqual(back.y, unit.y, accuracy: 0.0001)
    }

    // MARK: - Попадание по мелким странам

    /// Две страны: большая и вложенная в неё крошечная — как Ватикан в Риме.
    private func nested() -> WorldGeometry {
        func square(_ box: CGRect) -> Path { Path(box) }
        let big = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let tiny = CGRect(x: 0.49, y: 0.49, width: 0.002, height: 0.002)
        return WorldGeometry(countries: [
            Country(id: "BIG", name: "Big", nameRU: "Большая", continent: .europe,
                    areaKm2: 500_000, flagHue: nil, path: square(big), bounds: big,
                    mainBounds: big, anchor: CGPoint(x: 0.5, y: 0.5), pointCount: 4),
            Country(id: "TNY", name: "Tiny", nameRU: "Крошечная", continent: .europe,
                    areaKm2: 2, flagHue: nil, path: square(tiny), bounds: tiny,
                    mainBounds: tiny, anchor: CGPoint(x: 0.491, y: 0.491), pointCount: 4)
        ])
    }

    func testВложеннаяСтранаВыигрываетУБольшой() {
        // Точка внутри обеих. Раньше побеждала та, что встретилась первой,
        // и во Ватикан нельзя было попасть никогда.
        let hit = nested().country(at: CGPoint(x: 0.4905, y: 0.4905), tolerance: 0)
        XCTAssertEqual(hit?.id, "TNY")
    }

    func testМелкойСтранеДаютПлощадкуСПалец() {
        // Зум, на котором крошечная страна — семь точек экрана: мимо неё
        // легко промахнуться, и промах рядом должен достаться ей.
        let tolerance: CGFloat = 0.002 / 7 * 20
        let hit = nested().country(at: CGPoint(x: 0.4925, y: 0.491), tolerance: tolerance)
        XCTAssertEqual(hit?.id, "TNY")
    }

    func testНаКартеМираМелкаяСтранаНеКрадётТап() {
        // Тот же промах, но на карте мира: крошечная страна там меньше
        // точки, и отдавать ей половину большой страны нельзя.
        let hit = nested().country(at: CGPoint(x: 0.45, y: 0.45), tolerance: 0.05)
        XCTAssertEqual(hit?.id, "BIG")
    }
}
