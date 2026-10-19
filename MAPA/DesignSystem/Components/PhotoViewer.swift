import SwiftUI

/// Фотография во весь экран.
///
/// Снимки с Викисклада — лучшее, что есть в приложении, и до этого их
/// можно было только разглядывать в ленте шириной сто пятьдесят точек.
/// Теперь по касанию фотография открывается целиком, с названием места,
/// именем автора и лицензией — то, что лицензия и требует показывать,
/// здесь наконец видно без прищура.
///
/// Закрывается касанием, кнопкой и смахиванием вниз: любой из трёх
/// способов, которым человек попробует это сделать, сработает.
struct PhotoViewer: View {

    @Environment(\.dsMotion) private var motion

    let photo: Landmark
    let onClose: () -> Void

    @State private var drag: CGFloat = 0

    /// Фон тает вместе со смахиванием — видно, что экран уезжает, а не завис.
    private var backdropOpacity: Double {
        let progress = min(1, Double(abs(drag)) / 400)
        return 1 - progress
    }

    var body: some View {
        ZStack {
            // Чёрный, а не затемнение темы: под фотографией не должно быть
            // ничего, что с ней спорит.
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()

            // Снимок занимает весь экран, подпись лежит на нём полосой
            // внизу — иначе между фотографией и её названием оставалась
            // ладонь черноты, и они переставали быть одним целым.
            RemoteImage(url: photo.large ?? photo.small, contentMode: .fit)
                .padding(.horizontal, DS.Space.sm)
                .padding(.top, 72)
                .padding(.bottom, 96)
                .offset(y: drag)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                caption
                    .padding(.horizontal, DS.Space.screen)
                    .padding(.top, DS.Space.lg)
                    .padding(.bottom, DS.Space.xl)
                    .frame(maxWidth: .infinity)
                    .background {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }
            }
            .offset(y: drag)

            closeButton
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
        .gesture(dismissDrag)
        .transition(motion.transition(.opacity))
        .accessibilityAddTraits(.isModal)
    }

    private var caption: some View {
        VStack(spacing: DS.Space.xxs) {
            Text(photo.name)
                .font(DS.Font.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let credit = photo.credit {
                Text(credit)
                    .font(DS.Font.micro)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Size.iconSm, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                        .background(Circle().fill(.white.opacity(0.14)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть фотографию")
            }
            Spacer()
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, 56)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                if abs(value.translation.height) > 120 {
                    onClose()
                }
                withAnimation(motion.animation(.snap)) { drag = 0 }
            }
    }
}

extension View {
    /// Открывает фотографию поверх экрана, пока в `photo` что-то лежит.
    func photoViewer(_ photo: Binding<Landmark?>) -> some View {
        overlay {
            if let item = photo.wrappedValue {
                PhotoViewer(photo: item) { photo.wrappedValue = nil }
                    .zIndex(10)
            }
        }
    }
}
