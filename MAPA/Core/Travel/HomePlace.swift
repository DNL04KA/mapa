import CoreGraphics
import Foundation

/// Дом — точка, а не страна.
///
/// Разница принципиальна: статус «живу» отвечает на вопрос «в какой стране»,
/// а дом — «откуда ты». От него будут считаться расстояния до других стран,
/// от него начнутся маршруты, и он же подпишет карточку для соцсетей.
struct HomePlace: Equatable, Codable {

    /// Страна, в которой стоит точка, — нужна для подписи.
    var countryID: String
    /// Название города, если дом поставлен из города. Появилось на 6-м этапе,
    /// поэтому необязательное: старые файлы без него читаются как прежде.
    var cityName: String?
    var longitude: Double
    var latitude: Double

    var coordinate: Coordinate {
        Coordinate(longitude: longitude, latitude: latitude)
    }

    var unitPoint: CGPoint {
        MapProjection.unitPoint(longitude: longitude, latitude: latitude)
    }

    init(countryID: String, coordinate: Coordinate, cityName: String? = nil) {
        self.countryID = countryID
        self.cityName = cityName
        self.longitude = coordinate.longitude
        self.latitude = coordinate.latitude
    }
}
