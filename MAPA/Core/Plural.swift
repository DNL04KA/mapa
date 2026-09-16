import Foundation

/// Русские числительные: «1 страна», «2 страны», «5 стран».
///
/// `NumberFormatter` такого не умеет, а строки вида «5 страна(ы)»
/// сразу выдают, что приложение делали не для людей.
enum Plural {

    static func format(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        "\(count) \(word(count, one, few, many))"
    }

    static func word(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let hundred = abs(count) % 100
        let ten = hundred % 10

        // 11–14 — исключение: «11 стран», а не «11 страна».
        if hundred >= 11 && hundred <= 14 { return many }
        if ten == 1 { return one }
        if ten >= 2 && ten <= 4 { return few }
        return many
    }

    static func countries(_ count: Int) -> String {
        format(count, "страна", "страны", "стран")
    }

    static func continents(_ count: Int) -> String {
        format(count, "континент", "континента", "континентов")
    }
}
