import Foundation

/// Фотография достопримечательности с Викисклада.
///
/// Автор и лицензия едут вместе со снимком не для красоты: фотографии на
/// Викискладе бесплатные при одном условии — назвать того, кто их снял.
/// Поэтому подпись здесь обязательное поле формы, а не украшение.
struct LandmarkPhoto: Decodable, Identifiable, Hashable {
    let name: String
    let small: URL
    let large: URL
    let author: String
    let license: String

    var id: String { name }

    /// «Имя автора · CC BY-SA 4.0» — то, что показываем под фотографией.
    var credit: String? {
        let parts = [author, license].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Каталог фотографий: город → его достопримечательности.
///
/// Собран `Tools/build_landmarks.py`. В приложении лежат только ссылки — сами
/// снимки телефон качает по мере надобности. Триста фотографий в сборке весили
/// бы больше, чем всё остальное приложение вместе взятое.
enum LandmarkPhotos {

    static func photos(for cityNameRU: String) -> [LandmarkPhoto] {
        catalog[cityNameRU] ?? []
    }

    /// Главный снимок города — для маленькой карточки в маршруте.
    static func cover(for cityNameRU: String) -> LandmarkPhoto? {
        catalog[cityNameRU]?.first
    }

    static func photo(for cityNameRU: String, landmark: String) -> LandmarkPhoto? {
        catalog[cityNameRU]?.first { $0.name == landmark }
    }

    private static let catalog: [String: [LandmarkPhoto]] = load()

    private static func load() -> [String: [LandmarkPhoto]] {
        guard let url = Bundle.main.url(forResource: "landmarks", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [LandmarkPhoto]].self, from: data)) ?? [:]
    }
}
