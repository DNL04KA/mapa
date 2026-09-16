import SwiftUI

public extension DS {

    /// Цвета отмеченных стран.
    ///
    /// Тон берётся от флага страны, а насыщенность и светлота — от статуса.
    /// Германия золотая, Италия зелёная, Франция синяя — но все «был»
    /// одинаково яркие, а все «хочу» одинаково приглушённые. Статус
    /// дополнительно подтверждается цветом свечения: оно своё у каждого
    /// статуса и от флага не зависит.
    enum StatusColor {

        struct HSB {
            var hue: Double
            var saturation: Double
            var brightness: Double

            var color: SwiftUI.Color {
                SwiftUI.Color(hue: hue, saturation: saturation, brightness: brightness)
            }
        }

        /// Насколько светлой должна получиться страна с этим статусом.
        ///
        /// Задаём именно **воспринимаемую** светлоту, а не «яркость» из HSB.
        /// Синий с яркостью 1.0 глазу заметно темнее жёлтого с той же яркостью —
        /// разница почти десятикратная. Без выравнивания карта распалась бы
        /// на слепящие жёлтые страны и тонущие синие.
        static func targetLuminance(_ status: TravelStatus, onLight: Bool) -> Double {
            // На светлой карте всё наоборот: страна должна быть темнее фона,
            // иначе она сливается с бумагой.
            if onLight {
                switch status {
                case .visited:  return 0.36
                case .living:   return 0.32
                case .wishlist: return 0.62
                }
            }
            switch status {
            case .visited:  return 0.60
            case .living:   return 0.66
            case .wishlist: return 0.34
            }
        }

        static func baseSaturation(_ status: TravelStatus) -> Double {
            switch status {
            case .visited:  return 0.78
            case .living:   return 0.74
            case .wishlist: return 0.62
            }
        }

        /// Запасной тон, если у страны нет цвета флага.
        private static func fallbackHue(_ status: TravelStatus) -> Double {
            switch status {
            case .visited:  return 0.085
            case .living:   return 0.475
            case .wishlist: return 0.755
            }
        }

        /// Светлота чистого тона при полной насыщенности — от 0.07 у синего
        /// до 0.93 у жёлтого. Считается по весам восприятия яркости.
        private static func luminance(ofHue hue: Double) -> Double {
            let sector = hue * 6
            let fraction = sector - sector.rounded(.down)
            let ascending = fraction
            let descending = 1 - fraction

            let rgb: (Double, Double, Double)
            switch Int(sector) % 6 {
            case 0:  rgb = (1, ascending, 0)
            case 1:  rgb = (descending, 1, 0)
            case 2:  rgb = (0, 1, ascending)
            case 3:  rgb = (0, descending, 1)
            case 4:  rgb = (ascending, 0, 1)
            default: rgb = (1, 0, descending)
            }
            return 0.2126 * rgb.0 + 0.7152 * rgb.1 + 0.0722 * rgb.2
        }

        /// Подбирает насыщенность и яркость так, чтобы страна вышла нужной
        /// светлоты независимо от тона флага.
        private static func balanced(
            hue: Double,
            status: TravelStatus,
            lift: Double,
            onLight: Bool
        ) -> HSB {
            let hueLuminance = luminance(ofHue: hue)
            let target = min(0.92, max(0.12, targetLuminance(status, onLight: onLight) + lift))

            // На белом листе страну отделяет от фона чёрный контур, а не
            // собственная тёмность. Значит и выравнивать светлоту можно слабее —
            // цвета остаются чистыми, а не уходят в оливковый и бурый.
            // На светлом чуть добавляем насыщенности, но немного: перебор
            // превращает карту в леденцы, а нам нужны глубокие тона.
            var saturation = min(1, baseSaturation(status) + (onLight ? 0.03 : 0))
            var brightness = 1.0

            let natural = brightness * (1 - saturation * (1 - hueLuminance))
            let strength = onLight ? 0.5 : 0.55
            let corrected = natural + (target - natural) * strength

            if corrected < natural {
                brightness = corrected / max(0.05, 1 - saturation * (1 - hueLuminance))
            } else if hueLuminance < 0.999 {
                saturation = max(0.30, (1 - corrected) / (1 - hueLuminance))
            }

            return HSB(
                hue: hue,
                saturation: min(max(saturation, 0), 1),
                brightness: min(max(brightness, 0), 1)
            )
        }

        /// Две опорные точки градиента для чипов и карточек интерфейса,
        /// где страны нет и тон брать неоткуда.
        static func stops(_ status: TravelStatus) -> (HSB, HSB) {
            let hue = fallbackHue(status)
            return (
                balanced(hue: hue, status: status, lift: 0.06, onLight: false),
                balanced(hue: (hue + 0.04).truncatingRemainder(dividingBy: 1),
                         status: status, lift: -0.14, onLight: false)
            )
        }

        /// Градиент страны: тон от флага, светлота от статуса.
        static func colors(
            _ status: TravelStatus,
            tint: Double = 0,
            flagHue: Double? = nil,
            onLight: Bool = false
        ) -> [SwiftUI.Color] {
            let hue = flagHue ?? fallbackHue(status)
            // Небольшой разброс светлоты: красных и синих флагов много,
            // и соседи с близкими тонами всё равно чуть отличаются.
            let jitter = tint * 0.04
            return [
                balanced(hue: hue, status: status, lift: 0.06 + jitter, onLight: onLight).color,
                balanced(hue: (hue + 0.035).truncatingRemainder(dividingBy: 1),
                         status: status, lift: -0.15 + jitter, onLight: onLight).color
            ]
        }

        /// Цвет для свечения и теней — всегда цвет статуса, а не флага.
        /// Это последний надёжный признак, по которому статус читается издалека.
        static func glow(_ status: TravelStatus) -> SwiftUI.Color {
            HSB(hue: fallbackHue(status), saturation: 0.72, brightness: 1).color
        }

        /// Осветлённый тон для обводки — «трубка» неона.
        static func outline(_ status: TravelStatus, tint: Double = 0, flagHue: Double? = nil) -> SwiftUI.Color {
            HSB(hue: flagHue ?? fallbackHue(status), saturation: 0.22, brightness: 1).color
        }

        // MARK: - Подобранная палитра

        /// Восемь цветов, собранных как палитра, а не набранных из флагов.
        ///
        /// Флаги дают 176 случайных оттенков: горчичная Германия рядом
        /// с лососевой Норвегией и салатовой Бразилией. Каждый цвет по
        /// отдельности нормальный, а вместе это выглядит дёшево — потому что
        /// такую палитру не собирал никто. Здесь наоборот: тона приглушены,
        /// разведены по кругу и держат друг друга.
        private static let curatedPalette: [SwiftUI.Color] = [
            SwiftUI.Color(hex: 0x2E4A6B),   // чернильный синий
            SwiftUI.Color(hex: 0xB05A3D),   // терракота
            SwiftUI.Color(hex: 0x6B8A66),   // шалфей
            SwiftUI.Color(hex: 0xB8913F),   // охра
            SwiftUI.Color(hex: 0x7A4A62),   // слива
            SwiftUI.Color(hex: 0x3B7370),   // морская волна
            SwiftUI.Color(hex: 0x8C4A3F),   // ржавчина
            SwiftUI.Color(hex: 0x55677A)    // грифель
        ]

        /// Дом в подобранной палитре — самый тёмный тон на карте.
        /// Он не входит в восьмёрку: если бы входил, его цвет рано или поздно
        /// достался бы обычной стране, и дом перестал бы быть единственным.
        static let curatedHome = SwiftUI.Color(hex: 0x2B2724)

        /// Цвет страны из подобранной палитры. Выбор устойчив: одна и та же
        /// страна всегда получает свой тон, а соседи почти никогда не совпадают.
        static func curated(for countryID: String) -> SwiftUI.Color {
            var hash: UInt64 = 0x9E3779B97F4A7C15
            for byte in countryID.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x100000001b3
            }
            return curatedPalette[Int(hash % UInt64(curatedPalette.count))]
        }

        /// Устойчивый сдвиг светлоты из идентификатора страны, −1…1.
        ///
        /// Считаем сами, а не через `hashValue`: у Swift он засеивается заново
        /// на каждый запуск, и цвета стран менялись бы при каждом старте.
        static func tint(for countryID: String) -> Double {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in countryID.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x100000001b3
            }
            return Double(hash % 2001) / 1000 - 1
        }
    }
}
