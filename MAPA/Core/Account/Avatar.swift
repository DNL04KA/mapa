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

    /// Место на карте — номер страны из набора.
    case place(Int)
    /// Пейзаж из набора — номер картинки.
    case scene(Int)
    /// Значок из набора: имя символа и место цвета в палитре.
    /// Остался ради профилей, созданных до пейзажей.
    case symbol(String, Int)
    /// Своё фото из галереи — идентификатор файла.
    case photo(String)
    /// Пришло вместе с входом.
    case remote(URL)

    static let `default` = Avatar.place(0)

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
        return .place(Int(hash % UInt64(AvatarPlaces.count)))
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

        /// Пары цветов, из которых собирается заливка.
        ///
        /// Раньше здесь лежали приглушённые плоские тона, и аватарки
        /// выглядели как серые кружки в списке контактов. Градиент из двух
        /// цветов, белый значок и тонкий ободок дают тот же набор, но он
        /// выглядит нарисованным, а не вычисленным. Цвета — из палитр самой
        /// карты, поэтому аватарка не смотрится из другого приложения.
        static let gradients: [[Color]] = [
            [Color(hex: 0x6C5CFF), Color(hex: 0x9B5CFF)],   // индиго
            [Color(hex: 0x22A7C9), Color(hex: 0x2EE0C2)],   // лагуна
            [Color(hex: 0xE86FD1), Color(hex: 0xFF7A9C)],   // магента
            [Color(hex: 0xF0A33C), Color(hex: 0xE2622F)],   // закат
            [Color(hex: 0x3E6E9E), Color(hex: 0x24606B)],   // море
            [Color(hex: 0x5C7A45), Color(hex: 0x2F5148)],   // лес
            [Color(hex: 0xB08D5F), Color(hex: 0x7A5F42)],   // винтаж
            [Color(hex: 0x55677A), Color(hex: 0x2E3A4A)],   // уголь
            [Color(hex: 0x5FE3B4), Color(hex: 0x22A7C9)],   // мята
            [Color(hex: 0xFF5C7A), Color(hex: 0xC2512F)],   // гранат
        ]

        static func gradient(_ index: Int) -> [Color] {
            gradients[((index % gradients.count) + gradients.count) % gradients.count]
        }

        /// Цвет для случаев, где градиент не нужен, — рамка, подпись.
        static func color(_ index: Int) -> Color {
            gradient(index)[0]
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
            case let .place(index):
                AvatarPlace(index: index, size: size)

            case let .scene(index):
                AvatarScene(index: index, size: size)

            case let .symbol(name, colorIndex):
                let colors = Avatar.Catalog.gradient(colorIndex)
                Circle()
                    .fill(LinearGradient(colors: colors,
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                // Тонкий светлый ободок изнутри: он отделяет аватарку от
                // тёмной панели и даёт ей объём на любом фоне.
                Circle()
                    .strokeBorder(.white.opacity(0.22), lineWidth: max(1, size * 0.02))
                Image(systemName: name)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: colors[1].opacity(0.55), radius: size * 0.06, y: size * 0.02)

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
