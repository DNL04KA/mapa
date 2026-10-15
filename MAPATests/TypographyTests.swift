import SwiftUI
import XCTest
@testable import MAPA

/// Шрифтовая шкала и настройка размера текста на телефоне.
///
/// Проверка нужна потому, что ошибку здесь не видно глазами: шкала из
/// `Font.system(size:)` выглядит правильно ровно до того момента, когда
/// человек увеличит шрифт в настройках — а разработчик этого не делает
/// никогда. Полгода приложение прожило с комментарием «масштабируется
/// Dynamic Type» над шкалой, которая не масштабировалась вовсе.
final class TypographyTests: XCTestCase {

    func testТекстРастётВместеСНастройкой() {
        let body = DS.Font.body
        let normal = body.size(for: .large)
        let huge = body.size(for: .accessibility5)

        XCTAssertEqual(normal, 16, accuracy: 0.5, "обычный размер — базовый")
        XCTAssertGreaterThan(huge, normal * 1.5, "на самом крупном шрифте текст обязан вырасти")
    }

    func testМелкоеРастётБыстрееКрупного() {
        // Подпись обязана догнать читаемый размер, а «2.5 %» и так огромен:
        // если дать ему расти так же, он выдавит с экрана всё остальное.
        let captionGrowth = DS.Font.caption.size(for: .accessibility5) / DS.Font.caption.size
        let heroGrowth = DS.Font.hero.size(for: .accessibility5) / DS.Font.hero.size
        XCTAssertGreaterThan(captionGrowth, heroGrowth)
    }

    func testПотолокРостаСоблюдается() {
        for style in [DS.Font.hero, DS.Font.display, DS.Font.numeral,
                      DS.Font.title, DS.Font.body, DS.Font.caption, DS.Font.micro] {
            let biggest = style.size(for: .accessibility5)
            XCTAssertLessThanOrEqual(biggest, style.size * style.cap + 0.01,
                                     "ступень \(style.size) перерастает свой потолок")
        }
    }

    func testРазмерНеУменьшаетсяСРостомНастройки() {
        // Монотонность: на каждом следующем шаге шрифт не меньше предыдущего.
        let steps: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge,
                                        .xxLarge, .xxxLarge, .accessibility1,
                                        .accessibility2, .accessibility3,
                                        .accessibility4, .accessibility5]
        for style in [DS.Font.body, DS.Font.micro, DS.Font.title] {
            var previous: CGFloat = 0
            for step in steps {
                let size = style.size(for: step)
                XCTAssertGreaterThanOrEqual(size, previous, "шаг \(step) уменьшил шрифт")
                previous = size
            }
        }
    }

    func testКаждойНастройкеСоответствуетСвояКатегорияUIKit() {
        // Перевод в язык UIKit — единственное место, где можно молча
        // промахнуться и получить размер от чужой ступени.
        let pairs: [(DynamicTypeSize, UIContentSizeCategory)] = [
            (.xSmall, .extraSmall), (.large, .large), (.xxxLarge, .extraExtraExtraLarge),
            (.accessibility1, .accessibilityMedium),
            (.accessibility5, .accessibilityExtraExtraExtraLarge)
        ]
        for (size, category) in pairs {
            XCTAssertEqual(size.contentSizeCategory, category)
        }
    }
}
