import Foundation

/// Что сейчас с поездкой.
///
/// Раньше маршрут показывал все свои лица разом: оценку и отзыв у плана,
/// в который ещё не съездил, галочки «пройдено» у поездки, до которой три
/// месяца. Под одним словом жили три разные вещи — мечта, план и
/// воспоминание, — и экран не умел выбрать, какая из них перед ним.
///
/// Состояние ставит человек. Приложение умеет подсказать — даты для этого
/// у него есть, — но не переключает само: поездку могли отменить, перенести
/// или просто не поехать, и узнать об этом из календаря нельзя.
enum JourneyStatus: String, Codable, CaseIterable, Identifiable, Sendable {

    /// Набросок: города есть, решения нет.
    case draft
    /// Решено и назначено.
    case planned
    /// Идёт прямо сейчас.
    case inProgress
    /// Съездил.
    case completed
    /// Не состоялась. Маршрут остаётся — к нему возвращаются.
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft:      return String(localized: "Черновик")
        case .planned:    return String(localized: "Запланирован")
        case .inProgress: return String(localized: "Идёт сейчас")
        case .completed:  return String(localized: "Пройден")
        case .cancelled:  return String(localized: "Отменён")
        }
    }

    var icon: String {
        switch self {
        case .draft:      return "pencil.line"
        case .planned:    return "calendar"
        case .inProgress: return "figure.walk"
        case .completed:  return "checkmark.seal.fill"
        case .cancelled:  return "xmark.circle"
        }
    }

    /// Порядок в списке: сначала то, что происходит, потом то, что
    /// впереди, и только потом прошлое и неслучившееся.
    var listOrder: Int {
        switch self {
        case .inProgress: return 0
        case .planned:    return 1
        case .draft:      return 2
        case .completed:  return 3
        case .cancelled:  return 4
        }
    }

    /// Поездка уже позади.
    var isPast: Bool { self == .completed || self == .cancelled }
}
