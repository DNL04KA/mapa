import XCTest
@testable import MAPA

/// Сообщество: разбор ответов сервера и состояния экрана.
///
/// Сервера у нас пока нет, и это ровно та часть, которую нельзя оставить
/// непроверенной: когда ключи появятся, ошибка в разборе ответа покажет
/// пустой топ вместо списка, и выяснится это у людей. Поэтому ответы
/// берутся в той же форме, в какой их отдаёт представление
/// `popular_routes` из supabase/schema.sql.
@MainActor
final class CommunityTests: XCTestCase {

    private let routesJSON = """
    [{"id":"r1","author_id":"a1","title":"Италия за две недели","country_id":"ITA",
      "reviews_count":42,"saves_count":17,"rating":4.60,"score":4.520},
     {"id":"r2","author_id":"a2","title":"Япония весной","country_id":"JPN",
      "reviews_count":1,"saves_count":0,"rating":5.00,"score":4.100},
     {"id":"r3","author_id":"a1","title":"Перу","country_id":"PER",
      "reviews_count":0,"saves_count":3,"rating":null,"score":4.000}]
    """

    private let authorsJSON = """
    [{"id":"a1","handle":"nikita","name":"Никита","bio":"Сорок стран","avatar_path":null,
      "routes_count":2,"reviews_count":42,"saves_count":20,"score":4.260},
     {"id":"a2","handle":"sato","name":"Сато","bio":null,"avatar_path":null,
      "routes_count":1,"reviews_count":1,"saves_count":0,"score":4.100}]
    """

    func testОтветСервераРазбирается() throws {
        let routes = try JSONDecoder().decode([PublicRoute].self, from: Data(routesJSON.utf8))
        XCTAssertEqual(routes.count, 3)
        XCTAssertEqual(routes[0].title, "Италия за две недели")
        XCTAssertEqual(routes[0].authorID, "a1")
        XCTAssertEqual(routes[0].reviewsCount, 42)
        XCTAssertEqual(routes[0].rating ?? 0, 4.6, accuracy: 0.001)

        // Маршрут без отзывов приходит с пустой оценкой, а не с нулём:
        // ноль звёзд и «никто не оценил» — разные вещи.
        XCTAssertNil(routes[2].rating)
    }

    func testОдинОтзывНеПоднимаетВышеСорокаДвух() throws {
        // Смысл сглаженной оценки: пятёрка от одного человека не обгоняет
        // 4,6 от сорока двух. Считает это сервер, но если он однажды
        // начнёт считать иначе, топ перестанет быть топом — и это
        // должно быть видно здесь.
        let routes = try JSONDecoder().decode([PublicRoute].self, from: Data(routesJSON.utf8))
        let byScore = routes.sorted { $0.score > $1.score }

        XCTAssertEqual(byScore.first?.id, "r1")
        XCTAssertGreaterThan(routes[1].rating ?? 0, routes[0].rating ?? 0)
        XCTAssertLessThan(routes[1].score, routes[0].score)
    }

    func testАвторыРазбираютсяИСортируются() throws {
        let authors = try JSONDecoder().decode([PublicAuthor].self, from: Data(authorsJSON.utf8))
        XCTAssertEqual(authors.count, 2)
        XCTAssertEqual(authors[0].handle, "nikita")
        XCTAssertEqual(authors[0].routesCount, 2)
        XCTAssertNil(authors[1].bio, "пустое «о себе» остаётся пустым")
        XCTAssertEqual(authors.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.first?.id, "a1")
    }

    func testБезСервераЭтоНеПустотаИНеОшибка() async {
        // Три разных состояния, и путать их нельзя: «сервер не подключён»
        // объясняется словами, «ничего не нашлось» — это пустой список,
        // а ошибка сети — повод попробовать ещё раз.
        let store = CommunityStore(source: MissingCommunity())
        await store.load()

        XCTAssertEqual(store.routes, .notConfigured)
        XCTAssertEqual(store.authors, .notConfigured)
    }

    func testОтветСервераДоезжаетДоЭкрана() async throws {
        let store = CommunityStore(source: FakeCommunity(
            routes: try JSONDecoder().decode([PublicRoute].self, from: Data(routesJSON.utf8)),
            authors: try JSONDecoder().decode([PublicAuthor].self, from: Data(authorsJSON.utf8))))
        await store.load()

        guard case let .loaded(routes) = store.routes else { return XCTFail("маршруты не дошли") }
        guard case let .loaded(authors) = store.authors else { return XCTFail("авторы не дошли") }
        XCTAssertEqual(routes.count, 3)
        XCTAssertEqual(authors.count, 2)

        guard case let .loaded(mine) = await store.routes(by: authors[0]) else {
            return XCTFail("маршруты автора не дошли")
        }
        XCTAssertEqual(mine.map(\.id), ["r1", "r3"], "на странице человека только его маршруты")
    }

    func testСетеваяОшибкаОстаётсяОшибкой() async {
        let store = CommunityStore(source: BrokenCommunity())
        await store.load()
        XCTAssertEqual(store.routes, .failed("Сервер ответил 500"))
    }
}

/// Источник с заранее известным ответом — вместо сервера.
private struct FakeCommunity: CommunitySource {
    let routes: [PublicRoute]
    let authors: [PublicAuthor]

    func topRoutes(limit: Int) async throws -> [PublicRoute] { routes }
    func topAuthors(limit: Int) async throws -> [PublicAuthor] { authors }
    func author(id: String) async throws -> PublicAuthor {
        guard let found = authors.first(where: { $0.id == id }) else {
            throw CommunityError.network("нет такого")
        }
        return found
    }
    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute] {
        routes.filter { $0.authorID == authorID }
    }
}

private struct BrokenCommunity: CommunitySource {
    private var failure: CommunityError { .network("Сервер ответил 500") }
    func topRoutes(limit: Int) async throws -> [PublicRoute] { throw failure }
    func topAuthors(limit: Int) async throws -> [PublicAuthor] { throw failure }
    func author(id: String) async throws -> PublicAuthor { throw failure }
    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute] { throw failure }
}
