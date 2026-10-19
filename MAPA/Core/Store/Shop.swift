import Foundation
import StoreKit

/// Покупка MAPA+.
///
/// Одна покупка навсегда, а не подписка. Приложение не требует серверов и
/// не тратит деньги каждый месяц: брать за это подписку значило бы брать
/// за воздух. Куплено один раз — полотна и палитры открыты навсегда и на
/// всех устройствах того же Apple ID.
///
/// Правда о состоянии: пока в App Store Connect нет зарегистрированного
/// товара, StoreKit отдаёт пустой список. Чтобы покупку можно было
/// собрать и проверить до этого, рядом лежит `MAPA.storekit` — локальная
/// витрина для симулятора. Это тестовый режим, настоящих денег в нём нет,
/// и приложение об этом прямо говорит на экране.
@MainActor
final class Shop: ObservableObject {

    /// Идентификатор товара. Тот же самый придётся завести в App Store
    /// Connect — иначе покупка не найдётся.
    static let productID = "com.mapa.app.plus"

    enum State: Equatable {
        case loading
        /// Витрина не отвечает: нет сети или товар ещё не заведён.
        case unavailable
        case ready(price: String)
    }

    @Published private(set) var state: State = .loading
    /// Куплено. Единственный источник правды о доступе к платному.
    @Published private(set) var isPlus = false
    /// Покупка идёт — кнопку надо погасить, иначе человек нажмёт дважды.
    @Published private(set) var isBuying = false
    /// Последняя ошибка, которую стоит показать. Отмена покупки ошибкой
    /// не считается: человек сам передумал, и сообщать ему об этом незачем.
    @Published var failure: String?

    private var product: Product?
    private var updates: Task<Void, Never>?

    init() {
        // Чужие покупки (другое устройство, возврат, семейный доступ)
        // приходят сюда же — поэтому слушаем до конца жизни приложения.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let transaction = try? update.payloadValue else { continue }
                await transaction.finish()
                await self?.refresh()
            }
        }
    }

    deinit { updates?.cancel() }

    func load() async {
        await refresh()
        do {
            let products = try await Product.products(for: [Self.productID])
            guard let product = products.first else {
                state = .unavailable
                return
            }
            self.product = product
            state = .ready(price: product.displayPrice)
        } catch {
            state = .unavailable
        }
    }

    /// Что из купленного действует прямо сейчас.
    func refresh() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? entitlement.payloadValue,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPlus = owned
    }

    func buy() async {
        guard let product, !isBuying else { return }
        isBuying = true
        defer { isBuying = false }

        do {
            switch try await product.purchase() {
            case let .success(verification):
                let transaction = try verification.payloadValue
                await transaction.finish()
                await refresh()
            case .userCancelled:
                break
            case .pending:
                // Покупка ждёт подтверждения родителя — это не ошибка,
                // но и не успех: придёт в Transaction.updates.
                failure = NSLocalizedString("Покупка ждёт подтверждения", comment: "")
            @unknown default:
                break
            }
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Восстановить покупку на новом телефоне.
    func restore() async {
        isBuying = true
        defer { isBuying = false }
        try? await AppStore.sync()
        await refresh()
        if !isPlus {
            failure = NSLocalizedString("Покупка не найдена", comment: "")
        }
    }
}
