import SwiftUI

/// Метки поверх карты: дом и «ты здесь».
///
/// Слой объявлен `Animatable` с той же камерой, что и холст. Без этого метки
/// прыгали бы к конечной точке, пока карта плавно едет: SwiftUI анимировал бы
/// их отдельно от `Canvas`, и связь между меткой и страной терялась бы.
struct MapMarkersLayer: View, Animatable {

    var camera: MapCamera

    let home: HomePlace?
    let current: Coordinate?
    let viewport: CGSize
    let accent: Color

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(camera.zoom, AnimatablePair(camera.center.x, camera.center.y)) }
        set {
            camera.zoom = newValue.first
            camera.center = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    var body: some View {
        ZStack {
            if let point = pingPoint {
                LocationPin(scale: markerScale, accent: accent)
                    // Остриё пина должно стоять ровно в точке, а `position`
                    // ставит центр — отсюда сдвиг на половину высоты.
                    .position(x: point.x, y: point.y - LocationPin.height * markerScale / 2)
            }

            if let home, let point = screenPoint(for: home.unitPoint) {
                // Иконка лежит прямо на стране, а не висит над ней на булавке.
                HomeMark(scale: markerScale, label: camera.zoom >= 3 ? home.cityName : nil)
                    .position(point)
            }
        }
        .allowsHitTesting(false)
    }

    /// Метки живут в экранных точках, а страны — в долях мира. На обзоре всего
    /// мира значок в натуральную величину накрывает пол-Европы, поэтому он
    /// сжимается вместе с картой и разворачивается по мере приближения.
    private var markerScale: CGFloat {
        min(max((camera.zoom - 0.8) / 3.4, 0.4), 1)
    }

    /// Когда ты дома, обе метки встают в одну точку и мешают друг другу.
    /// Дом важнее: он именованный и постоянный, а пинг лишь дублировал бы его.
    private var pingPoint: CGPoint? {
        guard let current, let point = screenPoint(for: MapProjection.unitPoint(current)) else { return nil }
        if let home, let homePoint = screenPoint(for: home.unitPoint) {
            if hypot(point.x - homePoint.x, point.y - homePoint.y) < 26 { return nil }
        }
        return point
    }

    /// Экранная точка метки.
    ///
    /// Мир бесконечен по горизонтали, поэтому у одной географической точки
    /// есть бесконечно много экранных. Перебираем ближайшие копии и берём ту,
    /// что реально попала на экран; если ни одна не попала — метку не рисуем.
    private func screenPoint(for unit: CGPoint) -> CGPoint? {
        guard viewport.width > 0 else { return nil }
        let margin: CGFloat = 120

        for offset in camera.visibleWorldOffsets(in: viewport) {
            let shifted = CGPoint(x: unit.x + offset, y: unit.y)
            let point = camera.screenPoint(unit: shifted, in: viewport)
            if point.x > -margin, point.x < viewport.width + margin,
               point.y > -margin, point.y < viewport.height + margin {
                return point
            }
        }
        return nil
    }
}

// MARK: - Форма пина

/// Капля: круг сверху, остриё снизу. Боковые линии идут по касательной
/// к окружности — иначе в месте стыка появляется излом, который заметен
/// даже на мелком значке.
struct PinShape: Shape {

    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let distance = tip.y - center.y

        var path = Path()
        guard distance > radius else {
            path.addEllipse(in: rect)
            return path
        }

        let beta = acos(radius / distance)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .radians(.pi / 2 + beta),
            endAngle: .radians(.pi / 2 - beta),
            clockwise: false
        )
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}

// MARK: - Дом

/// Белая иконка дома, лежащая прямо на стране.
///
/// Не булавка: булавка втыкается в карту сверху и живёт в своём слое,
/// а здесь значок должен читаться как часть самой карты. Поэтому он стоит
/// ровно в точке, без острия и подложки, и мягко пульсирует свечением.
struct HomeMark: View {

    @Environment(\.dsMotion) private var motion
    @Environment(\.mapTheme) private var theme
    @State private var isBreathing = false

    var scale: CGFloat = 1
    /// Название города. Появляется, только когда карта достаточно приближена:
    /// на обзоре мира подпись под каждым домом была бы просто мусором.
    var label: String?

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "house.fill")
                .font(.system(size: DS.Size.iconMd * scale, weight: .semibold))
                .foregroundStyle(theme.mapInk)
                // Контур обязателен: значок на жёлтой или салатовой стране
                // без него просто исчезает.
                .shadow(color: theme.mapInkShadow, radius: 2.5 * scale, y: 1)
                .shadow(color: theme.mapInk.opacity(isBreathing ? 0.9 : 0.25), radius: (isBreathing ? 12 : 4) * scale)
                .opacity(isBreathing ? 1 : 0.78)

            if let label {
                Text(label)
                    .font(DS.Font.micro)
                    .foregroundStyle(theme.mapInk)
                    .fixedSize()
                    .dsMapText()
            }
        }
        .onAppear {
            guard motion.allowsAmbientMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .accessibilityLabel(label.map { "Твой дом, \($0)" } ?? "Твой дом")
    }
}

// MARK: - Ты здесь

/// Белый пин с отверстием — та самая классическая геометка.
/// Появляется падением сверху, дальше едва заметно покачивается,
/// а тень под ним дышит в такт: так метка выглядит стоящей на карте,
/// а не наклеенной на экран.
struct LocationPin: View {

    @Environment(\.dsMotion) private var motion
    @Environment(\.mapTheme) private var theme
    @State private var hasLanded = false
    @State private var isHovering = false

    var scale: CGFloat = 1
    var accent: Color = DS.Color.accent

    static let width: CGFloat = 26
    static let height: CGFloat = 34

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.35))
                .frame(width: 14 * scale, height: 4 * scale)
                .scaleEffect(isHovering ? 0.8 : 1)
                .blur(radius: 1.5 * scale)
                .offset(y: 3 * scale)

            pin
                .offset(y: isHovering ? -3 * scale : 0)
        }
        .frame(width: Self.width * scale, height: Self.height * scale, alignment: .bottom)
        .scaleEffect(hasLanded ? 1 : 0.4, anchor: .bottom)
        .opacity(hasLanded ? 1 : 0)
        .onAppear(perform: start)
        .accessibilityLabel("Ты здесь")
    }

    private var pin: some View {
        PinShape()
            .fill(theme.mapInk)
            .frame(width: Self.width * scale, height: Self.height * scale)
            .overlay {
                Circle()
                    .fill(accent)
                    .frame(width: 9 * scale, height: 9 * scale)
                    .offset(y: -(Self.height * scale) / 2 + Self.width * scale / 2)
            }
            .shadow(color: accent.opacity(0.7), radius: 8 * scale)
    }

    private func start() {
        guard motion.allowsAmbientMotion else {
            hasLanded = true
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
            hasLanded = true
        }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
            isHovering = true
        }
    }
}
