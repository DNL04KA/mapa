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
    /// Город, если дом поставлен из города. Хранится идентификатор, а не
    /// только название: подпись под домиком должна читаться на языке
    /// телефона, а название, записанное один раз при выборе, застыло бы
    /// по-русски навсегда.
    var cityID: String?
    /// Название города на момент выбора. Появилось на 6-м этапе, поэтому
    /// необязательное: старые файлы без него читаются как прежде. Остаётся
    /// запасным ответом, если города с таким идентификатором больше нет.
    var cityName: String?
    var longitude: Double
    var latitude: Double

    var coordinate: Coordinate {
        Coordinate(longitude: longitude, latitude: latitude)
    }

    var unitPoint: CGPoint {
        MapProjection.unitPoint(longitude: longitude, latitude: latitude)
    }

    init(countryID: String, coordinate: Coordinate,
         cityID: String? = nil, cityName: String? = nil) {
        self.countryID = countryID
        self.cityID = cityID
        self.cityName = cityName
        self.longitude = coordinate.longitude
        self.latitude = coordinate.latitude
    }
}
