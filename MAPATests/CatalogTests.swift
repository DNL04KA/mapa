import XCTest
@testable import MAPA

/// Целостность справочников.
///
/// Данные собираются скриптами и лежат в бандле. Скрипт может отработать
/// наполовину, ключ — разойтись с идентификатором, ссылка — остаться
/// незаполненной: всё это не падает, а тихо показывает пустоту. Эти проверки
/// ловят такое до того, как увидит человек.
final class CatalogTests: XCTestCase {

    func testГородаЗагружаются() throws {
        let cities = try CityLoader.loadFromBundle()
        XCTAssertGreaterThan(cities.count, 800)
        XCTAssertTrue(cities.allSatisfy { !$0.nameRU.isEmpty })
        XCTAssertTrue(cities.allSatisfy { !$0.name.isEmpty })
    }

    func testУКаждойСтраныРовноОднаСтолица() throws {
        let cities = try CityLoader.loadFromBundle()
        var capitals: [String: Int] = [:]
        for city in cities where city.isCapital {
            capitals[city.countryID, default: 0] += 1
        }
        let countries = Set(cities.map(\.countryID))

        let many = capitals.filter { $0.value > 1 }
        XCTAssertTrue(many.isEmpty, "несколько столиц: \(many.keys.sorted())")

        let none = countries.subtracting(capitals.keys).sorted()
        XCTAssertTrue(none.isEmpty, "страны без столицы: \(none)")
    }

    func testМестаГородовСвязаныССуществующимиГородами() throws {
        let cities = try CityLoader.loadFromBundle()
        let ids = Set(cities.map(\.id))
        var checked = 0

        for city in cities {
            let places = CityFacts.landmarks(for: city.id)
            guard !places.isEmpty else { continue }
            checked += 1
            XCTAssertTrue(ids.contains(city.id))
            XCTAssertTrue(places.allSatisfy { !$0.ru.isEmpty && !$0.en.isEmpty },
                          "пустое название у \(city.nameRU)")
        }
        XCTAssertGreaterThan(checked, 300, "каталог мест почти пуст")
    }

    func testСсылкиНаФотографииБезопасны() throws {
        let cities = try CityLoader.loadFromBundle()
        for city in cities {
            for place in CityFacts.landmarks(for: city.id) {
                guard let url = place.small else { continue }
                // Только https: iOS по умолчанию не пустит http, и картинка
                // молча не загрузится — без единой ошибки в журнале.
                XCTAssertEqual(url.scheme, "https", "\(place.ru): \(url)")
            }
        }
    }

    func testГраницыЗагружаютсяИПлощадиПоложительны() async throws {
        let result = try await WorldGeometryLoader.loadFromBundle()
        XCTAssertGreaterThan(result.geometry.countries.count, 150)
        XCTAssertTrue(result.geometry.countries.allSatisfy { $0.areaKm2 > 0 })
        XCTAssertTrue(result.geometry.countries.allSatisfy { !$0.nameRU.isEmpty })
    }

    func testПереводыЕстьНаОбоихЯзыках() throws {
        // Ключ, которого нет в русской таблице, молча берётся из английской —
        // именно так в русском видео появилось «HOME · ВАРШАВА».
        for language in ["ru", "en"] {
            let path = Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                        inDirectory: nil, forLocalization: language)
            XCTAssertNotNil(path, "нет таблицы для \(language)")
            guard let path else { continue }
            let table = NSDictionary(contentsOfFile: path) as? [String: String]
            XCTAssertNotNil(table, "таблица \(language) не разбирается")
            XCTAssertGreaterThan(table?.count ?? 0, 200)
        }
    }

    func testОстровныеГосударстваНаМесте() async throws {
        // Сингапур, Мальта, Монако и прочие мелкие страны держатся в
        // границах 1:50m: в основном наборе 1:110m их просто нет, и один
        // неверный фильтр молча выкидывает их все разом.
        let world = try await WorldGeometryLoader.loadFromBundle().geometry
        let ids = Set(world.countries.map(\.id))
        let small = ["SGP", "HKG", "MAC", "MDV", "MUS", "SYC", "MLT", "CPV", "BRB",
                     "LCA", "VCT", "ATG", "DMA", "GRD", "CUW", "ABW", "PYF", "WSM",
                     "PLW", "BHR", "MCO", "AND", "VAT", "SMR", "LIE"]
        let missing = small.filter { !ids.contains($0) }
        XCTAssertTrue(missing.isEmpty, "пропали страны: \(missing)")
    }

    func testУКаждойСтраныЕстьЦветФлага() async throws {
        let world = try await WorldGeometryLoader.loadFromBundle().geometry
        // Антарктида без флага — она и не страна; остальные обязаны иметь тон.
        let without = world.countries.filter { $0.flagHue == nil && $0.id != "ATA" }
        XCTAssertTrue(without.isEmpty, "без цвета: \(without.map(\.id).sorted())")
    }

    func testВМонакоМожноПопастьПальцем() async throws {
        // Монако со всех сторон окружено Францией, и в данных Natural Earth
        // французский контур его не вырезает: пока побеждало точное
        // попадание, тап по Монако открывал Францию.
        let world = try await WorldGeometryLoader.loadFromBundle().geometry
        // Зум, на котором Монако шириной около семи точек экрана.
        let close: CGFloat = 20 * (0.061 / 360) / 7
        let monaco = MapProjection.unitPoint(longitude: 7.424, latitude: 43.733)
        XCTAssertEqual(world.country(at: monaco, tolerance: close)?.id, "MCO")

        // И соседи остаются при своих: на карте мира тап по Лиону — Франция,
        // хотя Монако и Андорра лежат в пределах пальца от него.
        let lyon = MapProjection.unitPoint(longitude: 4.83, latitude: 45.76)
        XCTAssertEqual(world.country(at: lyon, tolerance: 20.0 / 393)?.id, "FRA")

        // Сан-Марино внутри Италии — та же история, другой сосед.
        let sanMarino = MapProjection.unitPoint(longitude: 12.458, latitude: 43.936)
        XCTAssertEqual(world.country(at: sanMarino, tolerance: close)?.id, "SMR")
    }

    func testБольшинствуСтранЕстьЧтоПоказать() async throws {
        // Сто пятьдесят восемь стран из двухсот одной — это каждая пятая
        // карточка с пустотой, и так было, пока места искались только
        // вокруг городов. Проверка держит планку: если отбор снова
        // сломается, это будет видно здесь, а не в магазине.
        let world = try await WorldGeometryLoader.loadFromBundle().geometry
        let withPlaces = world.countries.filter { !CountryLandmarks.all(for: $0.id).isEmpty }
        XCTAssertGreaterThanOrEqual(withPlaces.count, 190,
                                    "стран с местами стало меньше: \(withPlaces.count)")
    }

    func testУМестОткудаОниВзялисьЕстьПодпись() throws {
        // Фотографии с Викисклада идут под лицензией, которая требует
        // называть автора. Снимок без подписи показывать нельзя.
        let cities = try CityLoader.loadFromBundle()
        var checked = 0
        for city in cities {
            for place in CityFacts.landmarks(for: city.id) where place.small != nil {
                XCTAssertNotNil(place.credit, "\(place.ru): фотография без подписи")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 500)
    }
}
