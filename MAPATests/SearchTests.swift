import XCTest
@testable import MAPA

/// Поиск.
///
/// Его проверять тестами особенно важно: ошибка здесь не падает и не
/// выглядит сломанной — просто город «не находится», и человек решает,
/// что его в приложении нет.
final class SearchTests: XCTestCase {

    private func index() async throws -> SearchIndex {
        let geometry = try await WorldGeometryLoader.loadFromBundle().geometry
        let cities = try CityLoader.loadFromBundle()
        return SearchIndex(countries: geometry.countries, cities: cities)
    }

    private func titles(_ results: [SearchResult]) -> [String] {
        results.map(\.title)
    }

    /// Проверяем по идентификаторам, а не по подписям: подпись зависит от
    /// языка телефона, и на английском «Италия» законно показывается как
    /// «Italy» — тест об этом не про то.
    private func ids(_ results: [SearchResult]) -> [String] {
        results.map(\.id)
    }

    /// Название города на том языке, на котором его показывает приложение.
    private func city(_ id: String, in results: [SearchResult]) -> Bool {
        ids(results).contains("t:" + id)
    }

    func testНаходитСтрануПоНачалуНазвания() async throws {
        let found = try await index().search("итал")
        XCTAssertTrue(ids(found).contains("c:ITA"), "нашлось: \(titles(found).prefix(5))")
    }

    func testНаходитГородПоНачалуНазвания() async throws {
        let found = try await index().search("праг")
        XCTAssertTrue(city("CZE-Prague", in: found), "нашлось: \(titles(found).prefix(5))")
    }

    func testНаходитПоАнглийскомуНазванию() async throws {
        // Человек помнит город так, как помнит: «Cologne», «Köln», «Кёльн».
        let found = try await index().search("rome")
        XCTAssertTrue(city("ITA-Rome", in: found), "нашлось: \(titles(found).prefix(5))")
    }

    func testЁИЕРавнозначны() async throws {
        let found = try await index().search("кельн")
        XCTAssertTrue(city("DEU-Cologne", in: found), "нашлось: \(titles(found).prefix(5))")
    }

    func testДиакритикаНеМешает() async throws {
        let found = try await index().search("malaga")
        XCTAssertTrue(city("ESP-Malaga", in: found), "нашлось: \(titles(found).prefix(5))")
    }

    func testСовпадениеСНачалаВышеСовпаденияВнутри() async throws {
        let found = try await index().search("вен")
        guard let first = found.first else { return XCTFail("пусто") }
        // «Венгрия» и «Вена» начинаются с запроса, «Словения» содержит его
        // внутри — и должна быть ниже, какой бы большой ни была. Сверяем с
        // русским названием: подпись на английском телефоне другая, а
        // правило сортировки — то же.
        let russian: String
        switch first {
        case let .country(country): russian = country.nameRU
        case let .city(city):       russian = city.nameRU
        }
        XCTAssertTrue(russian.lowercased().hasPrefix("вен"),
                      "первым оказалось «\(russian)»")
    }

    func testОднойБуквыНедостаточно() async throws {
        let found = try await index().search("и")
        XCTAssertTrue(found.isEmpty)
    }

    func testМелкаяСтранаНаходится() async throws {
        // Ради них всё и затевалось: пальцем по карте в Люксембург не попасть.
        //
        // Монако, Сан-Марино, Андорры, Ватикана, Мальты и Сингапура здесь
        // нет и быть не может: их нет в границах 1:110m — у них попросту
        // нет полигона в этом масштабе. Это известная дыра, не забытый тест.
        for query in ["люксембург", "черногор", "словени"] {
            let found = try await index().search(query)
            XCTAssertFalse(found.isEmpty, "по запросу «\(query)» ничего")
        }
    }

    /// Первый запуск спрашивает город, где человек живёт, и ищет его тем же
    /// индексом. Если столица не находится по собственному названию, шаг
    /// бесполезен — а проверить руками сто девяносто семь столиц нельзя.
    func testКаждаяСтолицаНаходитсяПоСвоемуНазванию() async throws {
        let world = try await WorldGeometryLoader.loadFromBundle().geometry
        let cities = try CityLoader.loadFromBundle()
        let index = SearchIndex(countries: world.countries, cities: cities)

        var lost: [String] = []
        for city in cities where city.isCapital {
            // Три первых: по запросу «Сингапур» страна законно идёт
            // впереди города, а «Виктория» есть и на Сейшелах, и в Канаде.
            let top = index.search(city.nameRU).prefix(3)
            if !top.contains(where: { $0 == .city(city) }) {
                lost.append(city.nameRU)
            }
        }
        XCTAssertTrue(lost.isEmpty, "не находятся: \(lost.sorted())")
    }
}
