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
    /// Дошла ли фотография. Нужно там, где рядом стоит подпись к снимку:
    /// имя автора под пустым местом — это не указание авторства, а мусор.
    var onLoad: ((Bool) -> Void)?

    @State private var image: UIImage?
    @State private var appeared = false
    /// Загрузка закончилась ничем — сеть или сам снимок.
    @State private var failed = false
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
            } else if failed {
                missing
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                failed = false
                onLoad?(false)
                return
            }
            #if DEBUG
            // Снять, как выглядит приложение без сети, иначе нечем:
            // симулятор ходит в интернет вместе с машиной. Только отладка.
            if ProcessInfo.processInfo.environment["MAPA_NO_PHOTOS"] == "1" {
                image = nil
                failed = true
                onLoad?(false)
                return
            }
            #endif

            if let ready = RemoteImageStore.shared.cached(url) {
                image = ready
                appeared = true
                failed = false
                onLoad?(true)
                return
            }
            image = nil
            appeared = false
            failed = false
            let loaded = await RemoteImageStore.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
            guard loaded != nil else {
                failed = true
                onLoad?(false)
                return
            }
            onLoad?(true)
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: DS.Motion.Duration.base)) { appeared = true }
            }
        }
    }

    /// Что видно, когда снимок не пришёл.
    ///
    /// Раньше оставалась просто подложка: в самолёте и в метро карточка
    /// страны показывала пустой прямоугольник, и понять, грузится ли он
    /// ещё или уже нет, было нельзя. Значок отвечает на этот вопрос, не
    /// занимая собой весь кадр.
    ///
    /// Размер считается от места: один и тот же вид стоит и в квадратике
    /// 72×72, и на фотографии во весь экран.
    private var missing: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Image(systemName: "photo")
                .font(.system(size: min(max(side * 0.22, 13), 40), weight: .light))
                .foregroundStyle(DS.Color.inkTertiary.opacity(0.55))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}
