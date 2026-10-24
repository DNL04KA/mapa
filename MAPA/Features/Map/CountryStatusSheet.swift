import SwiftUI

/// Панель выбора статуса.
///
/// Это не `.sheet` и не `Form`: системный шит принёс бы свою анимацию, свои
/// поля и свой фон — и карта на время выбора перестала бы быть видна.
/// Здесь панель живёт в том же слое, что и карта, поэтому страна остаётся
/// подсвеченной, а сама карта успевает подвинуться, чтобы её не закрыть.
struct CountryStatusSheet: View {

    @Environment(\.dsMotion) private var motion

    let country: Country
    let currentStatus: TravelStatus?
    let isHome: Bool
    let onSelect: (TravelStatus) -> Void
    let onClear: () -> Void
    let onToggleHome: () -> Void
    let onOpenCard: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel
        }
        .ignoresSafeArea()
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть выбор статуса")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.lg) {
            handle
            header
            detailsButton
            options
            homeButton
            clearButton
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl)
        .frame(maxWidth: .infinity)
        .background {
            // Скругление только сверху: панель «выезжает» из-под края экрана.
            UnevenRoundedTopShape(radius: DS.Radius.xl)
                .fill(panelFill)
                .overlay {
                    UnevenRoundedTopShape(radius: DS.Radius.xl)
                        .stroke(DS.Gradient.glassBorder(0.8), lineWidth: 1)
                }
                .dsShadow(.high)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .transition(.move(edge: .bottom))
    }

    private var panelFill: AnyShapeStyle {
        motion.reduceTransparency
            ? AnyShapeStyle(DS.Color.materialFallback)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    private var handle: some View {
        Capsule()
            .fill(DS.Color.borderStrong)
            .frame(width: 38, height: 4)
            .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: DS.Space.xxs) {
            Text(country.displayName)
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(subtitle)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let continent = country.continent {
            parts.append(continent.title)
        }
        if country.areaKm2 > 0 {
            let area = Self.areaFormatter.string(from: NSNumber(value: country.areaKm2)) ?? ""
            // Единица площади переводится: на английском телефоне в подписи
            // к стране стояло «404 322 км²».
            parts.append(String(format: NSLocalizedString("%@ км²", comment: ""), area))
        }
        return parts.joined(separator: " · ")
    }

    /// Быстрая отметка — тапом, а всё остальное про страну — здесь.
    /// Так основной жест остаётся в один тап, а карточка не мешается.
    private var detailsButton: some View {
        Button(action: onOpenCard) {
            HStack(spacing: DS.Space.xxs) {
                Text("Подробнее о стране")
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Size.glyphSm, weight: .bold))
            }
            .font(DS.Font.callout)
            .foregroundStyle(DS.Color.accentSoft)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var options: some View {
        DS.Reflow(spacing: DS.Space.xs) {
            ForEach(TravelStatus.allCases) { status in
                StatusOptionCard(
                    status: status,
                    isSelected: currentStatus == status
                ) {
                    onSelect(status)
                }
            }
        }
    }

    /// Дом — точка, а не страна: он встаёт ровно туда, куда ты ткнул.
    private var homeButton: some View {
        Button(action: onToggleHome) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: isHome ? "house.fill" : "house")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text(isHome ? "Это твой дом" : "Сделать домом")
            }
            .font(DS.Font.subhead)
            .foregroundStyle(isHome ? DS.Gradient.statusForeground(.living) : DS.Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.hitTarget)
            .background {
                if isHome {
                    DS.Gradient.status(.living)
                } else if motion.reduceTransparency {
                    DS.Color.surfaceRaised
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isHome ? Color.white.opacity(0.35) : DS.Color.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isHome ? "Убрать отметку дома" : "Поставить дом в этой точке")
    }

    @ViewBuilder
    private var clearButton: some View {
        if currentStatus != nil {
            Button(action: onClear) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    Text("Убрать отметку")
                }
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.hitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Потянуть вниз, чтобы закрыть. Вверх панель не тянется — за ней нет
    /// второго уровня, и резинка на пустоту выглядела бы как недоделка.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 90
                    || value.predictedEndTranslation.height > 220

                if shouldDismiss {
                    onDismiss()
                }
                withAnimation(motion.animation(.snap)) {
                    dragOffset = 0
                }
            }
    }

    private static let areaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

// MARK: - Карточка статуса

/// Крупная карточка вместо мелкого чипа: выбор статуса — главное действие
/// приложения, и попадать в него нужно не глядя.
struct StatusOptionCard: View {

    @Environment(\.dsMotion) private var motion
    @Environment(\.dynamicTypeSize) private var typeSize

    let status: TravelStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
            .frame(maxWidth: .infinity)
            .frame(height: typeSize.isAccessibilitySize ? nil : 96)
            .background {
                if isSelected {
                    DS.Gradient.status(status)
                } else if motion.reduceTransparency {
                    DS.Color.surfaceRaised
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.35) : DS.Color.border,
                        lineWidth: 1
                    )
            }
            .dsShadow(isSelected ? .glow(DS.Gradient.statusGlowColor(status), radius: 20) : .low)
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .animation(motion.animation(.bounce), value: isSelected)
        .accessibilityLabel(status.title)
        .accessibilityHint(status.subtitle)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Значок над подписью — или рядом с ней.
    ///
    /// На крупном шрифте «Был», «Живу» и «Хочу» в три плитки по ширине
    /// экрана уже не помещаются: подпись упирается в края и начинает
    /// жаться. Поэтому плитки превращаются в строки — так же, как это
    /// делает сам iOS в своих списках.
    @ViewBuilder
    private var label: some View {
        if typeSize.isAccessibilitySize {
            HStack(spacing: DS.Space.sm) {
                icon
                title
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)
        } else {
            VStack(spacing: DS.Space.xs) {
                icon
                title
            }
        }
    }

    private var icon: some View {
        Image(systemName: status.icon)
            .font(.system(size: DS.Size.iconLg, weight: .semibold))
            .foregroundStyle(isSelected ? DS.Gradient.statusForeground(status) : DS.Color.inkSecondary)
    }

    private var title: some View {
        Text(status.title)
            .font(DS.Font.subhead)
            .foregroundStyle(isSelected ? DS.Gradient.statusForeground(status) : DS.Color.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Форма панели

/// Прямоугольник со скруглением только сверху.
/// `UnevenRoundedRectangle` появился лишь в iOS 17, поэтому рисуем сами.
struct UnevenRoundedTopShape: Shape {

    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
