import SwiftUI

/// Картинка из сети, которая аккуратно проявляется.
///
/// Рисует только саму фотографию и ничего больше: подложку, рамку и заглушку
/// задаёт тот, кто вставляет. Так один и тот же вид годится и для квадратика
/// 72×72 в маршруте, и для широкой карточки города.
///
/// Если снимок уже в памяти, он появляется сразу и без анимации: проявление
/// того, что и так было готово, выглядит как тормоз, а не как плавность.
struct RemoteImage: View {

    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Прозрачный слой снизу — не для вида: пока картинки нет, без него
        // остаётся пустой вид, а на пустом виде SwiftUI не запускает `.task`,
        // и загрузка просто не начинается.
        ZStack {
            Color.clear

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            if let ready = RemoteImageStore.shared.cached(url) {
                image = ready
                appeared = true
                return
            }
            image = nil
            appeared = false
            let loaded = await RemoteImageStore.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
            guard loaded != nil else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: DS.Motion.Duration.base)) { appeared = true }
            }
        }
    }
}
