import CoreGraphics
import Foundation

/// Точка маршрута.
///
/// Координаты хранятся прямо здесь, а не ссылкой на город: маршрут должен
/// пережить любую пересборку городского справочника. Ссылка `cityID` остаётся
/// для будущего — по ней можно будет подтянуть население или фотографии.
struct RoutePoint: Identifiable, Equatable, Codable {

    let id: UUID
    var cityID: String?
    var name: String
    var countryID: String?
    var longitude: Double
    var latitude: Double

    /// Сколько дней здесь провести.
    var days: Int
    /// Бюджет на всю остановку, в евро.
    var budget: Int
    var note: String
    /// Пройдена ли точка. Появилось позже остальных полей, поэтому
    /// необязательное в декодере — старые файлы читаются как «не пройдено».
    var isVisited: Bool

    var coordinate: Coordinate {
        Coordinate(longitude: longitude, latitude: latitude)
    }

    var unitPoint: CGPoint {
        MapProjection.unitPoint(longitude: longitude, latitude: latitude)
    }

    init(
        id: UUID = UUID(),
        cityID: String? = nil,
        name: String,
        countryID: String? = nil,
        coordinate: Coordinate,
        days: Int = 2,
        budget: Int = 0,
        note: String = "",
        isVisited: Bool = false
    ) {
        self.id = id
        self.cityID = cityID
        self.name = name
        self.countryID = countryID
        self.longitude = coordinate.longitude
        self.latitude = coordinate.latitude
        self.days = days
        self.budget = budget
        self.note = note
        self.isVisited = isVisited
    }

    /// Старые файлы точек не знают про `isVisited` — читаем как «не пройдено»,
    /// а не роняем разбор всего маршрута.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cityID = try container.decodeIfPresent(String.self, forKey: .cityID)
        name = try container.decode(String.self, forKey: .name)
        countryID = try container.decodeIfPresent(String.self, forKey: .countryID)
        longitude = try container.decode(Double.self, forKey: .longitude)
        latitude = try container.decode(Double.self, forKey: .latitude)
        days = try container.decode(Int.self, forKey: .days)
        budget = try container.decode(Int.self, forKey: .budget)
        note = try container.decode(String.self, forKey: .note)
        isVisited = try container.decodeIfPresent(Bool.self, forKey: .isVisited) ?? false
    }

    init(city: City) {
        self.init(
            cityID: city.id,
            name: city.nameRU,
            countryID: city.countryID,
            coordinate: city.coordinate
        )
    }
}

/// Отзыв о маршруте.
///
/// Автор хранится строкой, а не ссылкой на пользователя: аккаунтов ещё нет,
/// а когда появятся, строку заменит идентификатор — снаружи ничего не изменится.
struct RouteReview: Identifiable, Equatable, Codable {

    let id: UUID
    var authorName: String
    /// Оценка от одной до пяти.
    var rating: Int
    var text: String
    var createdAt: Date
    /// Твой ли это отзыв. Пока других и не бывает, но поле нужно сразу:
    /// свой отзыв можно править, чужой — нет.
    var isMine: Bool

    init(
        id: UUID = UUID(),
        authorName: String,
        rating: Int,
        text: String = "",
        createdAt: Date = Date(),
        isMine: Bool = false
    ) {
        self.id = id
        self.authorName = authorName
        self.rating = min(max(rating, 1), 5)
        self.text = text
        self.createdAt = createdAt
        self.isMine = isMine
    }
}

/// Маршрут — упорядоченный список точек.
struct Route: Identifiable, Equatable, Codable {

    let id: UUID
    var title: String
    var points: [RoutePoint]
    var createdAt: Date
    var reviews: [RouteReview]

    init(
        id: UUID = UUID(),
        title: String = "",
        points: [RoutePoint] = [],
        createdAt: Date = Date(),
        reviews: [RouteReview] = []
    ) {
        self.id = id
        self.title = title
        self.points = points
        self.createdAt = createdAt
        self.reviews = reviews
    }

    /// Средняя оценка. `nil`, если не оценивал никто — это не то же самое,
    /// что ноль, и показывать такой маршрут нужно иначе.
    var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    var myReview: RouteReview? { reviews.first(where: \.isMine) }

    var totalDays: Int { points.reduce(0) { $0 + $1.days } }

    /// Сколько точек уже пройдено.
    var visitedCount: Int { points.filter(\.isVisited).count }

    /// Маршрут начат, но не закончен.
    var isInProgress: Bool { visitedCount > 0 && visitedCount < points.count }

    var isComplete: Bool { !points.isEmpty && visitedCount == points.count }
    var totalBudget: Int { points.reduce(0) { $0 + $1.budget } }

    /// Длина маршрута по прямым между точками, километры.
    /// Это не километраж дороги — это масштаб замысла.
    var totalDistanceKm: Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { sum, pair in
            sum + Self.distance(pair.0.coordinate, pair.1.coordinate)
        }
    }

    /// Название по умолчанию — из первой и последней точки.
    /// Пустое поле в списке выглядит как ошибка, а «Рим → Париж» читается сразу.
    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        switch points.count {
        case 0: return "Новый маршрут"
        case 1: return points[0].name
        default: return "\(points[0].name) → \(points[points.count - 1].name)"
        }
    }

    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let radius = 6371.0088
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * atan2(sqrt(h), sqrt(1 - h))
    }
}
