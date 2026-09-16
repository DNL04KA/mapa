import SwiftUI

public extension DS {

    /// Градиенты — главный визуальный язык MAPA. Плоских заливок в приложении нет:
    /// у каждой поверхности есть направление света.
    enum Gradient {

        // MARK: Статусы

        /// Заливка страны на карте: насыщенная, но не «кислотная».
        static func status(_ status: TravelStatus) -> LinearGradient {
            LinearGradient(
                colors: statusColors(status),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Мягкий вариант для фонов чипов и карточек.
        static func statusSoft(_ status: TravelStatus, opacity: Double = 0.18) -> LinearGradient {
            LinearGradient(
                colors: statusColors(status).map { $0.opacity(opacity) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Радиальное свечение под страной — даёт ощущение, что заливка «горит».
        static func statusGlow(_ status: TravelStatus) -> RadialGradient {
            RadialGradient(
                colors: [statusColors(status)[0].opacity(0.55), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 120
            )
        }

        static func statusColors(_ status: TravelStatus) -> [SwiftUI.Color] {
            DS.StatusColor.colors(status)
        }

        /// Цвет для теней и свечения вокруг элемента статуса.
        static func statusGlowColor(_ status: TravelStatus) -> SwiftUI.Color {
            DS.StatusColor.glow(status)
        }

        /// Текст поверх заливки статуса.
        static func statusForeground(_ status: TravelStatus) -> SwiftUI.Color {
            DS.Color.inkOnAccent
        }

        // MARK: Поверхности

        /// Фон приложения: сверху чуть светлее, снизу уходит в пустоту.
        static let appBackground = LinearGradient(
            colors: [DS.Palette.abyss, DS.Palette.void],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Заливка карточки: едва заметный переход, читается как объём.
        static let surface = LinearGradient(
            colors: [
                SwiftUI.Color.white.opacity(0.08),
                SwiftUI.Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Обводка «стекла»: светлая сверху, растворяется книзу.
        /// Это функция, а не константа: `ShapeStyle.opacity(_:)` появился только
        /// в iOS 17, поэтому прозрачность закладываем прямо в цвета.
        static func glassBorder(_ strength: Double = 1) -> LinearGradient {
            LinearGradient(
                colors: [
                    SwiftUI.Color.white.opacity(0.30 * strength),
                    SwiftUI.Color.white.opacity(0.06 * strength),
                    SwiftUI.Color.white.opacity(0.12 * strength)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        /// Брендовый акцент для кнопок и активных состояний.
        static let accent = LinearGradient(
            colors: [DS.Palette.indigoSoft, DS.Palette.indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // MARK: Карта

        // Для `Canvas` нужны именно `Gradient` (набор стопов), а не `LinearGradient`:
        // направление задаётся уже на месте отрисовки, в единичном пространстве мира.

        /// Океан внутри квадрата мира: сверху чуть холоднее и светлее.
        static let ocean = SwiftUI.Gradient(colors: [
            SwiftUI.Color(hex: 0x121A2E),
            SwiftUI.Color(hex: 0x0B0F1C)
        ])

        /// Суша без отметок. Светлее океана ровно настолько, чтобы граница
        /// читалась, но материки не «выпрыгивали» из фона.
        static let land = SwiftUI.Gradient(colors: [
            SwiftUI.Color(hex: 0x39426B),
            SwiftUI.Color(hex: 0x232A42)
        ])

        /// Затемнение снизу под текст поверх фото.
        static let scrim = LinearGradient(
            stops: [
                .init(color: .clear,                     location: 0.0),
                .init(color: DS.Palette.void.opacity(0.55), location: 0.55),
                .init(color: DS.Palette.void.opacity(0.95), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
