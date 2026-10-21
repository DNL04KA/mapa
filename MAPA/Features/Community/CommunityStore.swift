import SwiftUI

/// Состояние экрана сообщества.
///
/// Три состояния, а не два: «загружаем», «вот список» и «сервера нет».
/// Последнее — не ошибка и не пустота: показывать по нему «ничего не
/// нашлось» значит врать, будто мы спросили и нам ответили.
@MainActor
final class CommunityStore: ObservableObject {

    enum State<Item: Equatable>: Equatable {
        case loading
        case notConfigured
        case failed(String)
        case loaded([Item])
    }

    @Published private(set) var routes: State<PublicRoute> = .loading

    private let source: CommunitySource

    init(source: CommunitySource = .current) {
        #if DEBUG
        // Показ для снимков экрана: без сервера топ пуст, и увидеть
        // вёрстку заполненной иначе нельзя. Включается только переменной
        // окружения и только в отладочной сборке — в магазин этот путь
        // не попадает, и человек этих строк никогда не увидит.
        if ProcessInfo.processInfo.environment["MAPA_DEMO_COMMUNITY"] == "1" {
            self.source = DemoCommunity()
            return
        }
        #endif
        self.source = source
    }

    var isConfigured: Bool { BackendConfig.isConfigured }

    func load(limit: Int = 20) async {
        routes = await fetch { try await self.source.topRoutes(limit: limit) }
    }

    /// Найти человека по никнейму.
    ///
    /// Возвращает три разных исхода: нашли, такого нет, не смогли
    /// спросить. Путать их нельзя — «@кто-то не найден» и «сеть упала»
    /// требуют от человека разных действий.
    enum Lookup: Equatable {
        case found(PublicAuthor)
        case notFound
        case unavailable(String)
    }

    func find(handle: String) async -> Lookup {
        let cleaned = handle.trimmingCharacters(in: CharacterSet(charactersIn: " @"))
        guard cleaned.count >= 3 else { return .notFound }
        do {
            return .found(try await source.author(handle: cleaned))
        } catch CommunityError.notFound {
            return .notFound
        } catch CommunityError.notConfigured {
            return .unavailable(NSLocalizedString("Сообщество ещё не подключено", comment: ""))
        } catch let CommunityError.network(reason) {
            return .unavailable(reason)
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    /// Маршруты одного человека — для его страницы.
    func routes(by author: PublicAuthor, limit: Int = 20) async -> State<PublicRoute> {
        await fetch { try await self.source.routes(by: author.id, limit: limit) }
    }

    private func fetch<Item: Equatable>(
        _ work: @escaping () async throws -> [Item]
    ) async -> State<Item> {
        do {
            return .loaded(try await work())
        } catch CommunityError.notConfigured {
            return .notConfigured
        } catch let CommunityError.network(reason) {
            return .failed(reason)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

#if DEBUG
/// Данные для снимков экрана. Та же форма, что отдаёт сервер.
private struct DemoCommunity: CommunitySource {

    /// Снимки делаются на двух языках, и русские заголовки в английской
    /// витрине магазина выглядели бы так же, как выглядит чужой язык в
    /// любом списке, — ошибкой вёрстки. Поэтому у показа два набора.
    private static var json: String {
        AppLocale.isRussian ? russianJSON : englishJSON
    }

    private static let russianJSON = """
    [{"id":"r1","author_id":"a1","author_handle":"nikita","author_name":"Никита","title":"Италия за две недели","country_id":"ITA",
      "reviews_count":42,"saves_count":17,"rating":4.60,"score":4.520},
     {"id":"r2","author_id":"a2","author_handle":"sato","author_name":"Сато","title":"Япония весной","country_id":"JPN",
      "reviews_count":28,"saves_count":9,"rating":4.70,"score":4.470},
     {"id":"r3","author_id":"a3","author_handle":"ana","author_name":"Ана","title":"Перу: Лима — Куско — Мачу-Пикчу","country_id":"PER",
      "reviews_count":11,"saves_count":6,"rating":4.80,"score":4.350},
     {"id":"r4","author_id":"a1","author_handle":"nikita","author_name":"Никита","title":"Юг Испании за неделю","country_id":"ESP",
      "reviews_count":7,"saves_count":4,"rating":4.40,"score":4.210}]
    """

    private static let englishJSON = """
    [{"id":"r1","author_id":"a1","author_handle":"nikita","author_name":"Nikita","title":"Italy in two weeks","country_id":"ITA",
      "reviews_count":42,"saves_count":17,"rating":4.60,"score":4.520},
     {"id":"r2","author_id":"a2","author_handle":"sato","author_name":"Sato","title":"Japan in spring","country_id":"JPN",
      "reviews_count":28,"saves_count":9,"rating":4.70,"score":4.470},
     {"id":"r3","author_id":"a3","author_handle":"ana","author_name":"Ana","title":"Peru: Lima — Cusco — Machu Picchu","country_id":"PER",
      "reviews_count":11,"saves_count":6,"rating":4.80,"score":4.350},
     {"id":"r4","author_id":"a1","author_handle":"nikita","author_name":"Nikita","title":"Southern Spain in a week","country_id":"ESP",
      "reviews_count":7,"saves_count":4,"rating":4.40,"score":4.210}]
    """

    private static var authorsJSON: String {
        AppLocale.isRussian ? russianAuthorsJSON : englishAuthorsJSON
    }

    private static let russianAuthorsJSON = """
    [{"id":"a1","handle":"nikita","name":"Никита","bio":"Сорок стран, половина пешком",
      "avatar_path":null,"routes_count":2,"reviews_count":49,"saves_count":21,"score":4.365},
     {"id":"a2","handle":"sato","name":"Сато","bio":null,"avatar_path":null,
      "routes_count":1,"reviews_count":28,"saves_count":9,"score":4.470},
     {"id":"a3","handle":"ana","name":"Ана","bio":"Горы и поезда","avatar_path":null,
      "routes_count":1,"reviews_count":11,"saves_count":6,"score":4.350}]
    """

    private static let englishAuthorsJSON = """
    [{"id":"a1","handle":"nikita","name":"Nikita","bio":"Forty countries, half of them on foot",
      "avatar_path":null,"routes_count":2,"reviews_count":49,"saves_count":21,"score":4.365},
     {"id":"a2","handle":"sato","name":"Sato","bio":null,"avatar_path":null,
      "routes_count":1,"reviews_count":28,"saves_count":9,"score":4.470},
     {"id":"a3","handle":"ana","name":"Ana","bio":"Mountains and trains","avatar_path":null,
      "routes_count":1,"reviews_count":11,"saves_count":6,"score":4.350}]
    """

    private var routes: [PublicRoute] {
        (try? JSONDecoder().decode([PublicRoute].self, from: Data(Self.json.utf8))) ?? []
    }

    private var authors: [PublicAuthor] {
        (try? JSONDecoder().decode([PublicAuthor].self, from: Data(Self.authorsJSON.utf8))) ?? []
    }

    func topRoutes(limit: Int) async throws -> [PublicRoute] {
        routes.sorted { $0.score > $1.score }
    }

    func author(id: String) async throws -> PublicAuthor {
        guard let found = authors.first(where: { $0.id == id }) else {
            throw CommunityError.notFound
        }
        return found
    }

    func author(handle: String) async throws -> PublicAuthor {
        guard let found = authors.first(where: { $0.handle == handle.lowercased() }) else {
            throw CommunityError.notFound
        }
        return found
    }

    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute] {
        routes.filter { $0.authorID == authorID }
    }
}
#endif
