import SwiftUI

/// То, что SwiftUI интерполирует покадрово для карты.
///
/// Вместо вложенных `AnimatablePair` — свой тип: четыре поля с именами
/// читаются, а `AnimatablePair<CGFloat, AnimatablePair<CGFloat, ...>>` уже нет.
struct MapAnimatableState: VectorArithmetic {

    var zoom: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat
    /// Насколько разлилась заливка только что отмеченной страны, 0…1.
    var bloom: CGFloat

    static var zero: MapAnimatableState {
        MapAnimatableState(zoom: 0, centerX: 0, centerY: 0, bloom: 0)
    }

    static func + (lhs: MapAnimatableState, rhs: MapAnimatableState) -> MapAnimatableState {
        MapAnimatableState(
            zoom: lhs.zoom + rhs.zoom,
            centerX: lhs.centerX + rhs.centerX,
            centerY: lhs.centerY + rhs.centerY,
            bloom: lhs.bloom + rhs.bloom
        )
    }

    static func - (lhs: MapAnimatableState, rhs: MapAnimatableState) -> MapAnimatableState {
        MapAnimatableState(
            zoom: lhs.zoom - rhs.zoom,
            centerX: lhs.centerX - rhs.centerX,
            centerY: lhs.centerY - rhs.centerY,
            bloom: lhs.bloom - rhs.bloom
        )
    }

    mutating func scale(by rhs: Double) {
        zoom *= rhs
        centerX *= rhs
        centerY *= rhs
        bloom *= rhs
    }

    var magnitudeSquared: Double {
        Double(zoom * zoom + centerX * centerX + centerY * centerY + bloom * bloom)
    }
}

/// Отмеченная страна, готовая к отрисовке.
///
/// Рисуются по отдельности, а не общим слитым путём: у соседних стран
/// с одним статусом должны оставаться свои контуры, иначе они сливаются
/// в одно пятно.
struct MarkedCountry: Equatable, Identifiable {
    let id: String
    let path: Path
    let bounds: CGRect
    let status: TravelStatus
    /// Небольшой разброс светлоты, −1…1.
    let tint: Double
    /// Тон флага страны, 0…1.
    let flagHue: Double?
}

/// Всё, что рисуется поверх базовой суши.
struct MapOverlayState: Equatable {

    /// Отмеченные страны в порядке отрисовки: «хочу» внизу, «живу» сверху.
    /// Пересобирается при смене отметок, а не на каждом кадре.
    var marked: [MarkedCountry] = []

    /// Страна, которую прямо сейчас заливает краска.
    var bloom: Bloom?

    /// Страна под открытым шитом — её нужно видеть, пока выбираешь статус.
    var highlight: Path?

    /// Точки открытого маршрута в единичном пространстве, по порядку.
    var routeLine: [CGPoint] = []

    struct Bloom: Equatable {
        let countryID: String
        let path: Path
        let bounds: CGRect
        /// Точка тапа в единичном пространстве — отсюда растекается заливка.
        let origin: CGPoint
        let status: TravelStatus
        let tint: Double
        let flagHue: Double?
    }
}
