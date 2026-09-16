import CoreGraphics
import Foundation

/// Проекция Web Mercator — та же, что у Apple Maps, Google Maps и OSM.
///
/// Почему именно она:
/// • люди привыкли к форме материков именно в Меркаторе, любая другая
///   проекция читается как «карта сломалась»;
/// • мир превращается в квадрат 1×1, а значит камера — это просто
///   масштаб и смещение, без тригонометрии на каждом кадре;
/// • если позже понадобится MapKit-оверлей, системы координат совпадут.
///
/// Расплата — полюса уходят в бесконечность, поэтому широта обрезается
/// на ±85.05113°. Это стандартное значение: именно на нём мир становится квадратом.
public enum MapProjection {

    public static let maxLatitude: Double = 85.05112877980659

    /// Географическая точка → точка в единичном квадрате.
    /// (0,0) — северо-запад, (1,1) — юго-восток.
    public static func unitPoint(longitude: Double, latitude: Double) -> CGPoint {
        let clampedLatitude = min(max(latitude, -maxLatitude), maxLatitude)
        let radians = clampedLatitude * .pi / 180

        let x = (longitude + 180) / 360
        let y = 0.5 - log(tan(.pi / 4 + radians / 2)) / (2 * .pi)

        // Ровно на обрезанной широте arctan даёт погрешность порядка 1e-16,
        // и y уходит в микроскопический минус. Для глаза это ничто, но инвариант
        // «результат всегда внутри единичного квадрата» держит пространственный
        // индекс и попадание по стране от индексов за пределами массива.
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    public static func unitPoint(_ coordinate: Coordinate) -> CGPoint {
        unitPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
    }

    /// Обратное преобразование — понадобится, когда по тапу нужно будет
    /// понять, в какую точку мира ткнул палец.
    public static func coordinate(from unit: CGPoint) -> Coordinate {
        let longitude = Double(unit.x) * 360 - 180
        let y = 0.5 - Double(unit.y)
        let latitude = (2 * atan(exp(y * 2 * .pi)) - .pi / 2) * 180 / .pi
        return Coordinate(longitude: longitude, latitude: latitude)
    }
}
