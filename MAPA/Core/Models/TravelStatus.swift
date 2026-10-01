import SwiftUI

/// Статус страны на карте. Пока это чистое перечисление без хранилища —
/// на 4-м этапе оно станет полем модели SwiftData.
public enum TravelStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case visited   // был
    case living    // живу
    case wishlist  // хочу

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .visited:  return String(localized: "Был")
        case .living:   return String(localized: "Живу")
        case .wishlist: return String(localized: "Хочу")
        }
    }

    public var icon: String {
        switch self {
        case .visited:  return "checkmark.circle.fill"
        case .living:   return "house.fill"
        case .wishlist: return "sparkles"
        }
    }

    /// Короткое пояснение — пригодится в шите выбора на 3-м этапе.
    public var subtitle: String {
        switch self {
        case .visited:  return String(localized: "Уже видел своими глазами")
        case .living:   return String(localized: "Здесь мой дом")
        case .wishlist: return String(localized: "Однажды доберусь")
        }
    }
}
