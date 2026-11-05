import Foundation
import SwiftUI

/// Профиль и вход.
///
/// Одно место, которое знает, кто ты сейчас. Хранилище подменяемое — тот же
/// приём, что у карты и маршрутов: протокол, за которым сегодня файл на
/// телефоне, а завтра Supabase. Благодаря этому экран профиля пишется и
/// проверяется до того, как появится сервер, и переключение не потребует
/// править интерфейс.
@MainActor
final class AccountStore: ObservableObject {

    @Published private(set) var profile: Profile
    @Published private(set) var state: State = .idle
    /// Профиль не прочитался, и запись в его файл остановлена.
    /// Тот же замок, что у карты и маршрутов, и по той же причине.
    @Published private(set) var failure: StorageFailure?

    enum State: Equatable {
        case idle
        case working
        /// Текст показываем человеку, поэтому он на его языке.
        case failed(String)
    }

    private let storage: ProfileStorage
    private let auth: AuthService

    init(storage: ProfileStorage = FileProfileStorage(),
         auth: AuthService = UnavailableAuthService()) {
        self.storage = storage
        self.auth = auth

        // Файл профиля читается так же, как карта и маршруты: не вышло —
        // значит не пишем. Имя, никнейм и аватарка потерялись бы тише
        // всего, а восстановить их потом было бы неоткуда.
        let stored: Profile?
        do {
            stored = try storage.load()
        } catch {
            stored = nil
            self.failure = (error as? StorageFailure) ?? .unreadable
        }

        self.profile = stored ?? Profile.local()
        if stored == nil, failure == nil {
            storage.save(profile)
        } else if stored != nil, Self.defaultNames.contains(profile.name) {
            // Раньше имя по умолчанию записывалось в файл, и на английском
            // телефоне человек видел «Путешественник». Стираем его один
            // раз: пустое имя показывается на языке телефона.
            profile.name = ""
            storage.save(profile)
        }
    }

    /// Имена, которые когда-то записывались как «ещё не назвался».
    private static let defaultNames: Set<String> = ["Путешественник", "Traveller"]

    /// Можно ли вообще входить. Пока сервера нет — нет и входа,
    /// и честнее сказать это прямо, чем показать кнопку, которая не работает.
    var canSignIn: Bool { auth.isAvailable }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != profile.name, failure == nil else { return }
        profile.name = trimmed
        storage.save(profile)
    }

    /// Создать профиль: никнейм и имя.
    ///
    /// Пока сервера нет, профиль остаётся местным, и занятость никнейма
    /// проверить не у кого. Поэтому здесь только правила написания, а
    /// «такой уже есть» появится вместе с регистрацией — иначе пришлось
    /// бы обещать уникальность, которую мы не можем обеспечить.
    @discardableResult
    func createProfile(handle: String, name: String) -> Bool {
        guard Handle.isValid(handle), failure == nil else { return false }
        profile.handle = Handle.normalized(handle)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { profile.name = trimmed }
        storage.save(profile)
        return true
    }

    #if DEBUG
    /// Снять экран «профиля ещё нет» на телефоне, где он уже создан.
    func forgetHandleForScreenshot() {
        profile.handle = nil
    }
    #endif

    /// Принять профиль из копии.
    ///
    /// Именно заменить, а не слить: человек восстанавливает копию, чтобы
    /// вернуть то состояние целиком. Идентификатор берётся из копии —
    /// это тот же человек, просто на другом телефоне.
    func restore(_ restored: Profile) {
        // Копия — это и есть ответ на «файл не прочитался»: человек принёс
        // целые данные, и запись снова разрешена.
        failure = nil
        profile = restored
        storage.save(restored)
    }

    func setAvatar(_ avatar: Avatar) {
        guard avatar != profile.avatar, failure == nil else { return }
        // Старое своё фото удаляем сразу: иначе в папке копятся снимки,
        // на которые уже никто не смотрит.
        if case let .photo(old) = profile.avatar, case .photo(let new) = avatar, old != new {
            PhotoStore.avatars.delete(id: old)
        } else if case let .photo(old) = profile.avatar {
            PhotoStore.avatars.delete(id: old)
        }
        profile.avatar = avatar
        storage.save(profile)
    }

    func signIn(with provider: AuthProvider) async {
        state = .working
        do {
            let signed = try await auth.signIn(with: provider)
            profile = signed
            storage.save(signed)
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func signOut() async {
        state = .working
        try? await auth.signOut()
        // Выход не стирает карту: отметки сделаны на этом телефоне и
        // принадлежат человеку, а не сеансу.
        profile = Profile.local()
        storage.save(profile)
        state = .idle
    }
}

// MARK: - Хранилище профиля

protocol ProfileStorage {
    /// `nil` — профиля ещё нет, это первый запуск.
    /// Ошибка — файл есть, но прочитать его не вышло; тогда писать поверх
    /// нельзя, там имя, никнейм и аватарка человека.
    func load() throws -> Profile?
    func save(_ profile: Profile)
}

/// То, что лежит в файле профиля.
///
/// Первая версия писала профиль голым, без обёртки и без номера формата —
/// и это оказалось единственным хранилищем без него. Такой файл читается
/// по-прежнему и переписывается в новом виде при первом же изменении
/// профиля: миграция здесь не требует ничего от человека.
private struct ProfileSnapshot: Codable {
    var version: Int
    var profile: Profile
    var updatedAt: Date

    static let currentVersion = 2
}

struct FileProfileStorage: ProfileStorage {

    private let fileURL: URL

    init(fileName: String = "profile.json") {
        // Как в остальных хранилищах: пустой список каталогов — это не
        // повод падать на запуске, а повод уйти во временную папку.
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(fileName)
    }

    /// Чтение остаётся на главном акторе осознанно: профиль нужен в
    /// инициализаторе вьюмодели, до первого кадра, а в файле — несколько
    /// сотен байт. Асинхронность здесь дала бы экран без имени и аватарки
    /// на один кадр, и ради этого не стоит.
    func load() throws -> Profile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else {
            throw StorageFailure.unreadable
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let version = SchemaProbe.version(in: data) {
            guard version <= ProfileSnapshot.currentVersion else {
                throw StorageFailure.futureVersion(found: version,
                                                   supported: ProfileSnapshot.currentVersion)
            }
            guard let snapshot = try? decoder.decode(ProfileSnapshot.self, from: data) else {
                throw StorageFailure.unreadable
            }
            return snapshot.profile
        }

        // Без номера формата — значит первая версия, профиль записан голым.
        guard let old = try? decoder.decode(Profile.self, from: data) else {
            throw StorageFailure.unreadable
        }
        return old
    }

    /// А запись уходит с главного актора, как и в остальных хранилищах:
    /// её результата никто не ждёт, а случается она на каждое изменение
    /// профиля — имя, аватарка, никнейм, вход.
    func save(_ profile: Profile) {
        let snapshot = ProfileSnapshot(version: ProfileSnapshot.currentVersion,
                                       profile: profile,
                                       updatedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        let url = fileURL
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Хранилище для превью и тестов: ничего не пишет.
///
/// Такое же, как `EphemeralRouteStorage` и `EphemeralTravelLogStorage` —
/// по правилу «протокол + файловая реализация + эфемерная».
struct EphemeralProfileStorage: ProfileStorage {
    var initial: Profile?
    func load() throws -> Profile? { initial }
    func save(_ profile: Profile) {}
}

// MARK: - Вход

protocol AuthService {
    var isAvailable: Bool { get }
    func signIn(with provider: AuthProvider) async throws -> Profile
    func signOut() async throws
}

/// Пока сервер не подключён.
///
/// Не подделывает вход и не показывает «успешно вошли» — просто сообщает,
/// что входить некуда. Нарисовать работающий с виду экран входа, за которым
/// ничего нет, было бы хуже, чем честно его не иметь.
struct UnavailableAuthService: AuthService {

    var isAvailable: Bool { BackendConfig.isConfigured }

    func signIn(with provider: AuthProvider) async throws -> Profile {
        throw AuthError.backendNotConfigured
    }

    func signOut() async throws {}
}

enum AuthError: LocalizedError {
    case backendNotConfigured

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return String(localized: "Сервер ещё не подключён")
        }
    }
}
