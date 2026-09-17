import SwiftUI

/// Поочерёдное появление элементов списка.
///
/// Появление всей пачки разом читается как перерисовка экрана — будто что-то
/// моргнуло. По очереди с небольшим сдвигом снизу читается как то, что список
/// **выкладывают**: взгляд успевает пройти сверху вниз в том же порядке, в
/// котором его потом и читают.
///
/// Задержка берётся из общего каскада и упирается в потолок, поэтому длинный
/// список не заставляет ждать последний элемент.
///
/// При включённом «Уменьшении движения» элемент просто появляется на месте:
/// не мгновенно исчезающая анимация, а именно её отсутствие.
private struct RevealModifier: ViewModifier {

    let index: Int

    @Environment(\.dsMotion) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                if motion.reduceMotion {
                    shown = true
                } else {
                    withAnimation(motion.animation(.smooth).delay(DS.Motion.stagger(index))) {
                        shown = true
                    }
                }
            }
    }
}

public extension View {
    /// Появление по очереди: `index` — место элемента в списке.
    func dsReveal(_ index: Int) -> some View {
        modifier(RevealModifier(index: index))
    }
}
