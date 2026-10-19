import Foundation

/// Чужие маршруты и их авторы.
///
/// Всё, что здесь есть, приходит с сервера и ничем не подменяется. Пока
/// сервер не подключён, источник честно отвечает `notConfigured`, а экран
/// говорит об этом словами. Придумать десять правдоподобных авторов с
/// маршрутами было бы легко и было бы враньём: по таким маршрутам нельзя
/// поехать, а по оценкам — нельзя выбрать.

/// Опубликованный маршрут в том виде, в каком его видит чужой человек.
struct PublicRoute: Identifiable, Equatable, Decodable {
    let id: String
    let authorID: String
    let title: String
    let countryID: String?
    /// Средняя оценка. `nil`, пока никто не оценил.
    let rating: Double?
    let reviewsCount: Int
    let savesCount: Int
    /// Сглаженная оценка, по которой строится топ. Считается на сервере:
    /// сортировать по сырой средней значит пускать наверх один отзыв
    /// на пять звёзд.
    let score: Double

    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case title
        case countryID = "country_id"
        case rating
        case reviewsCount = "reviews_count"
        case savesCount = "saves_count"
        case score
    }
}

/// Автор: страница человека, на которую ходят смотреть его маршруты.
struct PublicAuthor: Identifiable, Equatable, Decodable {
    let id: String
    let handle: String
    let name: String
    let bio: String?
    let routesCount: Int
    let reviewsCount: Int
    let savesCount: Int
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case id, handle, name, bio
        case routesCount = "routes_count"
        case reviewsCount = "reviews_count"
        case savesCount = "saves_count"
        case score
    }
}

enum CommunityError: Error, Equatable {
    /// Сервера нет — не ошибка, а состояние приложения.
    case notConfigured
    case network(String)
}

/// Откуда берутся чужие маршруты. Протокол, а не класс, ровно затем, чтобы
/// разбор ответов и порядок в списках можно было проверить тестом, не
/// поднимая сервер.
protocol CommunitySource {
    func topRoutes(limit: Int) async throws -> [PublicRoute]
    func topAuthors(limit: Int) async throws -> [PublicAuthor]
    func author(id: String) async throws -> PublicAuthor
    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute]
}

/// Настоящий источник: PostgREST поверх Supabase.
///
/// Запросы идут в представления `popular_routes` и `popular_authors` —
/// сортировку и сглаживание оценки считает база, а не телефон: иначе
/// «топ» у каждого получался бы свой, из того куска, что он успел
/// загрузить.
struct SupabaseCommunity: CommunitySource {

    let config: BackendConfig
    var session: URLSession = .shared

    func topRoutes(limit: Int) async throws -> [PublicRoute] {
        try await get("popular_routes",
                      query: ["select": "*", "order": "score.desc", "limit": "\(limit)"])
    }

    func topAuthors(limit: Int) async throws -> [PublicAuthor] {
        try await get("popular_authors",
                      query: ["select": "*", "order": "score.desc", "limit": "\(limit)"])
    }

    func author(id: String) async throws -> PublicAuthor {
        let found: [PublicAuthor] = try await get(
            "popular_authors", query: ["select": "*", "id": "eq.\(id)", "limit": "1"])
        guard let author = found.first else {
            throw CommunityError.network("Профиль не найден")
        }
        return author
    }

    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute] {
        try await get("popular_routes",
                      query: ["select": "*", "author_id": "eq.\(authorID)",
                              "order": "score.desc", "limit": "\(limit)"])
    }

    private func get<T: Decodable>(_ table: String, query: [String: String]) async throws -> T {
        var components = URLComponents(
            url: config.url.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw CommunityError.network("Неверный адрес") }

        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + config.anonKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CommunityError.network("Пустой ответ")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw CommunityError.network("Сервер ответил \(http.statusCode)")
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as CommunityError {
            throw error
        } catch {
            throw CommunityError.network(error.localizedDescription)
        }
    }
}

/// Источник, которого нет. Возвращает не пустой список, а причину:
/// «ничего не нашлось» и «сервер не подключён» — разные вещи, и человеку
/// надо показать разное.
struct MissingCommunity: CommunitySource {
    func topRoutes(limit: Int) async throws -> [PublicRoute] { throw CommunityError.notConfigured }
    func topAuthors(limit: Int) async throws -> [PublicAuthor] { throw CommunityError.notConfigured }
    func author(id: String) async throws -> PublicAuthor { throw CommunityError.notConfigured }
    func routes(by authorID: String, limit: Int) async throws -> [PublicRoute] {
        throw CommunityError.notConfigured
    }
}

extension CommunitySource where Self == MissingCommunity {
    /// Источник по текущим настройкам приложения.
    static var current: CommunitySource {
        guard let config = BackendConfig.current else { return MissingCommunity() }
        return SupabaseCommunity(config: config)
    }
}
