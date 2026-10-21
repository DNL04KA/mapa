import XCTest
@testable import MAPA

/// Список стран для быстрой отметки.
///
/// Проверять его тестом важнее, чем кажется: ошибка здесь не падает и не
/// выглядит сломанной — страна просто «не находится», и человек решает,
/// что в приложении её нет. Ровно та же беда, что и с поиском.
final class CountryPickerTests: XCTestCase {

    private func world() async throws -> [Country] {
        try await WorldGeometryLoader.loadFromBundle().geometry.countries
    }

    func testВесьМирРазложенПоКонтинентам() async throws {
        let world = try await world()
        let sections = CountryPicker.sections(world)

        XCTAssertFalse(sections.isEmpty)
        // Ни одна страна не должна потеряться между секциями: потерянную
        // не отметит никто и никогда.
        let total = sections.reduce(0) { $0 + $1.countries.count }
        XCTAssertEqual(total, world.count)
    }

    func testЕвропаВышеОкеании() async throws {
        let sections = CountryPicker.sections(try await world())
        let names = sections.map(\.continent)

        guard let europe = names.firstIndex(of: .europe),
              let oceania = names.firstIndex(of: .oceania) else {
            return XCTFail("нет Европы или Океании")
        }
        XCTAssertLessThan(europe, oceania, "сверху то, куда ездят чаще")
        XCTAssertEqual(names.last, .antarctica, "Антарктида — последней")
    }

    func testВнутриКонтинентаПоАлфавиту() async throws {
        let sections = CountryPicker.sections(try await world())
        guard let europe = sections.first(where: { $0.continent == .europe }) else {
            return XCTFail("нет Европы")
        }

        let names = europe.countries.map(\.displayName)
        XCTAssertEqual(names, names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func testПоискНаходитНаОбоихЯзыках() async throws {
        let world = try await world()

        for query in ["япон", "japan", "JAPAN"] {
            let found = CountryPicker.sections(world, query: query)
                .flatMap(\.countries)
                .map(\.id)
            XCTAssertTrue(found.contains("JPN"), "по запросу «\(query)» Японии нет")
        }
    }

    func testПоискНеЗамечаетДиакритикуИЁ() async throws {
        let world = try await world()
        // «Кот-д’Ивуар» набирают как придётся; «Берег» — часть названия.
        XCTAssertFalse(CountryPicker.sections(world, query: "cote").isEmpty)
        XCTAssertFalse(CountryPicker.sections(world, query: "корея").isEmpty)
    }

    func testПустойЗапросЭтоВесьМир() async throws {
        let world = try await world()
        let all = CountryPicker.sections(world).flatMap(\.countries).count
        let blank = CountryPicker.sections(world, query: "   ").flatMap(\.countries).count
        XCTAssertEqual(all, blank)
    }

    func testНичегоНеНашлось() async throws {
        let world = try await world()
        XCTAssertTrue(CountryPicker.sections(world, query: "цщьъ").isEmpty)
    }

    func testСчётчикОтмеченногоСчитаетТолькоСвойКонтинент() async throws {
        let world = try await world()
        var log = TravelLog()
        log.set(.visited, for: "FRA")
        log.set(.wishlist, for: "ITA")
        log.set(.visited, for: "JPN")

        let sections = CountryPicker.sections(world)
        guard let europe = sections.first(where: { $0.continent == .europe }),
              let asia = sections.first(where: { $0.continent == .asia }) else {
            return XCTFail("нет секций")
        }

        // «Хочу» тоже отметка: в заголовке стоит, сколько стран континента
        // человек вообще тронул.
        XCTAssertEqual(CountryPicker.marked(europe, in: log), 2)
        XCTAssertEqual(CountryPicker.marked(asia, in: log), 1)
    }
}

/// Отметка из списка доходит до карты.
///
/// Нажать на симуляторе нечем, а путь «строка списка → журнал → процент»
/// — ровно тот, ради которого список и сделан: если он оборвётся, человек
/// будет жать по стране и видеть, что ничего не происходит.
@MainActor
final class MarkFromListTests: XCTestCase {

    private func model() async -> WorldMapViewModel {
        let model = WorldMapViewModel(storage: MemoryLogStorage(), routeStorage: MemoryRouteStorage())
        await model.load()
        return model
    }

    func testОтметкаИзСпискаМеняетЖурналИПроцент() async throws {
        let model = await model()
        guard let france = model.allCountries.first(where: { $0.id == "FRA" }) else {
            return XCTFail("нет Франции")
        }

        XCTAssertEqual(model.statistics.exploredCount, 0)

        model.mark(.visited, for: france)
        XCTAssertEqual(model.travelLog.status(for: "FRA"), .visited)
        XCTAssertEqual(model.statistics.exploredCount, 1)

        // Повторное касание снимает отметку — тем же способом, что и
        // поставило: иначе снять её было бы негде.
        model.mark(nil, for: france)
        XCTAssertNil(model.travelLog.status(for: "FRA"))
        XCTAssertEqual(model.statistics.exploredCount, 0)
    }

    func testХочуНеСчитаетсяЗаПобывал() async throws {
        let model = await model()
        guard let japan = model.allCountries.first(where: { $0.id == "JPN" }) else {
            return XCTFail("нет Японии")
        }

        model.mark(.wishlist, for: japan)
        XCTAssertEqual(model.travelLog.status(for: "JPN"), .wishlist)
        XCTAssertEqual(model.statistics.exploredCount, 0, "«хочу» — это не «был»")
    }

    func testВсеСтраныМираДоступныСписку() async throws {
        let model = await model()
        XCTAssertGreaterThan(model.allCountries.count, 190)
    }
}

/// Хранилища в памяти — чтобы тест не писал в файлы.
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
