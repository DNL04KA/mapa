import Foundation

/// Адрес сервера и ключ для него.
///
/// Лежит в `Supabase.plist`, которого в репозитории нет и быть не должно:
/// ключ привязан к конкретному проекту, и класть его в общий код — значит
/// однажды выложить его в открытый доступ вместе с исходниками.
///
/// Пока файла нет, приложение работает целиком на телефоне: карта, маршруты,
/// оценки — всё своё. Не хватает ровно того, для чего нужен второй человек.
struct BackendConfig: Equatable {

    let url: URL
    let anonKey: String

    /// `nil`, если сервер ещё не подключён.
    static let current: BackendConfig? = load()

    static var isConfigured: Bool { current != nil }

    private static func load() -> BackendConfig? {
        guard let path = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: path),
              let plist = try? PropertyListSerialization
                  .propertyList(from: data, format: nil) as? [String: String],
              let raw = plist["url"], let url = URL(string: raw),
              let key = plist["anonKey"], !key.isEmpty
        else { return nil }
        return BackendConfig(url: url, anonKey: key)
    }
}
