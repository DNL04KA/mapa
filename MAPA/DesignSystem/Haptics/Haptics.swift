import CoreHaptics
import UIKit

/// Тактильный отклик MAPA.
///
/// Два уровня:
/// 1. Системные генераторы (`UIFeedbackGenerator`) — быстрые, работают везде.
/// 2. Core Haptics — для фирменных паттернов. Главный из них — `countryFill`:
///    короткий «щелчок» в момент касания и мягкая волна, пока страна заливается.
///    Именно такие детали отличают дорогое приложение от обычного.
///
/// На симуляторе и старых устройствах Core Haptics недоступен —
/// тогда молча откатываемся на обычный impact.
@MainActor
public final class Haptics {

    public static let shared = Haptics()

    /// Пользовательский тумблер (появится в настройках позже).
    public var isEnabled: Bool = true

    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    // MARK: - Подготовка

    /// Вызывается заранее (например, при появлении экрана карты), чтобы
    /// первый отклик не опоздал на 100–200 мс, пока «просыпается» железо.
    public func prepare() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // Система может остановить движок (звонок, фон) — поднимаем обратно.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil   // не критично: приложение работает и без вибрации
        }
    }

    // MARK: - Базовые отклики

    /// Перемещение по списку, смена выбранного варианта.
    public func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Обычное нажатие.
    public func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, intensity: CGFloat = 1) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    public func success() { notify(.success) }
    public func warning() { notify(.warning) }
    public func error()   { notify(.error) }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    // MARK: - Фирменный паттерн

    /// Заливка страны: резкий щелчок + волна, затухающая за ~0.45 с.
    /// Ощущается как «краска растеклась», а не как обычный клик.
    public func countryFill() {
        guard isEnabled else { return }
        guard supportsHaptics else {
            tap(.medium)
            return
        }
        startEngineIfNeeded()
        guard let engine else {
            tap(.medium)
            return
        }

        let click = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        )

        let swell = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
            ],
            relativeTime: 0.03,
            duration: 0.42
        )

        // Кривая громкости: быстро набирает и плавно уходит в ноль.
        let envelope = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.15),
                .init(relativeTime: 0.10, value: 1.00),
                .init(relativeTime: 0.42, value: 0.00)
            ],
            relativeTime: 0.03
        )

        play(events: [click, swell], curves: [envelope], on: engine)
    }

    /// Снятие статуса — короткий «выдох» без щелчка.
    public func countryClear() {
        guard isEnabled else { return }
        startEngineIfNeeded()
        guard supportsHaptics, let engine else {
            tap(.soft, intensity: 0.7)
            return
        }
        let fade = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0,
            duration: 0.22
        )
        play(events: [fade], curves: [], on: engine)
    }

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve], on engine: CHHapticEngine) {
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            tap(.medium)
        }
    }
}
