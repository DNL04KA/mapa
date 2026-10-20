import SwiftUI

/// Аватарка-кусочек карты.
///
/// Пейзажи и значки умеет нарисовать любое приложение. А вот это — только
/// наше: в кружке лежит настоящий кусок мировой карты, и страна в нём
/// закрашена цветом своего флага. Тот же контур, который человек трогает
/// пальцем на большой карте, и те же цвета — аватарка оказывается частью
/// приложения, а не картинкой, принесённой со стороны.
///
/// Двенадцать мест выбраны за узнаваемость силуэта: Италию, Японию и
/// Исландию узнают по форме, не читая подписи.
/// Страны, чьи очертания узнаются с одного взгляда. Список вне вида:
/// по нему считают номера и там, где до интерфейса дело не доходит.
enum AvatarPlaces {
    static let countries = [
        // Греция и Индонезия отсюда убраны: в кружке они превращаются
        // в пятно из островов. Силуэт должен узнаваться без подписи.
        "ITA", "JPN", "ISL", "IND",
        "NOR", "BRA", "EGY", "NZL",
        "ESP", "TUR", "AUS", "CHL",
    ]

    static var count: Int { countries.count }

    static func id(at index: Int) -> String {
        countries[((index % count) + count) % count]
    }
}

@MainActor
struct AvatarPlace: View {

    let index: Int
    var size: CGFloat = 64

    static var count: Int { AvatarPlaces.count }

    private var id: String { AvatarPlaces.id(at: index) }

    var body: some View {
        let geometry = WorldAtlas.shared.geometry
        let country = geometry?.country(id: id)

        Canvas { context, bounds in
            let rect = CGRect(origin: .zero, size: bounds)
            context.clip(to: Path(ellipseIn: rect))
            draw(in: &context, rect: rect, geometry: geometry, country: country)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: max(1, size * 0.022))
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, rect: CGRect,
                      geometry: WorldGeometry?, country: Country?) {
        // Вода — всегда, даже если карта ещё не загрузилась: пустой серый
        // кружок выглядит поломкой, а тёмная вода — замыслом.
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x16314F), Color(hex: 0x0A1A2C)]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY),
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))

        guard let geometry, let country else { return }

        // Рамка кадра: страна занимает чуть больше половины кружка, вокруг
        // остаются соседи — иначе силуэт висит в пустоте и не читается.
        let box = country.mainBounds
        let span = max(box.width, box.height) / 0.52
        let scale = rect.width / span
        let centre = CGPoint(x: box.midX, y: box.midY)

        var map = context
        map.translateBy(x: rect.midX, y: rect.midY)
        map.scaleBy(x: scale, y: scale)
        map.translateBy(x: -centre.x, y: -centre.y)

        // Сетка параллелей и меридианов — тихая, как на самой карте.
        let step = 10.0 / 360.0
        var grid = Path()
        var line = (centre.x - span).rounded(.down)
        while line < centre.x + span {
            grid.move(to: CGPoint(x: line, y: centre.y - span))
            grid.addLine(to: CGPoint(x: line, y: centre.y + span))
            line += step
        }
        var row = (centre.y - span).rounded(.down)
        while row < centre.y + span {
            grid.move(to: CGPoint(x: centre.x - span, y: row))
            grid.addLine(to: CGPoint(x: centre.x + span, y: row))
            row += step
        }
        map.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 0.6 / scale)

        // Суша вокруг — одним тоном: она здесь фон, а не содержание.
        let window = CGRect(x: centre.x - span / 2, y: centre.y - span / 2,
                            width: span, height: span).insetBy(dx: -span / 4, dy: -span / 4)
        for neighbour in geometry.countries where neighbour.id != id {
            guard neighbour.bounds.intersects(window) else { continue }
            map.fill(neighbour.path, with: .color(Color(hex: 0x22304A)))
        }

        // Сама страна — в цвете своего флага, со свечением по контуру.
        let tint = country.flagHue.map { Color(hue: $0, saturation: 0.72, brightness: 0.95) }
            ?? Color(hex: 0x6C5CFF)
        map.fill(country.path, with: .color(tint))
        map.stroke(country.path, with: .color(.white.opacity(0.75)), lineWidth: 1.2 / scale)
    }
}

/// Загруженная карта мира, доступная всему приложению.
///
/// Геометрия весит двести килобайт и разбирается полсекунды — второй раз
/// читать её ради аватарки незачем. Карта кладёт сюда то, что уже
/// загрузила, аватарки берут готовое. Если ещё не загрузилось, кружок
/// рисует воду: это честнее, чем ждать с пустым экраном.
@MainActor
final class WorldAtlas {
    static let shared = WorldAtlas()
    private(set) var geometry: WorldGeometry?

    func use(_ geometry: WorldGeometry) {
        self.geometry = geometry
    }
}
