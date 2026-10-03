import Foundation

/// Что посмотреть в стране.
///
/// Собирается `Tools/build_country_facts.py` из Викиданных — тем же способом,
/// что и места городов, и по той же причине: написать списки для ста
/// семидесяти шести стран руками значит где-то вспомнить верно, где-то
/// правдоподобно, и не суметь отличить одно от другого.
///
/// Ключ — код страны. Он не переводится и не меняется.
enum CountryLandmarks {

    static func all(for countryID: String) -> [Landmark] {
        catalog[countryID] ?? []
    }

    static func cover(for countryID: String) -> Landmark? {
        all(for: countryID).first { $0.small != nil }
    }

    private static let catalog: [String: [Landmark]] = load()

    private static func load() -> [String: [Landmark]] {
        guard let url = Bundle.main.url(forResource: "country-facts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [Landmark]].self, from: data)) ?? [:]
    }
}
