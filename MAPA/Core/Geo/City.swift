import CoreGraphics
import Foundation

/// Город на карте.
public struct City: Identifiable, Equatable {

    public let id: String
    public let name: String
    public let nameRU: String
    public let countryID: String
    public let coordinate: Coordinate
    public let isCapital: Bool
    public let population: Int

    /// Положение в единичном пространстве — считается один раз при загрузке.
    public let unitPoint: CGPoint

    /// Насколько город важен внутри своей страны.
    /// Столица весит вчетверо: она почти всегда — то, ради чего едут.
    public var importance: Double {
        Double(population) * (isCapital ? 4 : 1)
    }

    /// Расстояние по большой окружности, километры.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6371.0088
        let lat1 = coordinate.latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - coordinate.latitude) * .pi / 180
        let deltaLon = (other.longitude - coordinate.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Разбор городов из бандла.
public enum CityLoader {

    public enum LoaderError: LocalizedError {
        case resourceMissing
        case malformed

        public var errorDescription: String? {
            switch self {
            case .resourceMissing: return String(localized: "В бандле нет файла cities.json")
            case .malformed:       return String(localized: "Файл городов повреждён")
            }
        }
    }

    public static func loadFromBundle() throws -> [City] {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json") else {
            throw LoaderError.resourceMissing
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let raw = root["cities"] as? [[String: Any]]
        else {
            throw LoaderError.malformed
        }

        return raw.compactMap { item in
            guard
                let id = item["id"] as? String,
                let name = item["name"] as? String,
                let countryID = item["country"] as? String,
                let longitude = item["lon"] as? Double,
                let latitude = item["lat"] as? Double
            else { return nil }

            let coordinate = Coordinate(longitude: longitude, latitude: latitude)
            return City(
                id: id,
                name: name,
                nameRU: item["name_ru"] as? String ?? name,
                countryID: countryID,
                coordinate: coordinate,
                isCapital: (item["capital"] as? Bool) ?? false,
                population: (item["population"] as? Int) ?? 0,
                unitPoint: MapProjection.unitPoint(coordinate)
            )
        }
    }
}
