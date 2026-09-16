import SwiftUI

/// Контур страны, вписанный в прямоугольник.
///
/// Фотографий у нас нет и не будет ещё долго, а «герой» карточке нужен.
/// Собственный силуэт страны честнее любого стока: он уникален, он и есть
/// то, что человек только что трогал пальцем на карте.
struct CountrySilhouette: Shape {

    let country: Country

    func path(in rect: CGRect) -> Path {
        // Берём габариты главного массива, а не всей страны: иначе Аляска
        // и Гавайи ужимают США в невнятную полоску.
        let box = country.mainBounds
        guard box.width > 0, box.height > 0, rect.width > 0, rect.height > 0 else {
            return Path()
        }

        let scale = min(rect.width / box.width, rect.height / box.height)
        let width = box.width * scale
        let height = box.height * scale

        let transform = CGAffineTransform(
            translationX: rect.minX + (rect.width - width) / 2 - box.minX * scale,
            y: rect.minY + (rect.height - height) / 2 - box.minY * scale
        ).scaledBy(x: scale, y: scale)

        return country.path.applying(transform)
    }
}

/// Силуэт со свечением в цвете флага — «обложка» страны.
struct CountryHeroArt: View {

    let country: Country
    let status: TravelStatus?
    var accent: Color = DS.Color.accent

    private var colors: [Color] {
        DS.StatusColor.colors(status ?? .visited, flagHue: country.flagHue)
    }

    var body: some View {
        ZStack {
            CountrySilhouette(country: country)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: colors[0].opacity(0.9), radius: 30)
                .shadow(color: colors[0].opacity(0.5), radius: 60)

            CountrySilhouette(country: country)
                .stroke(.white.opacity(0.55), lineWidth: 1.2)
        }
        .accessibilityHidden(true)
    }
}
