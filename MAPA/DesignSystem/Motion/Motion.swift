import SwiftUI

public extension DS {

    /// Каталог движений. Все анимации в MAPA берутся отсюда —
    /// это единственный способ добиться, чтобы приложение «двигалось» одинаково.
    enum Motion {

        public enum Preset: String, CaseIterable, Identifiable {
            /// Нажатие кнопки, чип. Быстро и без раскачки.
            case snap
            /// Появление панелей, смена состояния. Основная рабочая пружина.
            case smooth
            /// Крупные перемещения: карта, переход в карточку страны.
            case flow
            /// Заливка страны, празднование. Слегка «пружинит».
            case bounce
            /// Медленный фоновый дрейф (аврора, параллакс).
            case ambient

            public var id: String { rawValue }

            public var title: String {
                switch self {
                case .snap:    return "snap"
                case .smooth:  return "smooth"
                case .flow:    return "flow"
                case .bounce:  return "bounce"
                case .ambient: return "ambient"
                }
            }

            public var usage: String {
                switch self {
                case .snap:    return "Кнопки, чипы, мелкие переключения"
                case .smooth:  return "Панели, смена состояния, шиты"
                case .flow:    return "Карта, переходы между экранами"
                case .bounce:  return "Заливка страны, награды"
                case .ambient: return "Фоновый дрейф градиентов"
                }
            }

            /// Полная версия анимации — когда Reduce Motion выключен.
            public var animation: Animation {
                switch self {
                case .snap:
                    return .spring(response: 0.26, dampingFraction: 0.86, blendDuration: 0)
                case .smooth:
                    return .spring(response: 0.45, dampingFraction: 0.90, blendDuration: 0)
                case .flow:
                    return .spring(response: 0.68, dampingFraction: 0.88, blendDuration: 0)
                case .bounce:
                    return .spring(response: 0.50, dampingFraction: 0.62, blendDuration: 0)
                case .ambient:
                    return .easeInOut(duration: 7.0)
                }
            }

            /// Версия для Reduce Motion: сохраняем понятную смену состояния,
            /// но убираем пружину, разлёт и долгий дрейф.
            public var reducedAnimation: Animation {
                switch self {
                case .ambient: return .linear(duration: 0.001)
                case .flow:    return .easeOut(duration: 0.22)
                default:       return .easeOut(duration: 0.16)
                }
            }
        }

        // MARK: Длительности для не-пружинных вещей

        public enum Duration {
            public static let instant: Double = 0.12
            public static let quick:   Double = 0.20
            public static let base:    Double = 0.32
            public static let slow:    Double = 0.60
            /// Один цикл фонового дрейфа.
            public static let ambientLoop: Double = 14
        }

        // MARK: Каскад

        /// Задержка для поочерёдного появления элементов списка.
        /// Ограничиваем сверху, чтобы 40-й элемент не ждал секунду.
        public static func stagger(_ index: Int, step: Double = 0.045, cap: Double = 0.36) -> Double {
            min(Double(index) * step, cap)
        }
    }
}
