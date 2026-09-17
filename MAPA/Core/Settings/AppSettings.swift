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
        surface = storedSurface.isPremium ? .night : storedSurface
        palette = storedPalette.isPremium ? .flags : storedPalette
    }

    /// Какой палитрой раньше рисовалось это полотно.
    /// Светлая карта была единственной с подобранными тонами — остальные шли
    /// от флагов.
    private static func paletteForLegacySurface(_ surfaceID: String) -> String {
        surfaceID == MapSurface.paper.id ? MapPalette.ink.id : MapPalette.flags.id
    }

    /// Возвращает `false`, если полотно платное — интерфейс покажет замок.
    @discardableResult
    func select(_ surface: MapSurface) -> Bool {
        guard !surface.isPremium else { return false }
        self.surface = surface
        defaults.set(surface.id, forKey: Key.surfaceID)
        return true
    }

    @discardableResult
    func select(_ palette: MapPalette) -> Bool {
        guard !palette.isPremium else { return false }
        self.palette = palette
        defaults.set(palette.id, forKey: Key.paletteID)
        return true
    }
}
