import Foundation

/// Набросок маршрута по стране.
///
/// Это **не** чей-то настоящий маршрут и не редакционная подборка — выдавать
/// такое за живой опыт было бы обманом. Это механическая сборка из того, что
/// в приложении уже есть: главные города страны, их настоящие
/// достопримечательности и настоящие фотографии с Викисклада. Ценность здесь
/// не в «экспертном совете», а в том, что не надо десять раз тыкать в карту,
/// чтобы получить первую версию поездки, которую потом правишь под себя.
enum CountryRoutePlanner {

    struct Stop: Identifiable, Equatable {
        let city: City
        let days: Int
        let landmarks: [Landmark]
        let photo: Landmark?

        var id: String { city.id }
    }

    /// Сколько точек показываем. Больше пяти — это уже не набросок,
    /// а список городов, который никто не читает.
    static let maxStops = 5

    static func suggest(for cities: [City], limit: Int = maxStops) -> [Stop] {
        let chosen = pick(from: cities, limit: limit)
        guard chosen.count > 1 else { return chosen.map(stop(for:)) }
        return order(chosen).map(stop(for:))
    }

    // MARK: - Кого берём

    /// Сначала города, про которые нам есть что рассказать.
    ///
    /// Город без достопримечательностей в наброске бесполезен: он добавляет
    /// строку и не добавляет причины туда ехать. Поэтому сперва берём все
    /// известные, и только если их не набралось — дотягиваем самыми крупными.
    ///
    /// Из известных выбираем не первые попавшиеся, а те, где смотреть есть
    /// на что: четыре места с фотографиями весомее одного без. Размер
    /// города при равном счёте решает — в большом и помимо списка найдётся
    /// чем заняться, — но решает вторым, а не первым.
    private static func pick(from cities: [City], limit: Int) -> [City] {
        let known = cities
            .filter { !CityFacts.landmarks(for: $0.id).isEmpty }
            .sorted { worth($0) > worth($1) }
        if known.count >= limit { return Array(known.prefix(limit)) }

        let knownIDs = Set(known.map(\.id))
        let rest = cities.filter { !knownIDs.contains($0.id) }
        return known + rest.prefix(limit - known.count)
    }

    /// Чем город ценен для поездки.
    ///
    /// Место с фотографией — целый балл, без фотографии — половина: о нём
    /// мы знаем только название, и в карточке оно выглядит пустой строкой.
    /// Население добавляет доли балла, чтобы при равном счёте впереди
    /// оказался тот город, где и так есть чем заняться.
    private static func worth(_ city: City) -> Double {
        let places = CityFacts.landmarks(for: city.id)
        let score = places.reduce(0.0) { $0 + ($1.small == nil ? 0.5 : 1) }
        return score + min(1, Double(city.population) / 10_000_000)
    }

    // MARK: - В каком порядке

    /// Порядок «от ближайшего к ближайшему», начиная с самого крупного города.
    ///
    /// Не идеальный маршрут — идеальный это задача коммивояжёра, и ради
    /// пяти точек её решать незачем. Но этого достаточно, чтобы не гонять
    /// человека через всю страну и обратно, как получалось бы при сортировке
    /// по населению.
    private static func order(_ cities: [City]) -> [City] {
        guard let start = cities.max(by: { $0.importance < $1.importance }) else { return cities }

        var remaining = cities.filter { $0.id != start.id }
        var result = [start]

        while let current = result.last, !remaining.isEmpty {
            let nearestIndex = remaining.indices.min { lhs, rhs in
                distance(current, remaining[lhs]) < distance(current, remaining[rhs])
            }
            guard let index = nearestIndex else { break }
            result.append(remaining.remove(at: index))
        }
        return result
    }

    private static func distance(_ a: City, _ b: City) -> Double {
        a.distance(to: b.coordinate)
    }

    // MARK: - Сколько дней

    private static func stop(for city: City) -> Stop {
        let landmarks = CityFacts.landmarks(for: city.id)
        return Stop(
            city: city,
            days: days(landmarks: landmarks.count, population: city.population),
            landmarks: landmarks,
            photo: CityFacts.cover(for: city.id)
        )
    }

    /// День на пару мест плюс день на сам город, если он большой.
    /// Грубо, зато честно считается и легко правится ползунком.
    private static func days(landmarks: Int, population: Int) -> Int {
        let fromPlaces = Int(ceil(Double(max(landmarks, 1)) / 2))
        let bonus = population > 2_000_000 ? 1 : 0
        return min(4, max(1, fromPlaces + bonus))
    }

    /// Набросок, превращённый в настоящий маршрут пользователя.
    static func route(title: String, countryID: String, countryName: String, stops: [Stop]) -> Route {
        Route(
            title: title,
            points: stops.map { stop in
                RoutePoint(
                    cityID: stop.city.id,
                    name: stop.city.nameRU,
                    countryID: countryID,
                    countryName: countryName,
                    coordinate: stop.city.coordinate,
                    days: stop.days
                )
            }
        )
    }
}

/// Набросок по конкретной стране — то, что показывает список маршрутов.
struct CountrySuggestion: Identifiable, Equatable {
    let country: Country
    let stops: [CountryRoutePlanner.Stop]

    var id: String { country.id }
    var totalDays: Int { stops.reduce(0) { $0 + $1.days } }
}
