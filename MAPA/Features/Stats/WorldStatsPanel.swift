import SwiftUI

/// Статистика поверх карты.
///
/// Без карточки и без рамки: карта занимает весь экран, и любая панель
/// вырезала бы из неё кусок. Читаемость держит не подложка, а мягкое
/// затемнение сверху и тень под самим текстом.
struct WorldStatsPanel: View {

    @Environment(\.dsMotion) private var motion

    let statistics: TravelStatistics
    let theme: MapTheme
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            if statistics.isEmpty {
                emptyHeader
            } else {
                header
                if isExpanded {
                    legend
                    continents
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .accessibilityElement(children: .contain)
    }

    @MainActor private func toggle() {
        guard !statistics.isEmpty else { return }
        Haptics.shared.tap(.light)
        withAnimation(motion.animation(.smooth)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Шапка

    private var emptyHeader: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("Твоя карта пуста")
                .font(DS.Font.headline)
                .foregroundStyle(theme.mapInk)
            Text("Коснись любой страны, чтобы отметить её")
                .font(DS.Font.callout)
                .foregroundStyle(theme.mapInk.opacity(0.7))
        }
        .dsMapText()
        .accessibilityElement(children: .combine)
    }

    /// Шапка читается сверху вниз одним столбцом: надпись, число, полоса,
    /// счёт. Раньше огромный процент стоял слева, а «17 стран» мелко справа —
    /// и это выглядело как два чужих друг другу виджета на одном экране.
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(alignment: .bottom, spacing: DS.Space.sm) {
                percent

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.mapInk.opacity(0.7))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(motion.animation(.snap), value: isExpanded)
                    .padding(.bottom, 6)
            }

            progressLine

            Text(Plural.countries(statistics.exploredCount)
                 + " · " + Plural.continents(statistics.continentsTouched))
                .font(DS.Font.caption)
                .foregroundStyle(theme.mapInk.opacity(0.7))
                .monospacedDigit()
        }
        .dsMapText()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Мир открыт на \(String(format: "%.1f", statistics.worldPercent)) процента, "
            + "\(Plural.countries(statistics.exploredCount)), "
            + "\(Plural.continents(statistics.continentsTouched))"
        )
        .accessibilityHint(isExpanded ? "Свернуть подробности" : "Развернуть подробности")
        .accessibilityAddTraits(.isButton)
    }

    /// Главное число приложения, поэтому и обращение с ним особое.
    ///
    /// На тёмной карте это неоновая цифра с градиентом — она в одном языке
    /// со свечением стран. На бумаге тот же приём выглядит дёшево: там нужна
    /// журнальная подача — тонкое начертание, плотная посадка, один цвет.
    private var percent: some View {
        VStack(alignment: .leading, spacing: theme.isLight ? 0 : -6) {
            Text("Мир открыт на")
                .font(.system(size: theme.isLight ? 10 : 11, weight: .semibold))
                .tracking(theme.isLight ? 2.2 : DS.Font.overlineTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.mapInk.opacity(theme.isLight ? 0.45 : 0.5))

            HStack(alignment: .firstTextBaseline, spacing: theme.isLight ? 3 : 1) {
                AnimatedNumber(
                    value: statistics.worldPercent,
                    font: theme.isLight
                        ? .system(size: 62, weight: .light)
                        : .system(size: 58, weight: .bold, design: .rounded),
                    style: theme.isLight
                        ? AnyShapeStyle(theme.mapInk)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [theme.mapInk, theme.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ),
                    format: { String(format: "%.1f", $0) }
                )
                .tracking(theme.isLight ? -1.5 : 0)
                .animation(motion.animation(.smooth), value: statistics.worldPercent)

                Text("%")
                    .font(.system(size: theme.isLight ? 20 : 25,
                                  weight: theme.isLight ? .regular : .semibold,
                                  design: theme.isLight ? .default : .rounded))
                    .foregroundStyle(theme.mapInk.opacity(theme.isLight ? 0.35 : 1))
            }
        }
    }

    /// Полоса под числом: мир, разрезанный на континенты по площади.
    ///
    /// Раньше это была одна сплошная черта, и при 3.9 % она читалась как
    /// случайный штрих у левого края — непонятно, чего именно 3.9. Теперь
    /// видно, из чего складывается число: широкая Азия, узкая Европа, и
    /// сколько съедено внутри каждого куска. Сумма закрашенного по-прежнему
    /// равна проценту над полосой — это одна и та же величина, показанная
    /// телом, а не цифрой.
    private var progressLine: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 3
            let segments = statistics.segments
            let usable = max(0, proxy.size.width - gap * CGFloat(max(0, segments.count - 1)))

            HStack(spacing: gap) {
                ForEach(segments) { segment in
                    let width = usable * segment.share
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.mapInk.opacity(theme.isLight ? 0.13 : 0.14))

                        Capsule()
                            .fill(progressFill)
                            .frame(width: width * min(1, max(0, segment.filled)))
                            .shadow(color: theme.isLight ? .clear : theme.accent.opacity(0.8), radius: 6)
                    }
                    .frame(width: width)
                }
            }
            .animation(motion.animation(.smooth), value: statistics.worldPercent)
        }
        .frame(height: theme.isLight ? 4 : 5)
        .accessibilityHidden(true)
    }

    private var progressFill: AnyShapeStyle {
        theme.isLight
            ? AnyShapeStyle(theme.mapInk.opacity(0.8))
            : AnyShapeStyle(
                LinearGradient(
                    colors: [theme.accent.opacity(0.7), theme.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    // MARK: - Разбивка

    private var legend: some View {
        HStack(spacing: DS.Space.md) {
            legendItem(.visited, count: statistics.visitedCount)
            legendItem(.living, count: statistics.livingCount)
            legendItem(.wishlist, count: statistics.wishlistCount)
            Spacer(minLength: 0)
        }
        .dsMapText()
    }

    private func legendItem(_ status: TravelStatus, count: Int) -> some View {
        HStack(spacing: DS.Space.xxs) {
            Circle()
                .fill(DS.Gradient.status(status))
                .frame(width: 8, height: 8)

            Text("\(count)")
                .font(DS.Font.subhead)
                .foregroundStyle(theme.mapInk)
                .monospacedDigit()

            Text(status.title.lowercased())
                .font(DS.Font.micro)
                .foregroundStyle(theme.mapInk.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title): \(Plural.countries(count))")
    }

    private var continents: some View {
        VStack(spacing: DS.Space.xs) {
            ForEach(statistics.continents) { progress in
                continentRow(progress)
            }
        }
        .dsMapText()
    }

    private func continentRow(_ progress: TravelStatistics.ContinentProgress) -> some View {
        HStack(spacing: DS.Space.sm) {
            Text(progress.continent.title)
                .font(DS.Font.caption)
                .foregroundStyle(progress.explored > 0 ? DS.Color.ink : DS.Color.inkTertiary)
                .frame(width: 118, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            progressBar(progress.fraction)

            Text("\(progress.explored)/\(progress.total)")
                .font(DS.Font.micro)
                .foregroundStyle(theme.mapInk.opacity(0.5))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.continent.title): \(progress.explored) из \(progress.total)")
    }

    private func progressBar(_ fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.mapInk.opacity(0.16))

                Capsule()
                    .fill(theme.accent)
                    // Минимальная ширина, чтобы единственная страна на континенте
                    // не превращалась в невидимую полоску.
                    .frame(width: fraction > 0 ? max(6, proxy.size.width * fraction) : 0)
                    .animation(motion.animation(.smooth), value: fraction)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - Читаемость поверх карты

/// Тень под текстом поверх карты. Без подложки текст обязан читаться и на
/// светлой стране, и на тёмном океане — тень справляется с этим лучше рамки.
/// Цвет тени берётся от темы: по светлой карте тень белая, иначе тёмный текст
/// на светлом фоне обводится чёрным и выглядит как ошибка.
private struct DSMapText: ViewModifier {
    @Environment(\.mapTheme) private var theme

    func body(content: Content) -> some View {
        content
            .shadow(color: theme.mapInkShadow, radius: 6, y: 1)
            .shadow(color: theme.mapInkShadow.opacity(0.65), radius: 2, y: 1)
    }
}

public extension View {
    func dsMapText() -> some View { modifier(DSMapText()) }
}

/// Затемнение сверху под статистику. Плотное у самого края, полностью
/// прозрачное к середине — карта под ним остаётся видна.
struct MapTopScrim: View {

    @Environment(\.mapTheme) private var theme

    let height: CGFloat

    /// По светлой карте затемнение бессмысленно — нужно наоборот, засветление.
    private var scrimColor: Color { theme.isLight ? .white : DS.Palette.void }

    var body: some View {
        LinearGradient(
            stops: [
                // На белой карте затемнять нечего — там нужно, наоборот,
                // закрасить контуры под цифрами, поэтому засветление плотнее.
                .init(color: scrimColor.opacity(theme.isLight ? 0.99 : 0.72), location: 0.0),
                .init(color: scrimColor.opacity(theme.isLight ? 0.92 : 0.42), location: 0.5),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
