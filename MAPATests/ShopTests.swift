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

    private var session: SKTestSession?

    override func setUpWithError() throws {
        let session = try SKTestSession(configurationFileNamed: "MAPA")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        self.session = session
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

        // Право на покупку доезжает через `Transaction.updates`, а не
        // возвращается из `buy()`, — отсюда ожидание. А повтор нужен
        // из-за самой `SKTestSession`: она изредка отвечает на покупку
        // «отменено пользователем», хотя диалоги выключены и отменять
        // некому. Это особенность витрины в тестах, а не кода магазина:
        // при настоящей отмене `failure` остаётся пустым, и отличить
        // одно от другого в тесте нечем.
        await waitForPlus(shop)
        if !shop.isPlus && shop.failure == nil {
            await shop.buy()
            await waitForPlus(shop)
        }

        XCTAssertNil(shop.failure, "успешная покупка не сообщает об ошибке")
        XCTAssertTrue(shop.isPlus,
                      "после покупки MAPA+ должен быть открыт; состояние: \(shop.state), "
                      + "ошибка: \(shop.failure ?? "нет")")
    }

    /// Ждём права на покупку, но не вечно.
    private func waitForPlus(_ shop: Shop) async {
        for _ in 0..<30 where !shop.isPlus {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await shop.refresh()
        }
    }

    func testВозвратЗакрываетПлатноеОбратно() async throws {
        let shop = Shop()
        await shop.load()
        await shop.buy()
        await waitForPlus(shop)
        XCTAssertTrue(shop.isPlus)

        // Деньги вернули — доступ пропадает. Если этого не делать,
        // приложение раздаёт платное бесплатно и без следов.
        let session = try XCTUnwrap(self.session)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: UInt(transaction.identifier))

        // Возврат доезжает не мгновенно: ждём, но не вечно.
        for _ in 0..<30 where shop.isPlus {
            try await Task.sleep(nanoseconds: 100_000_000)
            await shop.refresh()
        }
        XCTAssertFalse(shop.isPlus, "после возврата платное снова закрыто")
    }

    func testНастройкиПускаютКПлатномуТолькоПослеПокупки() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "shop-tests"))
        defaults.removePersistentDomain(forName: "shop-tests")
        let settings = AppSettings(defaults: defaults)

        let paid = try XCTUnwrap(MapSurface.premium.first)
        XCTAssertFalse(settings.select(paid), "без покупки платное полотно не выбирается")
        XCTAssertNotEqual(settings.surface.id, paid.id)

        settings.isPlus = true
        XCTAssertTrue(settings.select(paid), "после покупки выбирается как обычное")
        XCTAssertEqual(settings.surface.id, paid.id)
    }
}
