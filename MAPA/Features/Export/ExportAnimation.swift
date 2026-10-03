import SwiftUI

/// Как карта оживает в видео.
///
/// Видео собирается из той же карточки, что и картинка, — ни одной новой
/// вьюхи. Меняются только данные: на кадре показано столько отметок,
/// сколько к этому моменту «проявилось», а процент досчитывается до своего.
/// Так картинка и видео не могут разойтись по виду, что бы я ни правил
/// дальше в карточке.
enum ExportAnimation {

    /// Длительность и частота. Четыре секунды — верхняя граница, после
    /// которой короткое видео перестают досматривать.
    static let fps = 30
    static let revealSeconds = 2.6
    static let holdSeconds = 1.4

    static var frameCount: Int { Int((revealSeconds + holdSeconds) * Double(fps)) }

    /// Доля проявленного на этом кадре, 0…1.
    ///
    /// Замедление к концу, а не равномерно: последняя страна должна лечь
    /// отдельным событием, а не промелькнуть в общем потоке.
    static func progress(frame: Int) -> Double {
        let revealFrames = revealSeconds * Double(fps)
        let raw = min(1, Double(frame) / revealFrames)
        return 1 - pow(1 - raw, 2.4)
    }

    /// Состояние карты на этом кадре.
    ///
    /// Страны ложатся в том же порядке, в каком лежат в наложении: «хочу»
    /// внизу, «живу» сверху. Порядок отрисовки и порядок появления совпадают,
    /// иначе заливка перекрывала бы уже показанное.
    static func overlay(_ full: MapOverlayState, at progress: Double) -> MapOverlayState {
        var state = full

        let shown = Int((Double(full.marked.count) * progress).rounded())
        state.marked = Array(full.marked.prefix(max(0, shown)))

        // Линия маршрута растёт вместе с картой: иначе она висит целиком
        // над пустой картой с первого кадра.
        let stops = Int((Double(full.routeLine.count) * progress).rounded())
        state.routeLine = Array(full.routeLine.prefix(max(0, stops)))

        // Подсветка и заливка — состояния живого экрана, в видео им не место.
        state.bloom = nil
        state.highlight = nil
        return state
    }

    /// Статистика на этом кадре: число досчитывается до настоящего.
    static func statistics(_ full: TravelStatistics, at progress: Double) -> TravelStatistics {
        TravelStatistics(
            worldPercent: full.worldPercent * progress,
            visitedCount: Int((Double(full.visitedCount) * progress).rounded()),
            livingCount: full.livingCount,
            wishlistCount: Int((Double(full.wishlistCount) * progress).rounded()),
            exploredCount: Int((Double(full.exploredCount) * progress).rounded()),
            continentsTouched: Int((Double(full.continentsTouched) * progress).rounded()),
            continents: full.continents
        )
    }
}
