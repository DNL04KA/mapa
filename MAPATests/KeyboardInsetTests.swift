import XCTest
import UIKit
@testable import MAPA

/// Клавиатура и панель.
///
/// Проверять это на экране неоткуда: снимок симулятора показывает
/// клавиатуру не всегда, а ошибка здесь стоит дорого — панель профиля
/// уезжает под клавиатуру вместе с кнопкой «Готово», и человек печатает
/// вслепую. Поэтому проверяем сам счётчик высоты.
@MainActor
final class KeyboardInsetTests: XCTestCase {

    func testВысотаБерётсяИзУведомления() {
        let inset = KeyboardInset()
        XCTAssertEqual(inset.height, 0, "пока клавиатуры нет — нулевой отступ")

        let screen = UIScreen.main.bounds
        let keyboard = CGRect(x: 0, y: screen.height - 300, width: screen.width, height: 300)
        post(UIResponder.keyboardWillChangeFrameNotification, frame: keyboard)

        XCTAssertEqual(inset.height, 300, accuracy: 0.5)
    }

    func testУехавшаяКлавиатураНеПоднимаетПанель() {
        let inset = KeyboardInset()
        let screen = UIScreen.main.bounds

        // Клавиатура уезжает за нижний край: её верх ниже экрана.
        post(UIResponder.keyboardWillChangeFrameNotification,
             frame: CGRect(x: 0, y: screen.height + 50, width: screen.width, height: 300))
        XCTAssertEqual(inset.height, 0, "отрицательный отступ поднял бы панель в воздух")

        post(UIResponder.keyboardWillChangeFrameNotification,
             frame: CGRect(x: 0, y: screen.height - 300, width: screen.width, height: 300))
        XCTAssertGreaterThan(inset.height, 0)

        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification,
                                        object: nil)
        XCTAssertEqual(inset.height, 0, "клавиатура ушла — отступ вернулся")
    }

    private func post(_ name: Notification.Name, frame: CGRect) {
        NotificationCenter.default.post(
            name: name,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)]
        )
    }
}
