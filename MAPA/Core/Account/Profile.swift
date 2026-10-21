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
    /// Никнейм — адрес человека в сообществе. `nil`, пока профиль не
    /// создан: приложением можно пользоваться и без него, и до появления
    /// второго человека никнейм ни к чему.
    var handle: String?
    var name: String
    var email: String?
    var avatar: Avatar
    let provider: AuthProvider
    let createdAt: Date

    var isLocal: Bool { provider == .local }

    /// Профиль создан: у человека есть никнейм, по которому к нему можно
    /// зайти. Без него он просто отмечает свою карту, и это нормально.
    var isCreated: Bool { handle?.isEmpty == false }

    /// Как человека зовут на экране. Пока он не назвался — «Путешественник»
    /// на языке телефона.
    ///
    /// Имя по умолчанию не хранится, а подставляется при показе: записанное
    /// один раз при первом запуске, оно застыло бы на том языке и осталось
    /// бы «Путешественником» на английском телефоне.
    var displayName: String {
        name.isEmpty ? String(localized: "Путешественник") : name
    }

    /// Первая буква имени — пока нет аватара, показываем её.
    var initial: String {
        String(displayName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    static func local() -> Profile {
        let id = "local-" + UUID().uuidString
        return Profile(
            id: id,
            handle: nil,
            name: "",
            email: nil,
            avatar: .suggested(for: id),
            provider: .local,
            createdAt: Date()
        )
    }
}

/// Никнейм: правила те же, что на сервере.
///
/// Проверять их здесь, а не только в базе, нужно затем, чтобы человек
/// узнавал об ошибке во время набора, а не после отправки формы. Правило
/// одно и то же в двух местах — и в `supabase/schema.sql` стоит ровно это
/// выражение.
enum Handle {

    static let minLength = 3
    static let maxLength = 20

    /// Что не так с никнеймом. `nil` — всё в порядке.
    ///
    /// Проверяем то написание, в котором никнейм будет храниться, а не то,
    /// что человек набрал: «@Sato» и «sato» — один и тот же никнейм, и
    /// отвергать первый только за заглавную букву было бы придирками.
    static func problem(with handle: String) -> String? {
        let value = normalized(handle)
        if value.count < minLength {
            return String(localized: "Не короче трёх знаков")
        }
        if value.count > maxLength {
            return String(localized: "Не длиннее двадцати знаков")
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        if value.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return String(localized: "Только латиница, цифры и _")
        }
        return nil
    }

    static func isValid(_ handle: String) -> Bool { problem(with: handle) == nil }

    /// Привести к тому виду, в каком никнейм хранится: без собачки,
    /// строчными. Человек набирает как привык, а хранится одно написание.
    static func normalized(_ handle: String) -> String {
        handle.trimmingCharacters(in: CharacterSet(charactersIn: " @")).lowercased()
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
