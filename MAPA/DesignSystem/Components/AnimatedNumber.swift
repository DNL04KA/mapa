import SwiftUI

/// Число, которое «доезжает» до нового значения, а не подменяется скачком.
///
/// Реализовано через `Animatable`: SwiftUI интерполирует `animatableData`
/// и перерисовывает текст на каждом кадре. Именно так статистика на 4-м этапе
/// будет набегать при отметке новой страны.
///
/// При Reduce Motion вызывающая сторона передаёт короткую анимацию,
/// и число фактически появляется сразу.
public struct AnimatedNumber: View, Animatable {

    private var value: Double
    private let format: (Double) -> String
    private let font: Font
    /// Не `Color`, а `AnyShapeStyle`: главное число на карте залито градиентом,
    /// и ради него не хочется заводить второй почти такой же компонент.
    private let style: AnyShapeStyle

    public init(
        value: Double,
        font: Font = DS.Font.display,
        style: AnyShapeStyle = AnyShapeStyle(DS.Color.ink),
        format: @escaping (Double) -> String = { String(Int($0.rounded())) }
    ) {
        self.value = value
        self.font = font
        self.style = style
        self.format = format
    }

    public var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    public var body: some View {
        Text(format(value))
            .font(font)
            // Моноширинные цифры: строка не «дёргается» при смене разрядов.
            .monospacedDigit()
            .foregroundStyle(style)
    }
}

public extension AnimatedNumber {
    /// Процент с одним знаком после запятой — формат статистики «% мира».
    static func percent(
        _ value: Double,
        font: Font = DS.Font.hero,
        style: AnyShapeStyle = AnyShapeStyle(DS.Color.ink)
    ) -> AnimatedNumber {
        AnimatedNumber(value: value, font: font, style: style) { number in
            String(format: "%.1f%%", number)
        }
    }
}
