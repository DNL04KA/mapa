import Foundation

/// Достопримечательность города: название на двух языках и фотография.
///
/// Автор и лицензия едут вместе со снимком не для красоты: фотографии на
/// Викискладе бесплатные при одном условии — назвать того, кто их снял.
/// Поэтому подпись здесь обязательное поле формы, а не украшение.
struct Landmark: Decodable, Identifiable, Hashable {

    let ru: String
    let en: String
    let small: URL?
    let large: URL?
    let author: String?
    let license: String?

    var id: String { ru }

    /// Название на языке приложения.
    var name: String { AppLocale.isRussian ? ru : en }

    /// «Имя автора · CC BY-SA 4.0» — то, что показываем под фотографией.
    var credit: String? {
        let parts = [author, license].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Что посмотреть в городе.
///
/// Раньше это был список, написанный руками: восемьдесят городов, которые я
/// мог назвать уверенно. Для восьмисот так нельзя — где-то я вспомнил бы
/// верно, где-то правдоподобно, и отличить одно от другого было бы нечем.
/// Теперь каталог собирается `Tools/build_city_facts.py` из Викиданных, а мера
/// «стоит посмотреть» — число языков, на которых о месте написали.
///
/// Ключ — идентификатор города, а не название: названия переводятся,
/// идентификаторы нет.
enum CityFacts {

    static func landmarks(for cityID: String?) -> [Landmark] {
        guard let cityID else { return [] }
        return catalog[cityID] ?? []
    }

    /// Главный снимок города — для маленькой карточки в маршруте и списках.
    static func cover(for cityID: String?) -> Landmark? {
        landmarks(for: cityID).first { $0.small != nil }
    }

    /// Названия через точку — строка «Колизей · Ватикан · Пантеон».
    static func summary(for cityID: String?, limit: Int = 3) -> String? {
        let names = landmarks(for: cityID).prefix(limit).map(\.name)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    private static let catalog: [String: [Landmark]] = load()

    private static func load() -> [String: [Landmark]] {
        guard let url = Bundle.main.url(forResource: "city-facts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [Landmark]].self, from: data)) ?? [:]
    }
}
