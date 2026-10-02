import SwiftUI

/// Аватарка.
///
/// Три вида: значок из набора, своё фото и картинка, пришедшая вместе с
/// входом через Apple или Google. Набор сделан не картинками, а значками
/// в цвете — это не экономия, а осознанный выбор:
///
/// — рисованные лица пришлось бы рисовать, и они разошлись бы по стилю
///   с остальным приложением уже на второй неделе;
/// — значок системного набора одинаково чёткий на любом экране и сам
///   умеет жить в светлой и тёмной теме;
/// — приложение про путешествия, и компас с палаткой говорят о человеке
///   больше, чем безликий кружок с буквой.
enum Avatar: Equatable, Codable, Hashable {

    /// Значок из набора: имя символа и место цвета в палитре.
    case symbol(String, Int)
    /// Своё фото из галереи — идентификатор файла.
    case photo(String)
    /// Пришло вместе с входом.
    case remote(URL)

    static let `default` = Avatar.symbol(Catalog.symbols[0], 0)

    /// Устойчивая аватарка по идентификатору человека.
    ///
    /// Нужна, чтобы у нового профиля не было пустого кружка, и чтобы она
    /// не менялась при каждом запуске. Считаем сами, а не через `hashValue`:
    /// у Swift он засеивается заново на каждый старт.
    static func suggested(for id: String) -> Avatar {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        let symbol = Catalog.symbols[Int(hash % UInt64(Catalog.symbols.count))]
        let color = Int((hash >> 16) % UInt64(Catalog.colors.count))
        return .symbol(symbol, color)
    }

    enum Catalog {
        /// Двенадцать значков про дорогу. Больше не нужно: выбор из тридцати
        /// превращается из удовольствия в задачу.
        static let symbols = [
            "safari",               // компас
            "airplane",
            "mountain.2.fill",
            "tent.fill",
            "backpack.fill",
            "camera.fill",
            "binoculars.fill",
            "map.fill",
            "sailboat.fill",
            "sunrise.fill",        // sun.horizon появился только в iOS 17
            "building.columns.fill",
            "globe.europe.africa.fill",
        ]

        /// Те же тона, что у палитры «Чернила» на карте, плюс пара тёплых:
        /// аватарка не должна выглядеть из другого приложения.
        static let colors: [Color] = [
            Color(hex: 0x2E4A6B), Color(hex: 0x3F6560), Color(hex: 0x55677A),
            Color(hex: 0x6B7355), Color(hex: 0x7A5B4C), Color(hex: 0x5B5570),
            Color(hex: 0x87764C), Color(hex: 0xB05A3D), Color(hex: 0x3B7370),
            Color(hex: 0x7A4A62),
        ]

        static func color(_ index: Int) -> Color {
            colors[((index % colors.count) + colors.count) % colors.count]
        }
    }
}

/// Кружок с аватаркой.
///
/// Один вид на все случаи: в профиле он 64 пункта, в списке отзывов 28,
/// а рисуется одинаково — иначе они разойдутся по мелочам при первой правке.
struct AvatarView: View {

    let avatar: Avatar
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            switch avatar {
            case let .symbol(name, colorIndex):
                let tint = Avatar.Catalog.color(colorIndex)
                Circle().fill(tint.opacity(0.22))
                Image(systemName: name)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(tint)

            case let .photo(id):
                if let image = PhotoStore.avatars.image(id: id) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    // Файл мог не пережить переустановку — показываем значок,
                    // а не пустой кружок.
                    placeholder
                }

            case let .remote(url):
                Circle().fill(DS.Color.surfaceSunken)
                RemoteImage(url: url)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(DS.Color.surfaceSunken)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(DS.Color.inkTertiary)
        }
    }
}
