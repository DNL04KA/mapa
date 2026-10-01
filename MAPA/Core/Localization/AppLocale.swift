import Foundation

/// На каком языке приложение говорит прямо сейчас.
///
/// Берём не язык системы, а то, что система **выбрала из наших** переводов:
/// у человека в iPhone может стоять французский, которого у нас нет, и тогда
/// приложение честно говорит по-русски. `preferredLocalizations` возвращает
/// именно это — и оно же меняется, когда язык переключают в Настройках
/// конкретного приложения.
enum AppLocale {

    static var isRussian: Bool {
        (Bundle.main.preferredLocalizations.first ?? "ru").hasPrefix("ru")
    }
}

public extension Country {
    /// Имя страны на языке приложения.
    ///
    /// Английские названия уже лежат в данных Natural Earth, поэтому второй
    /// язык географии достался бесплатно. Для поиска по каталогам —
    /// достопримечательности, фотографии — по-прежнему нужен `nameRU`:
    /// это ключ, а не подпись, и переводить его нельзя.
    var displayName: String { AppLocale.isRussian ? nameRU : name }
}

public extension City {
    var displayName: String { AppLocale.isRussian ? nameRU : name }
}

public extension Continent {
    var title: String {
        switch self {
        case .africa:       return String(localized: "Африка")
        case .asia:         return String(localized: "Азия")
        case .europe:       return String(localized: "Европа")
        case .northAmerica: return String(localized: "Северная Америка")
        case .southAmerica: return String(localized: "Южная Америка")
        case .oceania:      return String(localized: "Океания")
        case .antarctica:   return String(localized: "Антарктида")
        }
    }
}
