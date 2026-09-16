import SwiftUI

public extension DS {

    /// Глубина. В тёмной теме тень почти не видна, поэтому объём строится
    /// из трёх слоёв: тень вниз + светлая кромка сверху + свечение акцента.
    struct Shadow {
        public let color: SwiftUI.Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public static let none    = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        /// Приподнятый чип, кнопка.
        public static let low     = Shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        /// Карточка.
        public static let medium  = Shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)
        /// Модальный слой, шит.
        public static let high    = Shadow(color: .black.opacity(0.55), radius: 40, x: 0, y: 20)

        /// Цветное свечение — используется под активными статусами.
        public static func glow(_ color: SwiftUI.Color, radius: CGFloat = 24) -> Shadow {
            Shadow(color: color.opacity(0.45), radius: radius, x: 0, y: 8)
        }
    }
}

public extension View {
    func dsShadow(_ shadow: DS.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
