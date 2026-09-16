import SwiftUI

/// «Стекло» MAPA — основа всех карточек и панелей.
///
/// Слоёв три, и каждый нужен:
/// 1. материал (размытие того, что под ним) — даёт глубину;
/// 2. едва заметный градиент сверху — свет;
/// 3. градиентная обводка — кромка, которая ловит блик.
///
/// При Reduce Transparency материал заменяется непрозрачной заливкой:
/// контраст сохраняется, размытие исчезает.
public struct DSGlass: ViewModifier {

    @Environment(\.dsMotion) private var motion

    let radius: CGFloat
    let shadow: DS.Shadow
    let borderOpacity: Double

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if motion.reduceTransparency {
                        DS.Color.materialFallback
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                        DS.Gradient.surface
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DS.Gradient.glassBorder(borderOpacity), lineWidth: 1)
            }
            .dsShadow(shadow)
    }
}

public extension View {
    /// Карточка/панель в фирменном стекле.
    func dsGlass(
        radius: CGFloat = DS.Radius.lg,
        shadow: DS.Shadow = .medium,
        borderOpacity: Double = 1.0
    ) -> some View {
        modifier(DSGlass(radius: radius, shadow: shadow, borderOpacity: borderOpacity))
    }
}

/// Готовая карточка с внутренними отступами — чтобы не повторять
/// `.padding().dsGlass()` в каждом экране.
public struct GlassCard<Content: View>: View {

    private let radius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        radius: CGFloat = DS.Radius.lg,
        padding: CGFloat = DS.Space.md,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlass(radius: radius)
    }
}
