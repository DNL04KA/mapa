import Foundation

/// Прогулка по городу: порядок, в котором обходят его места.
///
/// Маршрут по стране отвечает на вопрос «куда ехать», а этот — на вопрос,
/// ради которого в город и приезжают: что посмотреть и в каком порядке,
/// чтобы не пересекать город дважды.
///
/// Это не чей-то проверенный маршрут и не редакционная подборка — выдавать
/// такое за живой опыт было бы обманом. Это настоящие места из Викиданных,
/// расставленные по расстоянию: от центра города к ближайшему, потом к
/// ближайшему из оставшихся. Задачу коммивояжёра ради четырёх точек решать
/// незачем — от перебора порядок почти не меняется, а понятность теряется.
enum CityWalk {

    struct Step: Identifiable, Equatable {
        let place: Landmark
        /// Сколько идти сюда от предыдущей точки. У первой — от центра города.
        let fromPrevious: Double

        var id: String { place.id }
    }

    struct Plan: Equatable {
        let steps: [Step]

        /// Длина всей прогулки в километрах.
        var distance: Double { steps.reduce(0) { $0 + $1.fromPrevious } }
        var isEmpty: Bool { steps.count < 2 }
    }

    /// Порядок обхода мест города.
    ///
    /// Места без координат остаются в конце списка в исходном порядке: они
    /// тоже настоящие, просто мы не знаем, где они, и врать о расстоянии
    /// до них не станем.
    static func plan(for city: City, limit: Int = 6) -> Plan {
        order(Array(CityFacts.landmarks(for: city.id).prefix(limit)), from: city.coordinate)
    }

    /// То же, но от произвольной точки отсчёта: планировщику не нужен весь
    /// город, ему нужны места и место старта.
    static func order(_ places: [Landmark], from start: Coordinate) -> Plan {
        var located = places.filter { $0.coordinate != nil }
        let unlocated = places.filter { $0.coordinate == nil }

        var steps: [Step] = []
        var cursor = start

        while !located.isEmpty {
            let nearest = located.indices.min { lhs, rhs in
                distance(cursor, located[lhs]) < distance(cursor, located[rhs])
            }
            guard let index = nearest else { break }
            let place = located.remove(at: index)
            steps.append(Step(place: place, fromPrevious: distance(cursor, place)))
            cursor = place.coordinate ?? cursor
        }

        steps += unlocated.map { Step(place: $0, fromPrevious: 0) }
        return Plan(steps: steps)
    }

    private static func distance(_ from: Coordinate, _ place: Landmark) -> Double {
        guard let to = place.coordinate else { return .greatestFiniteMagnitude }
        let earthRadius = 6371.0088
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}
