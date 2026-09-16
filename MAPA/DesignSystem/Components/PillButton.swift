import SwiftUI

/// Стиль кнопок MAPA. Стандартный `.buttonStyle(.bordered)` в приложении
/// не используется — он приносит чужую типографику и чужие радиусы.
///
/// Важная деталь: `@Environment` внутри самого `ButtonStyle` не работает —
/// стиль не является View и не подключён к иерархии. Поэтому вся отрисовка
/// вынесена во вложенный `Body`, который окружение читать умеет.
public struct DSButtonStyle: ButtonStyle {

    public enum Kind {
        /// Главное действие: градиент бренда.
        case primary
        /// Вторичное: стекло.
        case secondary
        /// Третичное: только текст.
        case ghost
        /// Действие в цвете статуса.
        case status(TravelStatus)
    }

    private let kind: Kind
    private let fullWidth: Bool

    public init(_ kind: Kind = .primary, fullWidth: Bool = false) {
        self.kind = kind
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, kind: kind, fullWidth: fullWidth)
    }

    private struct StyleBody: View {
        @Environment(\.dsMotion) private var motion
        @Environment(\.isEnabled) private var isEnabled

        let configuration: DSButtonStyle.Configuration
        let kind: Kind
        let fullWidth: Bool

        var body: some View {
            configuration.label
                .font(DS.Font.subhead)
                .foregroundStyle(foreground)
                .padding(.horizontal, DS.Space.lg)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: DS.Size.controlHeight)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous))
                .overlay {
                    if isSecondary {
                        RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                            .strokeBorder(DS.Color.border, lineWidth: 1)
                    }
                }
                .dsShadow(shadow)
                // Нажатие «проваливается» — самый читаемый отклик и без задержек.
                .scaleEffect(configuration.isPressed ? 0.965 : 1)
                .opacity(isEnabled ? 1 : 0.4)
                .animation(motion.animation(.snap), value: configuration.isPressed)
                .contentShape(Rectangle())
        }

        private var isSecondary: Bool {
            if case .secondary = kind { return true }
            return false
        }

        @ViewBuilder
        private var background: some View {
            switch kind {
            case .primary:
                DS.Gradient.accent
            case .secondary:
                if motion.reduceTransparency {
                    DS.Color.materialFallback
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            case .ghost:
                Color.clear
            case .status(let status):
                DS.Gradient.status(status)
            }
        }

        private var foreground: Color {
            switch kind {
            case .primary:   return .white
            case .secondary: return DS.Color.ink
            case .ghost:     return DS.Color.inkSecondary
            case .status(let status): return DS.Gradient.statusForeground(status)
            }
        }

        private var shadow: DS.Shadow {
            guard isEnabled else { return .none }
            switch kind {
            case .primary:
                return configuration.isPressed ? .low : .glow(DS.Palette.indigo, radius: 20)
            case .status(let status):
                return configuration.isPressed ? .low : .glow(DS.Gradient.statusGlowColor(status), radius: 20)
            case .secondary:
                return .low
            case .ghost:
                return .none
            }
        }
    }
}

public extension ButtonStyle where Self == DSButtonStyle {
    static var dsPrimary: DSButtonStyle { DSButtonStyle(.primary) }
    static var dsSecondary: DSButtonStyle { DSButtonStyle(.secondary) }
    static var dsGhost: DSButtonStyle { DSButtonStyle(.ghost) }
}

/// Кнопка-пилюля с хаптикой «из коробки»: отклик привязан к самому нажатию,
/// а не к результату действия, поэтому ощущается мгновенным.
public struct PillButton: View {

    private let title: String
    private let icon: String?
    private let kind: DSButtonStyle.Kind
    private let fullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        kind: DSButtonStyle.Kind = .primary,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.shared.tap(.light)
            action()
        } label: {
            HStack(spacing: DS.Space.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: DS.Size.iconSm, weight: .semibold))
                }
                Text(title)
            }
        }
        .buttonStyle(DSButtonStyle(kind, fullWidth: fullWidth))
    }
}
