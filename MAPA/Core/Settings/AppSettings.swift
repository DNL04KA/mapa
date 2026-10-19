import SwiftUI

/// Настройки приложения.
///
/// `UserDefaults`, а не отдельное хранилище: здесь лежат мелкие
/// пользовательские предпочтения, потеря которых ничего не стоит.
/// Отметки на карте — другое дело, у них своё хранилище с атомарной записью.
@MainActor
final class AppSettings: ObservableObject {

    private enum Key {
        /// Ключ старого формата, когда полотно и палитра были одной темой.
        static let legacyThemeID = "settings.themeID"
        static let surfaceID = "settings.surfaceID"
        static let paletteID = "settings.paletteID"
    }

    @Published private(set) var surface: MapSurface
    @Published private(set) var palette: MapPalette

    /// Куплен ли MAPA+. Ставится магазином при запуске и после покупки;
    /// здесь не хранится — источник правды один, и он в `Shop`.
    @Published var isPlus = false {
        didSet { restoreChoiceIfPaid() }
    }

    var theme: MapTheme { MapTheme(surface: surface, palette: palette) }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Старые установки не выбрасываем: человек уже выбрал себе карту,
        // и обновление приложения не повод вернуть ему чужую.
        let legacy = defaults.string(forKey: Key.legacyThemeID)
        let surfaceID = defaults.string(forKey: Key.surfaceID) ?? legacy ?? MapSurface.night.id
        let paletteID = defaults.string(forKey: Key.paletteID)
            ?? Self.paletteForLegacySurface(surfaceID)

        let storedSurface = MapSurface.surface(id: surfaceID)
        let storedPalette = MapPalette.palette(id: paletteID)

        // Если выбранное вдруг оказалось платным, а покупка не подтверждается —
        // откатываемся на открытое, а не показываем то, за что не заплачено.
        // Выбор при этом остаётся записанным: магазин ответит через
        // мгновение, и `restoreChoiceIfPaid` вернёт человеку его карту.
        surface = storedSurface.isPremium ? .night : storedSurface
        palette = storedPalette.isPremium ? .flags : storedPalette
    }

    /// Вернуть платный выбор, когда покупка подтвердилась.
    ///
    /// Магазин отвечает не мгновенно, и на первом кадре приложение честно
    /// показывает бесплатное полотно. Если окажется, что MAPA+ куплен,
    /// возвращаем то, что человек выбрал, — а не заставляем выбирать снова.
    private func restoreChoiceIfPaid() {
        guard isPlus else { return }
        if let id = defaults.string(forKey: Key.surfaceID) {
            surface = MapSurface.surface(id: id)
        }
        if let id = defaults.string(forKey: Key.paletteID) {
            palette = MapPalette.palette(id: id)
        }
    }

    /// Какой палитрой раньше рисовалось это полотно.
    /// Светлая карта была единственной с подобранными тонами — остальные шли
    /// от флагов.
    private static func paletteForLegacySurface(_ surfaceID: String) -> String {
        surfaceID == MapSurface.paper.id ? MapPalette.ink.id : MapPalette.flags.id
    }

    /// Возвращает `false`, если полотно платное и не куплено — интерфейс
    /// покажет замок.
    @discardableResult
    func select(_ surface: MapSurface) -> Bool {
        guard !surface.isPremium || isPlus else { return false }
        self.surface = surface
        defaults.set(surface.id, forKey: Key.surfaceID)
        return true
    }

    @discardableResult
    func select(_ palette: MapPalette) -> Bool {
        guard !palette.isPremium || isPlus else { return false }
        self.palette = palette
        defaults.set(palette.id, forKey: Key.paletteID)
        return true
    }
}
