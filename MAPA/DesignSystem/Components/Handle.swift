import SwiftUI

public extension DS {

    /// Никнейм одним словом.
    ///
    /// Собачка — не отдельное слово, а приставка: между ней и именем не
    /// должно быть ни пробела, ни разрядки, иначе «@nikita» читается как
    /// «@ nikita» и перестаёт быть адресом. И она тише самого никнейма —
    /// глаз должен цепляться за имя, а собачка лишь говорит, что это оно.
    ///
    /// Возвращает `Text`, а не готовую вьюху: размер, обрезку и подпись
    /// для голоса каждый экран ставит свои.
    static func handle(_ handle: String, tint: SwiftUI.Color = DS.Color.ink) -> Text {
        Text(verbatim: "@").foregroundColor(tint.opacity(0.5))
            + Text(verbatim: handle).foregroundColor(tint)
    }
}
