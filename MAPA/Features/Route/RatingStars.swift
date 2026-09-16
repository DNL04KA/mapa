import SwiftUI

/// Пять звёзд: и показывают оценку, и принимают её.
///
/// Один компонент на оба случая намеренно. Если развести показ и ввод
/// по разным вьюхам, они неизбежно разъедутся по размеру и отступам —
/// а звёзды должны выглядеть одинаково везде, где встречаются.
@MainActor
struct RatingStars: View {

    @Environment(\.dsMotion) private var motion

    /// Показанная оценка. Дробная для средней: 4.5 — половина звезды.
    let value: Double
    var size: CGFloat = 16
    var tint: Color = DS.Color.accent
    /// Если задано — звёзды становятся кнопками.
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: size * 0.22) {
            ForEach(1...5, id: \.self) { index in
                star(index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(onSelect == nil
            ? "Оценка \(String(format: "%.1f", value)) из пяти"
            : "Поставить оценку")
        .accessibilityValue("\(Int(value.rounded())) из 5")
    }

    @ViewBuilder
    private func star(_ index: Int) -> some View {
        if let onSelect {
            Button {
                Haptics.shared.selection()
                onSelect(index)
            } label: {
                Image(systemName: Double(index) <= value.rounded() ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Double(index) <= value.rounded() ? tint : DS.Color.inkTertiary)
                    .frame(width: size * 1.7, height: size * 1.9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(motion.animation(.snap), value: value)
        } else {
            Image(systemName: symbolName(for: index))
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Double(index) <= value + 0.25 ? tint : DS.Color.inkTertiary)
        }
    }

    /// Половинка нужна только для показа средней: при вводе оценка целая.
    private func symbolName(for index: Int) -> String {
        let difference = value - Double(index - 1)
        if difference >= 0.75 { return "star.fill" }
        if difference >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}
