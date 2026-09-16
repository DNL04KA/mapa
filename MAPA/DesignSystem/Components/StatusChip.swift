import SwiftUI

/// Чип статуса — прообраз того, что появится в шите выбора на 3-м этапе.
/// Выбранный чип заливается градиентом статуса и получает цветное свечение;
/// невыбранный остаётся стеклянным.
public struct StatusChip: View {

    @Environment(\.dsMotion) private var motion

    private let status: TravelStatus
    private let isSelected: Bool
    private let action: () -> Void

    public init(status: TravelStatus, isSelected: Bool, action: @escaping () -> Void) {
        self.status = status
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            // Фирменный паттерн: тот же отклик получит заливка страны на карте.
            if isSelected {
                Haptics.shared.countryClear()
            } else {
                Haptics.shared.countryFill()
            }
            action()
        } label: {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: status.icon)
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text(status.title)
                    .font(DS.Font.subhead)
            }
            .foregroundStyle(isSelected ? DS.Gradient.statusForeground(status) : DS.Color.inkSecondary)
            .padding(.horizontal, DS.Space.md)
            .frame(height: DS.Size.hitTarget)
            .background {
                ZStack {
                    if isSelected {
                        DS.Gradient.status(status)
                    } else if motion.reduceTransparency {
                        DS.Color.materialFallback
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.35) : DS.Color.border,
                        lineWidth: 1
                    )
            }
            .dsShadow(isSelected ? .glow(DS.Gradient.statusGlowColor(status), radius: 18) : .low)
        }
        .buttonStyle(.plain)
        .animation(motion.animation(.bounce), value: isSelected)
        .accessibilityLabel(status.title)
        .accessibilityHint(status.subtitle)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
