import SwiftUI
import UIKit

public extension DS {

    /// Шрифтовая шкала. Два семейства:
    /// • `.rounded` — для чисел и «геройских» заголовков (статистика, проценты).
    ///   Округлые цифры выглядят дружелюбнее и лучше держат крупный кегль.
    /// • `.default` — для всего текстового.
    ///
    /// Размер здесь — базовый, для обычных настроек телефона. Настоящий
    /// считается от него: см. `FontStyle`.
    enum Font {
        // Числа и главные акценты
        public static let hero      = FontStyle(56, .bold,     .rounded, .largeTitle,  cap: 1.35)
        public static let display   = FontStyle(36, .bold,     .rounded, .largeTitle,  cap: 1.45)
        public static let numeral   = FontStyle(24, .semibold, .rounded, .title2,      cap: 1.6)

        // Заголовки
        public static let title     = FontStyle(26, .bold,     .default, .title1)
        public static let headline  = FontStyle(19, .semibold, .default, .headline)
        public static let subhead   = FontStyle(16, .semibold, .default, .subheadline)

        // Текст
        public static let body      = FontStyle(16, .regular,  .default, .body)
        public static let callout   = FontStyle(14, .regular,  .default, .callout)
        public static let caption   = FontStyle(13, .medium,   .default, .caption1)
        public static let micro     = FontStyle(11, .semibold, .default, .caption2)

        /// Разрядка для мелких заглавных подписей («КОНТИНЕНТЫ»).
        public static let overlineTracking: CGFloat = 1.4
    }

    /// Шрифт, который растёт вместе с настройкой размера текста на телефоне.
    ///
    /// Раньше шкала состояла из `Font.system(size:)`, а в комментарии было
    /// написано, что такой шрифт масштабируется сам. Это неправда:
    /// масштабируются только текстовые стили и шрифты, объявленные
    /// относительно них. Человек с крупным шрифтом в настройках открывал
    /// MAPA и не видел никакой разницы — приложение оставалось мелким.
    ///
    /// Поэтому размер считается через `UIFontMetrics` от того текстового
    /// стиля, которому эта ступень соответствует по смыслу: заголовок растёт
    /// как заголовок, подпись — как подпись.
    ///
    /// `cap` — потолок роста. Крупным ступеням он нужен, мелким нет: «2.5 %»
    /// в пятьдесят шесть пунктов на самом большом шрифте превратилось бы в
    /// сто тридцать и перестало помещаться в экран, а подписи обязаны расти
    /// до конца — ради них всё и затевалось.
    struct FontStyle: Equatable {
        public let size: CGFloat
        public let weight: SwiftUI.Font.Weight
        public let design: SwiftUI.Font.Design
        public let textStyle: UIFont.TextStyle
        public let cap: CGFloat

        public init(_ size: CGFloat,
                    _ weight: SwiftUI.Font.Weight,
                    _ design: SwiftUI.Font.Design,
                    _ textStyle: UIFont.TextStyle,
                    cap: CGFloat = 2.2) {
            self.size = size
            self.weight = weight
            self.design = design
            self.textStyle = textStyle
            self.cap = cap
        }

        /// Размер для заданной настройки телефона.
        public func size(for typeSize: DynamicTypeSize) -> CGFloat {
            let traits = UITraitCollection(preferredContentSizeCategory: typeSize.contentSizeCategory)
            let scaled = UIFontMetrics(forTextStyle: textStyle)
                .scaledValue(for: size, compatibleWith: traits)
            return min(scaled, size * cap)
        }

        public func font(for typeSize: DynamicTypeSize) -> SwiftUI.Font {
            .system(size: size(for: typeSize), weight: weight, design: design)
        }
    }
}

public extension DynamicTypeSize {
    /// Перевод в язык UIKit: `UIFontMetrics` умеет считать только от него.
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall:         return .extraSmall
        case .small:          return .small
        case .medium:         return .medium
        case .large:          return .large
        case .xLarge:         return .extraLarge
        case .xxLarge:        return .extraExtraLarge
        case .xxxLarge:       return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default:     return .large
        }
    }
}

/// Применяет ступень шкалы и пересчитывает её при смене настройки.
private struct ScaledFont: ViewModifier {

    @Environment(\.dynamicTypeSize) private var typeSize
    let style: DS.FontStyle

    func body(content: Content) -> some View {
        content.font(style.font(for: typeSize))
    }
}

public extension View {
    /// Та же запись, что и раньше — `.font(DS.Font.body)`, — но теперь текст
    /// слушается настроек телефона. Перегрузка, а не новое имя, ровно ради
    /// этого: сто сорок два места в приложении не пришлось трогать.
    func font(_ style: DS.FontStyle) -> some View {
        modifier(ScaledFont(style: style))
    }
}

// MARK: - Готовые текстовые стили

public extension View {
    /// Мелкая заглавная подпись-рубрика.
    func dsOverline() -> some View {
        self.font(DS.Font.micro)
            .tracking(DS.Font.overlineTracking)
            .textCase(.uppercase)
    }
}
