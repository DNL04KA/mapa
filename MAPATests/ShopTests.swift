import StoreKitTest
import XCTest
@testable import MAPA

/// Покупка MAPA+.
///
/// Проверять покупку глазами нельзя: в симуляторе, запущенном из
/// командной строки, витрины нет вовсе, а нажимать «купить» руками перед
/// каждым выпуском — верный способ однажды выпустить приложение, где
/// кнопка не работает. `SKTestSession` даёт настоящую витрину из файла
/// `MAPA.storekit` прямо в тесте.
@MainActor
final class ShopTests: XCTestCase {

    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "MAPA")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    override func tearDown() {
        session = nil
    }

    func testЦенаПриходитИзВитрины() async throws {
        let shop = Shop()
        await shop.load()

        guard case let .ready(price) = shop.state else {
            return XCTFail("витрина не ответила: \(shop.state)")
        }
        XCTAssertFalse(price.isEmpty)
        XCTAssertFalse(shop.isPlus, "без покупки платное закрыто")
    }

    func testПокупкаОткрываетПлатное() async throws {
        let shop = Shop()
        await shop.load()
        await shop.buy()

        XCTAssertTrue(shop.isPlus, "после покупки MAPA+ должен быть открыт")
        XCTAssertNil(shop.failure, "успешная покупка не сообщает об ошибке")
    }

    func testВозвратЗакрываетПлатноеОбратно() async throws {
        let shop = Shop()
        await shop.load()
        await shop.buy()
        XCTAssertTrue(shop.isPlus)

        // Деньги вернули — доступ пропадает. Если этого не делать,
        // приложение раздаёт платное бесплатно и без следов.
        try session.refundTransaction(identifier: UInt(session.allTransactions().first!.identifier))

        // Возврат доезжает не мгновенно: ждём, но не вечно.
        for _ in 0..<30 where shop.isPlus {
            try await Task.sleep(nanoseconds: 100_000_000)
            await shop.refresh()
        }
        XCTAssertFalse(shop.isPlus, "после возврата платное снова закрыто")
    }

    func testНастройкиПускаютКПлатномуТолькоПослеПокупки() {
        let defaults = UserDefaults(suiteName: "shop-tests")!
        defaults.removePersistentDomain(forName: "shop-tests")
        let settings = AppSettings(defaults: defaults)

        let paid = MapSurface.premium.first!
        XCTAssertFalse(settings.select(paid), "без покупки платное полотно не выбирается")
        XCTAssertNotEqual(settings.surface.id, paid.id)

        settings.isPlus = true
        XCTAssertTrue(settings.select(paid), "после покупки выбирается как обычное")
        XCTAssertEqual(settings.surface.id, paid.id)
    }
}
