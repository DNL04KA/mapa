import SwiftUI

/// Набросок маршрута по стране — лентой сверху вниз.
///
/// Раньше маршрут можно было собрать только тыкая в города на карте, и
/// выглядел он списком строк. Здесь наоборот: сначала показываем, **куда**
/// ехать и **что** там, а собирать маршрут не нужно — он уже собран.
///
/// Формат ленты выбран не ради красоты: поездка — это последовательность, и
/// вертикальная линия с номерами читается как последовательность, а таблица
/// или сетка — нет.
@MainActor
struct CountryRouteSection: View {

    @Environment(\.dsMotion) private var motion

    let stops: [CountryRoutePlanner.Stop]
    let tint: Color
    let onTake: () -> Void
    let onOpenCity: (City) -> Void

    private var totalDays: Int { stops.reduce(0) { $0 + $1.days } }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            header

            VStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    // Остановки выкладываются по очереди — маршрут
                    // прокладывается у тебя на глазах.
                    row(stop, index: index, isLast: index == stops.count - 1)
                        .dsReveal(index)
                }
            }

            PillButton("Взять себе", kind: .secondary, fullWidth: true, action: onTake)
                .padding(.top, DS.Space.xxs)

            Text("Набросок собран из главных городов страны и их настоящих достопримечательностей. Порядок — по географии, дни — по числу мест. Всё это правится, как только маршрут твой.")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader("Маршрут по стране")
            Spacer(minLength: DS.Space.xs)
            Text(Plural.cities(stops.count)
                 + " · " + Plural.days(totalDays))
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Остановка

    private func row(_ stop: CountryRoutePlanner.Stop, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            rail(index: index, isLast: isLast)

            Button {
                onOpenCity(stop.city)
            } label: {
                card(stop)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(index + 1). \(stop.city.displayName), \(Plural.days(stop.days))")
    }

    /// Номер и линия до следующей точки.
    private func rail(index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(tint)
                Text("\(index + 1)")
                    .font(.system(size: DS.Size.glyph, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Palette.void)
            }
            .frame(width: 24, height: 24)

            if !isLast {
                // Линия пунктиром, а не сплошная: между городами едут, и
                // пунктир — общепринятый знак перемещения, а не границы.
                Rectangle()
                    .fill(.clear)
                    .overlay {
                        Line()
                            .stroke(tint.opacity(0.45),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                    }
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 24)
    }

    private func card(_ stop: CountryRoutePlanner.Stop) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            photo(stop)

            VStack(alignment: .leading, spacing: 3) {
                if stop.landmarks.isEmpty {
                    Text("Что смотреть — расскажут те, кто был")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                } else {
                    Text(stop.landmarks.prefix(3).map(\.name).joined(separator: " · "))
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let credit = stop.photo?.credit {
                    Text(credit)
                        .font(.system(size: DS.Size.glyphSm))
                        .foregroundStyle(DS.Color.inkTertiary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, DS.Space.xs)
        }
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.surfaceRaised.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Color.hairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .padding(.bottom, DS.Space.sm)
    }

    /// Снимок во всю ширину карточки: ради него всё и затевалось.
    /// Название города — поверх фотографии, чтобы не отнимать строку.
    ///
    /// Размер задаёт прямоугольник-подложка, а снимок и подпись ложатся
    /// поверх него. Если собрать это стопкой, картинка с `.fill` раздувает
    /// стопку до своего размера, подпись прижимается к низу **картинки**,
    /// а не карточки, и обрезается вместе с ним.
    private func photo(_ stop: CountryRoutePlanner.Stop) -> some View {
        Rectangle()
            .fill(tint.opacity(0.14))
            .frame(height: 132)
            .overlay { RemoteImage(url: stop.photo?.large) }
            .clipped()
            .overlay(alignment: .bottom) {
                // Затемнение только снизу и только под текстом: накрывать им
                // весь снимок — гасить то, ради чего он здесь.
                LinearGradient(
                    colors: [.clear, DS.Palette.void.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 64)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .lastTextBaseline, spacing: DS.Space.xs) {
                    Text(stop.city.displayName)
                        .font(DS.Font.subhead)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(Plural.days(stop.days))
                        .font(DS.Font.micro)
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                }
                .padding(.horizontal, DS.Space.sm)
                .padding(.bottom, DS.Space.xs)
            }
    }
}

/// Вертикальная линия от верха к низу — для пунктира между остановками.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
