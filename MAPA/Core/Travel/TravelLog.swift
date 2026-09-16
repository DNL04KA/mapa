import Foundation

/// Отметки пользователя на карте.
///
/// Пока это значение в памяти — при перезапуске отметки теряются, и так и задумано:
/// на 4-м этапе внутренности заменит SwiftData, а вызывающий код не изменится.
/// Поэтому здесь нет ни одного упоминания хранилища.
struct TravelLog: Equatable {

    private(set) var statuses: [String: TravelStatus]
    /// Точка отсчёта. Одна на всю карту.
    private(set) var home: HomePlace?

    init(statuses: [String: TravelStatus] = [:], home: HomePlace? = nil) {
        self.statuses = statuses
        self.home = home
    }

    /// Поставить дом. Страна дома автоматически становится «живу»:
    /// нельзя жить где-то и не отметить это на карте.
    mutating func setHome(_ place: HomePlace?) {
        home = place
        if let place {
            statuses[place.countryID] = .living
        }
    }

    func status(for countryID: String) -> TravelStatus? {
        statuses[countryID]
    }

    /// `nil` снимает отметку.
    mutating func set(_ status: TravelStatus?, for countryID: String) {
        if let status {
            statuses[countryID] = status
        } else {
            statuses.removeValue(forKey: countryID)
        }
    }

    /// Идентификаторы стран с конкретным статусом.
    func countryIDs(with status: TravelStatus) -> [String] {
        statuses.compactMap { $0.value == status ? $0.key : nil }
    }

    var markedCount: Int { statuses.count }

    var isEmpty: Bool { statuses.isEmpty }
}
