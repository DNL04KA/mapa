import SwiftUI

/// Живой фон приложения: несколько цветных «облаков», медленно дрейфующих
/// в глубине. Даёт ощущение, что за интерфейсом есть пространство,
/// и стоит почти ничего — это радиальные градиенты, а не блюр по всему экрану.
///
/// При Reduce Motion облака замирают: композиция остаётся, движение исчезает.
public struct AuroraBackground: View {

    @Environment(\.dsMotion) private var motion
    @State private var drift: CGFloat = 0

    /// Насколько ярко светятся облака (на карте фон должен быть тише).
    private let intensity: Double
    private let colors: [Color]

    public init(intensity: Double = 1.0, colors: [Color] = MapTheme.default.auroraColors) {
        self.intensity = intensity
        self.colors = colors
    }

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                DS.Gradient.appBackground

                blob(
                    color: colors[0],
                    diameter: w * 1.15,
                    center: CGPoint(x: w * 0.18, y: h * 0.14),
                    travel: CGSize(width: w * 0.16, height: h * 0.05),
                    phase: 0
                )

                blob(
                    color: colors[min(1, colors.count - 1)],
                    diameter: w * 1.0,
                    center: CGPoint(x: w * 0.92, y: h * 0.34),
                    travel: CGSize(width: -w * 0.12, height: h * 0.08),
                    phase: 0.66
                )

                blob(
                    color: colors[min(2, colors.count - 1)],
                    diameter: w * 1.25,
                    center: CGPoint(x: w * 0.55, y: h * 0.96),
                    travel: CGSize(width: w * 0.10, height: -h * 0.07),
                    phase: 1.33
                )

                NoiseOverlay(opacity: 0.035)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: startDriftIfAllowed)
        .accessibilityHidden(true)
    }

    private func blob(color: Color, diameter: CGFloat, center: CGPoint, travel: CGSize, phase: Double) -> some View {
        // Каждое облако движется по своей фазе, поэтому картина не «пульсирует» синхронно.
        let t = sin((drift + phase) * .pi)
        let dx = travel.width * t * motion.travelScale
        let dy = travel.height * cos((drift + phase) * .pi) * motion.travelScale

        return Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.42 * intensity), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
            .position(x: center.x + dx, y: center.y + dy)
            .blendMode(.plusLighter)
    }

    private func startDriftIfAllowed() {
        guard motion.allowsAmbientMotion else { return }
        withAnimation(.easeInOut(duration: DS.Motion.Duration.ambientLoop).repeatForever(autoreverses: true)) {
            drift = 2
        }
    }
}
