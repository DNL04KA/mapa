import Foundation

/// Отметки пользователя на карте.
///
/// Пока это значение в памяти — при перезапуске отметки теряются, и так и задумано:
/// на 4-м этапе внутренности заменит SwiftData, а вызывающий код не изменится.
/// Поэтому здесь нет ни одного упоминания хранилища.
struct TravelLog: Equatable, Codable {

    private(set) var statuses: [String: TravelStatus]
    /// Точка отсчёта. Одна на всю карту.
    private(set) var home: HomePlace?
    /// Города, отмеченные вручную.
    ///
    /// Города из пройденных точек маршрута сюда не попадают: там отметка
    /// уже есть — сама пройденная точка. Держать её в двух местах значит
    /// однажды их рассогласовать; union считается при показе.
    private(set) var visitedCities: Set<String>
    /// Места, которые человек отметил увиденными.
    ///
    /// Хранится снимок, а не ссылка на каталог: каталог пересобирается
    /// скриптами из Викиданных, названия в нём меняются, и прошлое
    /// человека не должно меняться вместе с ними.
    private(set) var visitedPlaces: [String: VisitedPlace]

    init(statuses: [String: TravelStatus] = [:],
         home: HomePlace? = nil,
         visitedCities: Set<String> = [],
         visitedPlaces: [String: VisitedPlace] = [:]) {
        self.statuses = statuses
        self.home = home
        self.visitedCities = visitedCities
        self.visitedPlaces = visitedPlaces
    }

    // MARK: - Города и места

    mutating func setCityVisited(_ visited: Bool, cityID: String) {
        if visited {
            visitedCities.insert(cityID)
        } else {
            visitedCities.remove(cityID)
        }
    }

    func isCityVisited(_ cityID: String) -> Bool {
        visitedCities.contains(cityID)
    }

    mutating func setPlaceVisited(_ visited: Bool, place: VisitedPlace) {
        if visited {
            visitedPlaces[place.key] = place
        } else {
            visitedPlaces.removeValue(forKey: place.key)
        }
    }

    func isPlaceVisited(_ key: String) -> Bool {
        visitedPlaces[key] != nil
    }

    /// Поставить дом. Страна дома автоматически становится «живу»:
    /// нельзя жить где-то и не отметить это на карте.
    mutating func setHome(_ place: HomePlace?) {
        home = place
        if let place {
            statuses[place.countryID] = .living
        }
    }

    func status(for countryID: String) -> TravelStatus? {
        statuses[countryID]
    }

    /// `nil` снимает отметку.
    mutating func set(_ status: TravelStatus?, for countryID: String) {
        if let status {
            statuses[countryID] = status
        } else {
            statuses.removeValue(forKey: countryID)
        }
    }

    /// Идентификаторы стран с конкретным статусом.
    func countryIDs(with status: TravelStatus) -> [String] {
        statuses.compactMap { $0.value == status ? $0.key : nil }
    }

    var markedCount: Int { statuses.count }

    var isEmpty: Bool { statuses.isEmpty }

    // MARK: - Копия

    /// Статусы кодируются строками, а не числами: если завтра в
    /// перечислении поменяется порядок, старые копии не превратятся в
    /// кашу. Тот же приём, что и в файле журнала, — и по той же причине.
    enum CodingKeys: String, CodingKey {
        case statuses, home, visitedCities, visitedPlaces
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([String: String].self, forKey: .statuses)
        statuses = raw.compactMapValues(TravelStatus.init(rawValue:))
        home = try container.decodeIfPresent(HomePlace.self, forKey: .home)
        // Городов и мест в старых файлах нет, и это не пустая карта, а
        // просто более ранний формат: читается пустым множеством.
        visitedCities = try container.decodeIfPresent(Set<String>.self, forKey: .visitedCities) ?? []
        visitedPlaces = try container.decodeIfPresent([String: VisitedPlace].self,
                                                      forKey: .visitedPlaces) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(statuses.mapValues(\.rawValue), forKey: .statuses)
        try container.encodeIfPresent(home, forKey: .home)
        try container.encode(visitedCities, forKey: .visitedCities)
        try container.encode(visitedPlaces, forKey: .visitedPlaces)
    }
}

/// Место, которое человек видел своими глазами.
///
/// Снимок, а не ссылка: каталог мест собирается скриптами из Викиданных и
/// пересобирается заново, названия в нём меняются, а записи исчезают.
/// Прошлое человека меняться от этого не должно.
struct VisitedPlace: Equatable, Hashable, Codable {

    /// Устойчивый ключ — по координате, а не по названию.
    ///
    /// Идентификатор места в каталоге — это его русское название, и
    /// после пересборки оно может стать другим. Координата у здания не
    /// меняется; округление до трёх знаков — это около ста метров, и
    /// двух разных мест в такой сетке не бывает.
    let key: String
    /// Название на момент отметки.
    let name: String
    let cityID: String?

    init(key: String, name: String, cityID: String?) {
        self.key = key
        self.name = name
        self.cityID = cityID
    }

    init?(landmark: Landmark, cityID: String?) {
        guard let key = VisitedPlace.key(for: landmark) else { return nil }
        self.init(key: key, name: landmark.name, cityID: cityID)
    }

    /// `nil`, если у места нет координат: отмечать то, что нельзя
    /// отличить от соседнего одноимённого, мы не станем.
    static func key(for landmark: Landmark) -> String? {
        guard let lon = landmark.lon, let lat = landmark.lat else { return nil }
        return "\(Int((lat * 1000).rounded()))_\(Int((lon * 1000).rounded()))"
    }
}
