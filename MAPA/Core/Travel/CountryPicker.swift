import Foundation

/// Список стран для быстрой отметки.
///
/// Единственный способ закрасить карту был один — тыкать в страны пальцем.
/// Для того, кто был в двадцати, это двадцать охот за мелкими фигурками, а
/// Нидерланды, Черногория и Сингапур пальцем не берутся вовсе. Пустая карта
/// при этом не показывает ничего: ни процента, ни маршрутов, ни карточки
/// для соцсетей. Поэтому список — не «ещё один экран», а то, с чего
/// приложение начинает работать.
///
/// Здесь только отбор и порядок, без единого упоминания вьюх: правила
/// поиска и группировки должны проверяться тестом, а не глазами на
/// симуляторе.
enum CountryPicker {

    /// Континент и его страны.
    struct Section: Identifiable {
        let continent: Continent
        let countries: [Country]

        var id: String { continent.id }
    }

    /// Порядок континентов.
    ///
    /// Не по алфавиту: алфавит на русском и английском разный, и список
    /// бы перетасовывался от смены языка. Сверху то, куда ездят чаще, —
    /// человек находит своё в первом же экране и не листает.
    static let order: [Continent] = [
        .europe, .asia, .northAmerica, .southAmerica, .africa, .oceania, .antarctica
    ]

    /// Страны по континентам. Пустой запрос — весь мир.
    static func sections(_ countries: [Country], query: String = "") -> [Section] {
        let needle = SearchIndex.normalize(query)
        let found = needle.isEmpty ? countries : countries.filter { matches($0, needle) }

        return order.compactMap { continent in
            let inside = found
                .filter { $0.continent == continent }
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            return inside.isEmpty ? nil : Section(continent: continent, countries: inside)
        }
    }

    /// Совпадает ли страна с уже приведённым к общему виду запросом.
    ///
    /// Ищем по обоим названиям сразу: человек набирает «Japan» на русском
    /// телефоне и «Япония» на английском, и оба раза ждёт одну страну.
    static func matches(_ country: Country, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return SearchIndex.normalize(country.nameRU).contains(needle)
            || SearchIndex.normalize(country.name).contains(needle)
    }

    /// Сколько стран континента уже отмечено — число в заголовке секции.
    static func marked(_ section: Section, in log: TravelLog) -> Int {
        section.countries.filter { log.status(for: $0.id) != nil }.count
    }
}
