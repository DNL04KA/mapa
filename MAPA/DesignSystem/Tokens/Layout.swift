import SwiftUI

public extension DS {

    /// Шаг сетки — 4pt. Все отступы кратны ему, поэтому интерфейс
    /// «садится» на общий ритм без ручной подгонки.
    enum Space {
        public static let xxs: CGFloat = 4
        public static let xs:  CGFloat = 8
        public static let sm:  CGFloat = 12
        public static let md:  CGFloat = 16
        public static let lg:  CGFloat = 24
        public static let xl:  CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let huge: CGFloat = 72

        /// Боковые поля экрана.
        public static let screen: CGFloat = 20
    }

    enum Radius {
        public static let xs:  CGFloat = 8
        public static let sm:  CGFloat = 12
        public static let md:  CGFloat = 18
        public static let lg:  CGFloat = 26
        public static let xl:  CGFloat = 34
        /// Для «пилюль» и круглых кнопок.
        public static let pill: CGFloat = 999
    }

    enum Size {
        /// Минимальная зона нажатия по HIG.
        public static let hitTarget: CGFloat = 44

        /// Значки внутри строк: шеврон у заголовка, галочка у пройденной
        /// точки, звезда у столицы. Шкала отдельная от `icon*` — эти живут
        /// среди текста и равняются по нему, а не стоят сами по себе.
        /// Три ступени, а не шесть: разницу в один пункт никто не видит,
        /// а в коде она превращается в случайные числа.
        public static let glyphSm: CGFloat = 10
        public static let glyphMd: CGFloat = 12
        public static let glyphLg: CGFloat = 14

        /// Самостоятельные значки — в кнопках и на панелях.
        public static let iconSm: CGFloat = 16
        public static let iconMd: CGFloat = 22
        public static let iconLg: CGFloat = 28

        /// Значок пустого экрана и экрана загрузки: единственное, что на нём
        /// есть, поэтому и размер другого порядка.
        public static let iconXl: CGFloat = 34
        public static let iconHero: CGFloat = 44

        public static let controlHeight: CGFloat = 52
    }
}

public extension View {
    /// Стандартные боковые поля экрана.
    func dsScreenPadding() -> some View {
        padding(.horizontal, DS.Space.screen)
    }

    /// Скругление в стиле iOS (непрерывная кривая, не окружность).
    func dsRounded(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
