import SwiftUI

/// Города выбранной страны.
///
/// На общей карте городов нет намеренно: две сотни подписей превращают её
/// в справочник и убивают всё, ради чего она рисовалась. Города появляются
/// только когда страна выбрана — тогда их единицы, и каждый к месту.
///
/// Слой объявлен `Animatable` с той же камерой, что и холст, — иначе метки
/// отрывались бы от своих точек, пока карта плавно едет.
///
/// Касания слой не принимает: попадание по городу считается в том же месте,
/// что и попадание по стране. Иначе кнопка-город глотала бы начало жеста,
/// и с неё нельзя было бы начать тащить карту.
struct CityMarkersLayer: View, Animatable {

    var camera: MapCamera

    let cities: [City]
    let viewport: CGSize
    let accent: Color
    let selectedCityID: String?
    /// Город, где стоит дом: его точку не рисуем — там уже домик.
    let homeCityName: String?

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(camera.zoom, AnimatablePair(camera.center.x, camera.center.y)) }
        set {
            camera.zoom = newValue.first
            camera.center = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    var body: some View {
        ZStack {
            ForEach(visible, id: \.city.id) { item in
                CityMarker(
                    city: item.city,
                    isSelected: item.city.id == selectedCityID,
                    accent: accent
                )
                .position(item.point)
            }
        }
        .allowsHitTesting(false)
    }

    /// Города, которые реально попадают на экран и не мешают друг другу.
    ///
    /// Подписи расталкиваются: идём от важных к неважным и выбрасываем те,
    /// что перекрыли бы уже поставленную. Даже внутри одной страны города
    /// умеют лежать вплотную — Гаага и Амстердам, Претория и Йоханнесбург.
    private var visible: [(city: City, point: CGPoint)] {
        guard viewport.width > 0 else { return [] }

        let offsets = camera.visibleWorldOffsets(in: viewport)
        let margin: CGFloat = 40

        let candidates = cities
            .filter { $0.nameRU != homeCityName }
            .sorted { importance($0) > importance($1) }

        var placed: [CGRect] = []
        var result: [(city: City, point: CGPoint)] = []

        for city in candidates {
            for offset in offsets {
                let shifted = CGPoint(x: city.unitPoint.x + offset, y: city.unitPoint.y)
                let point = camera.screenPoint(unit: shifted, in: viewport)

                guard point.x > -margin, point.x < viewport.width + margin,
                      point.y > -margin, point.y < viewport.height + margin
                else { continue }

                let box = labelBox(for: city, at: point)
                if placed.contains(where: { $0.intersects(box) }) { break }

                placed.append(box)
                result.append((city, point))
                break
            }
        }

        return result
    }

    /// Выбранный город показываем всегда, дальше — по важности.
    private func importance(_ city: City) -> Double {
        city.id == selectedCityID ? .greatestFiniteMagnitude : city.importance
    }

    /// Прямоугольник, который займут точка с подписью.
    /// Ширину букв считаем приблизительно — точный замер тут не нужен,
    /// а `Text` пришлось бы измерять через отдельный проход разметки.
    private func labelBox(for city: City, at point: CGPoint) -> CGRect {
        let width = CGFloat(city.displayName.count) * 6.6 + 26
        return CGRect(x: point.x - 10, y: point.y - 11, width: width, height: 22)
    }
}

/// Точка города с подписью.
struct CityMarker: View {

    @Environment(\.dsMotion) private var motion
    @Environment(\.mapTheme) private var theme

    let city: City
    let isSelected: Bool
    let accent: Color

    private var dotSize: CGFloat {
        isSelected ? 13 : (city.isCapital ? 9 : 6)
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(theme.mapInk)
                    .frame(width: dotSize, height: dotSize)

                // У столиц точка с «дыркой» — так они отличаются от прочих
                // городов даже без подписи.
                if city.isCapital && !isSelected {
                    Circle()
                        .fill(theme.isLight ? Color.white : Color.black.opacity(0.75))
                        .frame(width: dotSize * 0.4, height: dotSize * 0.4)
                }

                if isSelected {
                    Circle()
                        .strokeBorder(accent, lineWidth: 2.5)
                        .frame(width: dotSize + 9, height: dotSize + 9)
                }
            }
            .shadow(color: theme.mapInkShadow, radius: 2.5)
            .shadow(color: isSelected ? accent.opacity(0.9) : .clear, radius: 8)

            Text(city.displayName)
                .font(.system(size: city.isCapital ? 12 : 11, weight: city.isCapital ? .semibold : .medium))
                .foregroundStyle(theme.mapInk)
                .fixedSize()
                .dsMapText()
        }
        // Подпись растёт вправо, поэтому блок сдвигаем обратно —
        // иначе точка «уезжает» от своих координат.
        .offset(x: labelShift)
        .transition(motion.transition(.scale(scale: 0.4).combined(with: .opacity)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(city.isCapital ? "\(city.displayName), столица" : city.displayName)
    }

    private var labelShift: CGFloat {
        CGFloat(city.displayName.count) * 3 + 4
    }
}
