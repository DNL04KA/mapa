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

    func testНаходитСтрануПоНачалуНазвания() async throws {
        let found = try await index().search("итал")
        XCTAssertTrue(titles(found).contains("Италия"), "нашлось: \(titles(found).prefix(5))")
    }

    func testНаходитГородПоНачалуНазвания() async throws {
        let found = try await index().search("праг")
        XCTAssertTrue(titles(found).contains("Прага"), "нашлось: \(titles(found).prefix(5))")
    }

    func testНаходитПоАнглийскомуНазванию() async throws {
        // Человек помнит город так, как помнит: «Cologne», «Köln», «Кёльн».
        let found = try await index().search("rome")
        XCTAssertTrue(titles(found).contains("Рим"), "нашлось: \(titles(found).prefix(5))")
    }

    func testЁИЕРавнозначны() async throws {
        let found = try await index().search("кельн")
        XCTAssertTrue(titles(found).contains("Кёльн"), "нашлось: \(titles(found).prefix(5))")
    }

    func testДиакритикаНеМешает() async throws {
        let found = try await index().search("malaga")
        XCTAssertTrue(titles(found).contains("Малага"), "нашлось: \(titles(found).prefix(5))")
    }

    func testСовпадениеСНачалаВышеСовпаденияВнутри() async throws {
        let found = try await index().search("вен")
        guard let first = found.first else { return XCTFail("пусто") }
        // «Венгрия» и «Вена» начинаются с запроса, «Словения» содержит его
        // внутри — и должна быть ниже, какой бы большой ни была.
        XCTAssertTrue(first.title.lowercased().hasPrefix("вен"),
                      "первым оказалось «\(first.title)»")
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
}
