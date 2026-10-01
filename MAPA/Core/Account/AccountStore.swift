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
        self.profile = storage.load() ?? Profile.local()
        if storage.load() == nil {
            storage.save(profile)
        }
    }

    /// Можно ли вообще входить. Пока сервера нет — нет и входа,
    /// и честнее сказать это прямо, чем показать кнопку, которая не работает.
    var canSignIn: Bool { auth.isAvailable }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != profile.name else { return }
        profile.name = trimmed
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
    func load() -> Profile?
    func save(_ profile: Profile)
}

struct FileProfileStorage: ProfileStorage {

    private let fileURL: URL

    init(fileName: String = "profile.json") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(fileName)
    }

    func load() -> Profile? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Profile.self, from: data)
    }

    func save(_ profile: Profile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
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
