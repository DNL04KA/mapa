import Foundation

/// Числительные: «1 страна», «2 страны», «5 стран».
///
/// Правила склонения не зашиты в код, а лежат в `Localizable.stringsdict`,
/// и выбирает их система. Так и должно быть: в русском пять форм поведения
/// (1, 2–4, 5–20, 21, 111), в английском две, в арабском шесть. Считать это
/// руками — значит однажды написать «5 страна» на языке, которого не знаешь.
enum Plural {

    static func countries(_ count: Int) -> String { localized("plural.countries", count) }
    static func continents(_ count: Int) -> String { localized("plural.continents", count) }
    static func cities(_ count: Int) -> String { localized("plural.cities", count) }
    static func days(_ count: Int) -> String { localized("plural.days", count) }
    static func points(_ count: Int) -> String { localized("plural.points", count) }
    static func places(_ count: Int) -> String { localized("plural.places", count) }
    static func reviews(_ count: Int) -> String { localized("plural.reviews", count) }

    private static func localized(_ key: String, _ count: Int) -> String {
        String(format: NSLocalizedString(key, comment: ""), count)
    }
}
