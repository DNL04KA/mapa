import SwiftUI

// MARK: - Единая точка правды о доступности

/// Все решения «анимировать или нет», «стекло или заливка» проходят через этот тип.
/// Так в коде фич не появляется россыпь `@Environment(\.accessibilityReduceMotion)`,
/// и мы можем подменить значения для превью и ручной проверки.
public struct DSMotionContext: Equatable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool

    public init(reduceMotion: Bool = false, reduceTransparency: Bool = false) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
    }

    /// Анимация с учётом Reduce Motion.
    public func animation(_ preset: DS.Motion.Preset) -> Animation {
        reduceMotion ? preset.reducedAnimation : preset.animation
    }

    /// Переход с учётом Reduce Motion: при включённом — только прозрачность.
    public func transition(_ full: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : full
    }

    /// Стоит ли вообще запускать бесконечный фоновый дрейф.
    public var allowsAmbientMotion: Bool { !reduceMotion }

    /// Множитель смещения для параллакса и «разлёта» (0 при Reduce Motion).
    public var travelScale: CGFloat { reduceMotion ? 0 : 1 }
}

private struct DSMotionKey: EnvironmentKey {
    static let defaultValue = DSMotionContext()
}

public extension EnvironmentValues {
    var dsMotion: DSMotionContext {
        get { self[DSMotionKey.self] }
        set { self[DSMotionKey.self] = newValue }
    }
}

// MARK: - Установка контекста

private struct DSMotionInstaller: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency

    let forceReduceMotion: Bool
    let forceReduceTransparency: Bool

    func body(content: Content) -> some View {
        content.environment(
            \.dsMotion,
            DSMotionContext(
                reduceMotion: systemReduceMotion || forceReduceMotion,
                reduceTransparency: systemReduceTransparency || forceReduceTransparency
            )
        )
    }
}

public extension View {
    /// Ставится один раз в корне приложения.
    /// `force*` нужны только для ручной проверки — системные настройки они не отменяют,
    /// а лишь дополняют (логическое ИЛИ).
    func dsMotionEnvironment(
        forceReduceMotion: Bool = false,
        forceReduceTransparency: Bool = false
    ) -> some View {
        modifier(
            DSMotionInstaller(
                forceReduceMotion: forceReduceMotion,
                forceReduceTransparency: forceReduceTransparency
            )
        )
    }
}
