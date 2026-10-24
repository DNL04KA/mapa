import SwiftUI

public extension DS {

    /// Шрифтовая шкала. Два семейства:
    /// • `.rounded` — для чисел и «геройских» заголовков (статистика, проценты).
    ///   Округлые цифры выглядят дружелюбнее и лучше держат крупный кегль.
    /// • `.default` — для всего текстового.
    ///
    /// Системный шрифт с явным размером в SwiftUI масштабируется Dynamic Type,
    /// поэтому доступность не ломается.
    enum Font {
        // Числа и главные акценты
        public static let hero      = SwiftUI.Font.system(size: 56, weight: .bold,      design: .rounded)
        public static let display   = SwiftUI.Font.system(size: 36, weight: .bold,      design: .rounded)
        public static let numeral   = SwiftUI.Font.system(size: 24, weight: .semibold,  design: .rounded)

        // Заголовки
        public static let title     = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let headline  = SwiftUI.Font.system(size: 19, weight: .semibold)
        public static let subhead   = SwiftUI.Font.system(size: 16, weight: .semibold)

        // Текст
        public static let body      = SwiftUI.Font.system(size: 16, weight: .regular)
        public static let callout   = SwiftUI.Font.system(size: 14, weight: .regular)
        public static let caption   = SwiftUI.Font.system(size: 13, weight: .medium)
        public static let micro     = SwiftUI.Font.system(size: 11, weight: .semibold)
        /// Мельче `micro` уже не подпись, а сноска: кредит фотографии,
        /// надпись на узкой кнопке. Ниже девяти опускаться нельзя.
        public static let nano      = SwiftUI.Font.system(size: 9,  weight: .regular)
        /// Подпись под значком вкладки — своя ступень: она стоит под иконкой
        /// и меряется по ней, а не по тексту рядом.
        public static let tab       = SwiftUI.Font.system(size: 10, weight: .medium)

        // Особые случаи — по одному на приложение.

        /// Номер точки в кружке: цифра должна быть плотной и круглой.
        public static let badge     = SwiftUI.Font.system(size: 12, weight: .bold,  design: .rounded)
        /// Имя приложения в шапке настроек.
        public static let brand     = SwiftUI.Font.system(size: 22, weight: .heavy, design: .rounded)
        /// Название страны в карточке — крупнее `display`, потому что это
        /// заголовок экрана, а не число в панели.
        public static let titleHero = SwiftUI.Font.system(size: 40, weight: .bold)

        /// Разрядка для мелких заглавных подписей («КОНТИНЕНТЫ»).
        public static let overlineTracking: CGFloat = 1.4
    }
}

// MARK: - Готовые текстовые стили

public extension View {
    /// Мелкая заглавная подпись-рубрика.
    func dsOverline() -> some View {
        self.font(DS.Font.micro)
            .tracking(DS.Font.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(DS.Color.inkTertiary)
    }
}
