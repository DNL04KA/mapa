import SwiftUI
import UIKit

/// Высота клавиатуры — чтобы панель уступила ей место.
///
/// Панели приложения игнорируют безопасную зону: они доезжают до самого
/// низа экрана и уходят под домашнюю полоску. Побочный эффект — вместе с
/// зоной игнорируется и клавиатура, и поле ввода оказывается под ней. На
/// экране профиля это значило, что человек печатает никнейм вслепую, а
/// кнопки «Готово» просто нет.
///
/// Поэтому высота берётся напрямую у системы и прибавляется отступом —
/// только там, где в панели есть поле ввода.
///
/// Уведомления приходят в главную очередь, поэтому `@Published` меняется
/// там же, где его читает экран.
final class KeyboardInset: ObservableObject {

    @Published private(set) var height: CGFloat = 0

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification,
                               object: nil, queue: .main) { [weak self] note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                        as? CGRect else { return }
                let screen = UIScreen.main.bounds.height
                // Клавиатура уезжает за нижний край экрана — отсюда максимум
                // с нулём: отрицательный отступ поднял бы панель в воздух.
                self?.height = max(0, screen - frame.minY)
            }
        )
        observers.append(
            center.addObserver(forName: UIResponder.keyboardWillHideNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.height = 0
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
