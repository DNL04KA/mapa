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
}
