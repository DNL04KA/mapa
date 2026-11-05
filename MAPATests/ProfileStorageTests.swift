import XCTest
@testable import MAPA

/// Файл профиля: чтение, миграция и замок на запись.
///
/// Профиль теряется тише всего остального: имя, никнейм и аватарка не
/// бросаются в глаза, и человек заметит пропажу через неделю, когда
/// восстанавливать будет уже неоткуда. Раньше нечитаемый файл молча
/// заменялся новым пустым профилем — ровно та же беда, что была с картой.
final class ProfileStorageTests: XCTestCase {

    private var fileName = ""

    private var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(fileName)
    }

    override func setUp() {
        super.setUp()
        fileName = "profile-test-\(UUID().uuidString).json"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func write(_ text: String) {
        let base = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try? Data(text.utf8).write(to: fileURL, options: .atomic)
    }

    private func read() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// Настоящий файл первой версии: профиль записан голым, без обёртки
    /// и без номера формата.
    private let oldProfile = """
    {"id":"6B29FC40-CA47-1067-B31D-00DD010662DA","name":"Никита","handle":"nikita",\
    "avatar":{"face":{"_0":3}},"provider":"local","createdAt":"2026-01-01T10:00:00Z"}
    """

    func testПрофильПервойВерсииЧитается() throws {
        write(oldProfile)
        let storage = FileProfileStorage(fileName: fileName)

        let profile = try XCTUnwrap(try storage.load())
        XCTAssertEqual(profile.name, "Никита")
        XCTAssertEqual(profile.handle, "nikita")
    }

    func testПослеПервойЗаписиФайлПереезжаетНаНовыйФормат() throws {
        write(oldProfile)
        let storage = FileProfileStorage(fileName: fileName)

        let profile = try XCTUnwrap(try storage.load())
        storage.save(profile)

        // Запись уходит с главного актора, поэтому ждём файл.
        let deadline = Date().addingTimeInterval(2)
        while !read().contains("\"version\"") && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(read().contains("\"version\" : 2") || read().contains("\"version\":2"),
                      "старый файл должен переехать в новый формат сам")

        let again = try XCTUnwrap(try storage.load())
        XCTAssertEqual(again.name, "Никита")
        XCTAssertEqual(again.handle, "nikita")
    }

    func testИспорченныйПрофильНеЧитаетсяИНеЗатирается() throws {
        write("{ это не профиль")
        let storage = FileProfileStorage(fileName: fileName)

        XCTAssertThrowsError(try storage.load()) { error in
            XCTAssertEqual(error as? StorageFailure, .unreadable)
        }
        XCTAssertEqual(read(), "{ это не профиль", "файл человека не трогаем")
    }

    func testПрофильБудущейВерсииНеЧитается() throws {
        write(#"{"version":99,"profile":{},"updatedAt":"2026-01-01T10:00:00Z"}"#)
        let storage = FileProfileStorage(fileName: fileName)

        XCTAssertThrowsError(try storage.load()) { error in
            XCTAssertEqual(error as? StorageFailure, .futureVersion(found: 99, supported: 2))
        }
    }

    func testПервыйЗапускЭтоНеОшибка() throws {
        let storage = FileProfileStorage(fileName: fileName)
        XCTAssertNil(try storage.load(), "профиля ещё нет — это нормально")
    }
}

/// Что делает приложение, когда профиль не прочитался.
@MainActor
final class ProfileLockTests: XCTestCase {

    func testПослеСбояЧтенияПрофильНеПерезаписывается() async {
        let storage = BrokenProfileStorage()
        let account = AccountStore(storage: storage)

        XCTAssertEqual(account.failure, .unreadable)
        XCTAssertEqual(storage.saves, 0, "пустой профиль не должен лечь поверх файла")

        account.rename("Новое имя")
        account.setAvatar(.face(7))
        _ = account.createProfile(handle: "nikita", name: "Никита")

        XCTAssertEqual(storage.saves, 0, "пока файл не прочитан, писать нечего и некуда")
    }

    func testВосстановлениеИзКопииСнимаетЗамок() async {
        let storage = BrokenProfileStorage()
        let account = AccountStore(storage: storage)

        var restored = Profile.local()
        restored.name = "Никита"
        account.restore(restored)

        XCTAssertNil(account.failure)
        XCTAssertEqual(account.profile.name, "Никита")
        XCTAssertEqual(storage.saves, 1)
    }
}

private final class BrokenProfileStorage: ProfileStorage {
    private(set) var saves = 0
    func load() throws -> Profile? { throw StorageFailure.unreadable }
    func save(_ profile: Profile) { saves += 1 }
}
