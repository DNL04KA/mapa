import Foundation

/// Как подписаны даты поездки.
///
/// Форматтеры живут здесь по двум причинам. Первая скучная: создание
/// `DateFormatter` стоит дороже, чем кажется, а список маршрутов рисует
/// подписи десятками. Вторая важнее — порядок дня и месяца, разделитель
/// диапазона и сокращения месяцев в каждом языке свои, и собирать строку
/// руками из кусков значит однажды написать «Mar 14 – 26 Mar».
///
/// Главный актор — не перестраховка: форматтеры переиспользуются, а значит
/// это разделяемое изменяемое состояние. Подписи рисует интерфейс, ему
/// главный актор и так родной.
@MainActor
enum TripDateFormat {

    /// Короткая дата: «14 мар», «14 Mar».
    static func day(_ date: Date) -> String {
        formatter(for: "d MMM").string(from: date)
    }

    /// Диапазон: «14–26 марта», «28 фев – 3 мар».
    ///
    /// Схлопывать одинаковый месяц умеет сама система — она же знает, где
    /// ставить тире, а где «–» с пробелами.
    static func range(from: Date, to: Date) -> String {
        interval(for: AppLocale.current).string(from: from, to: to)
    }

    // MARK: - Внутри

    private static var intervals: [String: DateIntervalFormatter] = [:]

    /// Форматтер собирается на каждый язык отдельно, и порядок здесь
    /// важен: смена `locale` сбрасывает шаблон, поэтому язык задаётся
    /// первым. Иначе вместо «14 мар. – 26 мар.» выходит
    /// «14.03.2026—26.03.2026» — год дважды и ни одного слова.
    private static func interval(for locale: Locale) -> DateIntervalFormatter {
        if let ready = intervals[locale.identifier] { return ready }

        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.timeStyle = .none
        formatter.dateTemplate = "d MMM"
        intervals[locale.identifier] = formatter
        return formatter
    }

    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(for template: String) -> DateFormatter {
        let locale = AppLocale.current
        let key = "\(template)|\(locale.identifier)"
        if let ready = cache[key] { return ready }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        cache[key] = formatter
        return formatter
    }
}
