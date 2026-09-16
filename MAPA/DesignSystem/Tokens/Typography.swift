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
