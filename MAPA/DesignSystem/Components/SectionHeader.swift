import SwiftUI

/// Заголовок секции. Вынесен в компонент, чтобы вертикальный ритм
/// между блоками был одинаковым на всех экранах.
public struct SectionHeader: View {

    private let title: LocalizedStringKey
    /// Строка, а не ключ перевода: сюда чаще приходят данные — «5 городов
    /// · 14 дней», — а не фраза из словаря. Там, где подзаголовок всё же
    /// фраза, её переводят на месте вызова через `String(localized:)`.
    private let subtitle: String?

    public init(_ title: LocalizedStringKey, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title)
                .dsOverline()
            if let subtitle {
                Text(subtitle)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
