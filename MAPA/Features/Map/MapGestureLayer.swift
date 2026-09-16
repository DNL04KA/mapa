import SwiftUI
import UIKit

/// Жесты карты на UIKit-распознавателях.
///
/// Почему не `DragGesture` и `MagnificationGesture`:
/// • `MagnificationGesture` не сообщает точку между пальцами, поэтому зум
///   пришлось бы привязывать к центру экрана — ощущается как рывок;
/// • у SwiftUI-жестов нет скорости в конце, а без неё нет инерции;
/// • одновременные пан и пинч на UIKit-распознавателях просто надёжнее.
struct MapGestureLayer: UIViewRepresentable {

    /// Смещение с прошлого кадра, в точках экрана.
    var onPan: (CGSize) -> Void
    /// Скорость в момент отрыва пальца, точек в секунду.
    var onPanEnded: (CGPoint) -> Void
    /// Изменение масштаба с прошлого кадра и точка между пальцами.
    var onPinch: (CGFloat, CGPoint) -> Void
    var onPinchEnded: () -> Void
    /// Одиночный тап — выбор страны.
    var onTap: (CGPoint) -> Void
    var onDoubleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = TouchView()
        view.backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        // Иначе первый тап двойного нажатия успел бы открыть шит.
        // Цена — примерно четверть секунды до появления панели.
        tap.require(toFail: doubleTap)

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Замыкания пересоздаются на каждый рендер SwiftUI — координатор
        // должен держать свежие, иначе жесты начнут дёргать устаревшее состояние.
        context.coordinator.parent = self
    }

    /// Прозрачная вьюха, которая всё равно ловит касания.
    private final class TouchView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { true }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var parent: MapGestureLayer

        init(_ parent: MapGestureLayer) {
            self.parent = parent
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }

            switch recognizer.state {
            case .changed:
                let translation = recognizer.translation(in: view)
                // Сбрасываем — дальше работаем приращениями, а не суммой.
                recognizer.setTranslation(.zero, in: view)
                parent.onPan(CGSize(width: translation.x, height: translation.y))

            case .ended:
                parent.onPanEnded(recognizer.velocity(in: view))

            case .cancelled, .failed:
                parent.onPanEnded(.zero)

            default:
                break
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }

            switch recognizer.state {
            case .changed:
                let scale = recognizer.scale
                recognizer.scale = 1
                parent.onPinch(scale, recognizer.location(in: view))

            case .ended, .cancelled, .failed:
                parent.onPinchEnded()

            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view, recognizer.state == .ended else { return }
            parent.onTap(recognizer.location(in: view))
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view, recognizer.state == .ended else { return }
            parent.onDoubleTap(recognizer.location(in: view))
        }

        /// Пан и пинч должны работать вместе: карту двигают и масштабируют
        /// одним движением руки, а не по очереди.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            !(gestureRecognizer is UITapGestureRecognizer) && !(other is UITapGestureRecognizer)
        }
    }
}
