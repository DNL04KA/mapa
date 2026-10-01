import SwiftUI

/// Формат картинки для соцсетей.
enum ExportFormat: String, CaseIterable, Identifiable {
    /// Вертикальная история.
    case story
    /// Пост в ленту.
    case post
    /// Квадрат.
    case square

    var id: String { rawValue }

    var title: String {
        switch self {
        case .story:  return "Истории"
        case .post:   return "Пост"
        case .square: return "Квадрат"
        }
    }

    /// Итоговый размер в пикселях.
    var pixelSize: CGSize {
        switch self {
        case .story:  return CGSize(width: 1080, height: 1920)
        case .post:   return CGSize(width: 1080, height: 1350)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }

    /// Размер вьюхи в точках. Рисуем втрое мельче и рендерим с масштабом 3 —
    /// так шрифты и отступы остаются в привычных величинах дизайн-системы.
    var pointSize: CGSize {
        CGSize(width: pixelSize.width / 3, height: pixelSize.height / 3)
    }

    var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }
}

/// Что именно показывать на карточке.
enum ExportTemplate: String, CaseIterable, Identifiable {
    /// Карта с отметками и процентом.
    case map
    /// Один маршрут с линией и точками.
    case route

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map:   return "Карта"
        case .route: return "Маршрут"
        }
    }
}

/// Карточка на экспорт.
///
/// Здесь нельзя использовать материалы и `UIViewRepresentable`: `ImageRenderer`
/// рисует их как пустоту. Поэтому все подложки — сплошные цвета из темы,
/// а не стекло, как в остальном приложении.
@MainActor
struct ExportCard: View {

    let template: ExportTemplate
    let format: ExportFormat
    let theme: MapTheme
    let geometry: WorldGeometry
    let overlay: MapOverlayState
    let camera: MapCamera
    let statistics: TravelStatistics
    let route: Route?
    let homeCity: String?

    private var size: CGSize { format.pointSize }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            map
            scrim
            caption
        }
        .frame(width: size.width, height: size.height)
        .background(theme.oceanTop)
        .clipped()
    }

    // MARK: - Карта

    private var map: some View {
        MapCanvas(
            camera: camera,
            bloomProgress: 0,
            geometry: geometry,
            overlay: overlay,
            stats: RenderStats(),
            showsGraticule: theme.graticuleOpacity > 0,
            theme: theme
        )
        .frame(width: size.width, height: size.height)
    }

    /// Затемнение снизу — без него подпись тонет в карте.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.42),
                .init(color: scrimColor.opacity(0.55), location: 0.72),
                .init(color: scrimColor.opacity(0.92), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var scrimColor: Color {
        theme.isLight ? .white : DS.Palette.void
    }

    // MARK: - Подпись

    private var caption: some View {
        VStack(alignment: .leading, spacing: size.width * 0.03) {
            switch template {
            case .map:   mapCaption
            case .route: routeCaption
            }

            wordmark
        }
        .padding(size.width * 0.075)
    }

    private var mapCaption: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Не «Из Рима»: склонять названия городов программно нельзя —
            // «из Осло» и «из Тбилиси» не меняются, «из Рима» меняется.
            // Метка без падежа работает для любого города.
            Text(homeCity.map { "Дом · \($0)" } ?? "Мир открыт на")
                .font(.system(size: size.width * 0.035, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(theme.mapInk.opacity(0.55))

            HStack(alignment: .firstTextBaseline, spacing: size.width * 0.012) {
                Text(String(format: "%.1f", statistics.worldPercent))
                    .font(.system(size: size.width * 0.2, weight: theme.isLight ? .light : .bold,
                                  design: theme.isLight ? .default : .rounded))
                    .foregroundStyle(theme.mapInk)

                Text("%")
                    .font(.system(size: size.width * 0.07, weight: .regular))
                    .foregroundStyle(theme.mapInk.opacity(0.45))
            }

            Text(subtitleText)
                .font(.system(size: size.width * 0.042, weight: .medium))
                .foregroundStyle(theme.mapInk.opacity(0.75))
        }
    }

    private var subtitleText: String {
        [Plural.countries(statistics.exploredCount),
         Plural.continents(statistics.continentsTouched)]
            .joined(separator: " · ")
    }

    private var routeCaption: some View {
        VStack(alignment: .leading, spacing: size.width * 0.02) {
            Text("Маршрут")
                .font(.system(size: size.width * 0.035, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(theme.mapInk.opacity(0.55))

            Text(route?.displayTitle ?? "")
                .font(.system(size: size.width * 0.075, weight: .bold))
                .foregroundStyle(theme.mapInk)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            if let route {
                Text(routeSubtitle(route))
                    .font(.system(size: size.width * 0.04, weight: .medium))
                    .foregroundStyle(theme.mapInk.opacity(0.75))

                // Города через точку, а не списком: в кадре важнее цепочка,
                // чем перечень — её читают одним движением глаз.
                Text(route.points.prefix(6).map(\.name).joined(separator: " · "))
                    .font(.system(size: size.width * 0.036, weight: .regular))
                    .foregroundStyle(theme.mapInk.opacity(0.6))
                    .lineLimit(2)
            }
        }
    }

    private func routeSubtitle(_ route: Route) -> String {
        var parts = [Plural.points(route.points.count)]
        if route.totalDays > 0 {
            parts.append(Plural.days(route.totalDays))
        }
        if route.totalDistanceKm > 1 {
            parts.append("\(Int(route.totalDistanceKm)) км")
        }
        return parts.joined(separator: " · ")
    }

    private var wordmark: some View {
        Text("MAPA")
            .font(.system(size: size.width * 0.038, weight: .heavy, design: .rounded))
            .tracking(2.5)
            .foregroundStyle(theme.accent)
    }
}
