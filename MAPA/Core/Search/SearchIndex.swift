import Foundation

/// Что нашлось.
enum SearchResult: Identifiable, Equatable {
    case country(Country)
    case city(City)

    var id: String {
        switch self {
        case let .country(country): return "c:" + country.id
        case let .city(city):       return "t:" + city.id
        }
    }

    var title: String {
        switch self {
        case let .country(country): return country.displayName
        case let .city(city):       return city.displayName
        }
    }
}

/// Поиск по странам и городам.
///
/// До него до половины приложения было не дойти: 176 стран и 863 города
/// открывались только пальцем по карте, и Люксембург с Сан-Марино человек
/// просто не находил.
///
/// Ищем сразу по русскому и английскому названию, потому что язык
/// приложения и язык, на котором человек помнит город, — разные вещи:
/// «Köln», «Кёльн» и «Cologne» должны приводить в одно место.
struct SearchIndex {

    private struct Entry {
        let result: SearchResult
        /// Варианты написания в нижнем регистре, без диакритики.
        let keys: [String]
        /// Чем крупнее, тем выше при равном совпадении.
        let weight: Double
    }

    private let entries: [Entry]

    init(countries: [Country], cities: [City]) {
        var entries: [Entry] = []

        for country in countries {
            entries.append(Entry(
                result: .country(country),
                keys: Self.keys(country.nameRU, country.name),
                // Страна весомее города: ищут обычно её, а города —
                // уточнение. Площадь переводим в сопоставимый с людьми
                // порядок, иначе Россия забивала бы всё подряд.
                weight: 3_000_000 + country.areaKm2
            ))
        }

        for city in cities {
            entries.append(Entry(
                result: .city(city),
                keys: Self.keys(city.nameRU, city.name),
                weight: Double(city.population) * (city.isCapital ? 2 : 1)
            ))
        }

        self.entries = entries
    }

    func search(_ query: String, limit: Int = 20) -> [SearchResult] {
        let needle = Self.normalize(query)
        guard needle.count >= 2 else { return [] }

        var scored: [(Double, SearchResult)] = []
        for entry in entries {
            guard let rank = Self.rank(entry.keys, needle) else { continue }
            // Совпадение с начала слова важнее размера: кто набрал «вен»,
            // ждёт Венецию и Вену, а не Венесуэлу просто потому, что она больше.
            scored.append((rank * 1_000_000_000 + entry.weight, entry.result))
        }

        return scored
            .sorted { $0.0 > $1.0 }
            .prefix(limit)
            .map(\.1)
    }

    /// Насколько хорошо совпало: 2 — с начала названия, 1 — внутри, иначе никак.
    private static func rank(_ keys: [String], _ needle: String) -> Double? {
        var best: Double?
        for key in keys {
            if key.hasPrefix(needle) {
                return 2
            }
            if key.contains(needle) {
                best = 1
            }
        }
        return best
    }

    private static func keys(_ values: String...) -> [String] {
        values.map(normalize).filter { !$0.isEmpty }
    }

    /// Нижний регистр без диакритики, «ё» приравнена к «е».
    ///
    /// Иначе «Кельн» не находит «Кёльн», а «Malaga» — «Málaga»: человек
    /// набирает так, как ему удобно, а не так, как написано в данных.
    ///
    /// Не приватное: тем же правилом ищет список стран. Два разных
    /// правила поиска в одном приложении — это когда «Кельн» находится в
    /// одном месте и не находится в другом.
    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
