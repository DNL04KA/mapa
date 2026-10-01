import CoreGraphics
import Foundation

/// Географическая точка. Порядок полей намеренно «долгота, широта» —
/// такой же, как в GeoJSON, чтобы при парсинге негде было ошибиться.
public struct Coordinate: Hashable, Sendable {
    public var longitude: Double
    public var latitude: Double

    public init(longitude: Double, latitude: Double) {
        self.longitude = longitude
        self.latitude = latitude
    }
}

/// Континенты в том виде, в каком их размечает Natural Earth.
/// Отдельный тип, а не строка: на 4-м этапе по нему считается покрытие.
public enum Continent: String, CaseIterable, Identifiable, Codable, Sendable {
    case africa = "Africa"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case southAmerica = "South America"
    case oceania = "Oceania"
    case antarctica = "Antarctica"

    public var id: String { rawValue }

    // Название на языке приложения живёт в AppLocale.swift.

    /// Континенты, которые считаются «покрываемыми» в статистике.
    /// Антарктида не в счёт: туда попадают единицы, и она бы портила прогресс.
    public static var travelable: [Continent] {
        allCases.filter { $0 != .antarctica }
    }
}
