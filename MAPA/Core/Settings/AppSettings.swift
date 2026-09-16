import SwiftUI

/// Настройки приложения.
///
/// `UserDefaults`, а не отдельное хранилище: здесь лежат мелкие
/// пользовательские предпочтения, потеря которых ничего не стоит.
/// Отметки на карте — другое дело, у них своё хранилище с атомарной записью.
@MainActor
final class AppSettings: ObservableObject {

    private enum Key {
        static let themeID = "settings.themeID"
    }

    @Published private(set) var theme: MapTheme

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedID = defaults.string(forKey: Key.themeID) ?? MapTheme.default.id
        let stored = MapTheme.theme(id: storedID)
        // Если тема вдруг оказалась платной, а покупка не подтверждается —
        // откатываемся на бесплатную, а не показываем то, за что не заплачено.
        theme = stored.isPremium ? .default : stored
    }

    /// Возвращает `false`, если тема платная — интерфейс покажет замок.
    @discardableResult
    func select(_ theme: MapTheme) -> Bool {
        guard !theme.isPremium else { return false }
        self.theme = theme
        defaults.set(theme.id, forKey: Key.themeID)
        return true
    }
}
