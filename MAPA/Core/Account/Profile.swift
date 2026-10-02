import Foundation

/// Кто ты в приложении.
///
/// Профиль есть всегда, даже без интернета и без входа: карту ты отмечаешь
/// для себя, и требовать регистрацию до того, как человек хоть что-то увидел,
/// — вернейший способ его потерять. Поэтому до входа профиль местный, а вход
/// нужен ровно тогда, когда появляется второй человек: чтобы опубликовать
/// маршрут, сохранить чужой или перенести свою карту на новый телефон.
struct Profile: Equatable, Codable {

    /// Идентификатор. У местного профиля свой, у серверного — выданный
    /// сервером. При первом входе местные данные переезжают на серверный.
    let id: String
    var name: String
    var email: String?
    var avatar: Avatar
    let provider: AuthProvider
    let createdAt: Date

    var isLocal: Bool { provider == .local }

    /// Первая буква имени — пока нет аватара, показываем её.
    var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    static func local() -> Profile {
        let id = "local-" + UUID().uuidString
        return Profile(
            id: id,
            name: String(localized: "Путешественник"),
            email: nil,
            avatar: .suggested(for: id),
            provider: .local,
            createdAt: Date()
        )
    }
}

/// Чем человек вошёл.
///
/// `local` — ещё никак: профиль живёт только на этом телефоне.
enum AuthProvider: String, Codable, CaseIterable {
    case local
    case apple
    case google
    case email

    var title: String {
        switch self {
        case .local:  return String(localized: "Только на этом телефоне")
        case .apple:  return String(localized: "Apple")
        case .google: return String(localized: "Google")
        case .email:  return String(localized: "Почта")
        }
    }

    /// Значок для кнопки входа.
    var icon: String {
        switch self {
        case .local:  return "iphone"
        case .apple:  return "apple.logo"
        case .google: return "g.circle.fill"
        case .email:  return "envelope.fill"
        }
    }
}
