import SwiftUI

public extension DS {

    /// Ряд, который на крупном шрифте становится столбцом.
    ///
    /// Крупный шрифт — это не «тот же экран, только буквы больше». Ряд из
    /// трёх плиток шириной с экран делится на три по сто двадцать точек, и
    /// слово «Поделиться» в них не помещается ни при каком размере: оно
    /// либо жмётся до нечитаемого, либо обрезается многоточием. Поэтому
    /// на настройках размера текста из раздела «Универсальный доступ»
    /// ряд разворачивается в столбец — так делает и сам iOS в своих
    /// списках и настройках.
    ///
    /// `ViewThatFits` тут не подходит: плитки растянуты на всю доступную
    /// ширину, поэтому «влезает» всегда, и выбор никогда не доходит до
    /// запасного варианта.
    struct Reflow<Content: View>: View {

        @Environment(\.dynamicTypeSize) private var typeSize

        private let spacing: CGFloat
        private let content: Content

        public init(spacing: CGFloat = DS.Space.sm, @ViewBuilder content: () -> Content) {
            self.spacing = spacing
            self.content = content()
        }

        public var body: some View {
            if typeSize.isAccessibilitySize {
                VStack(spacing: spacing) { content }
            } else {
                HStack(spacing: spacing) { content }
            }
        }
    }
}
